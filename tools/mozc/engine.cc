#include <algorithm>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <vector>
#include "base/system_util.h"
#include "base/util.h"
#include "composer/composer.h"
#include "data_manager/data_manager.h"
#include "engine/engine.h"
#include "converter/converter_interface.h"
#include "converter/segments.h"
#include "request/conversion_request.h"
namespace {
std::mutex mutex;
std::unique_ptr<mozc::Engine> engine;
std::string reverse_reading;
std::vector<std::string> candidates;
struct Choice {
  std::string value;
  std::shared_ptr<mozc::Segments> segments;
  std::vector<int> indices;
  mozc::ConversionRequest::RequestType type;
};
struct Batch { std::string reading; std::vector<Choice> choices; };
std::deque<Batch> batches;
std::vector<std::vector<std::string>> segment_rows;
struct SegmentBatch { std::string reading; std::shared_ptr<mozc::Segments> segments; };
std::deque<SegmentBatch> segment_batches;
mozc::ConversionRequest Request(const std::string& reading,
                               mozc::ConversionRequest::RequestType type, bool private_mode) {
  mozc::composer::Composer composer;
  composer.InsertCharacterPreedit(reading);
  mozc::ConversionRequest::Options options;
  options.request_type = type;
  options.incognito_mode = private_mode;
  options.create_partial_candidates = false;
  return mozc::ConversionRequestBuilder().SetComposer(composer).SetOptions(options).SetKey(reading).Build();
}
void Append(Batch& batch, std::shared_ptr<mozc::Segments> segments,
            mozc::ConversionRequest::RequestType type, size_t limit) {
  const size_t count = segments->conversion_segments_size();
  for (size_t varied = 0; varied < count && candidates.size() < limit; ++varied) {
    const auto& segment = segments->conversion_segment(varied);
    for (size_t j = 0; j < segment.candidates_size() && j < 24 && candidates.size() < limit; ++j) {
      Choice choice; choice.segments = segments; choice.type = type;
      for (size_t i = 0; i < count; ++i) {
        const auto& part = segments->conversion_segment(i);
        if (!part.candidates_size()) return;
        int index = i == varied ? j : 0;
        // Partial predictions require separate remaining-reading editing. Exclude them here.
        if (part.candidate(index).attributes & mozc::converter::Attribute::PARTIALLY_KEY_CONSUMED) break;
        choice.value += part.candidate(index).value;
        choice.indices.push_back(index);
      }
      if (choice.indices.size() == count && !choice.value.empty() &&
          std::find(candidates.begin(), candidates.end(), choice.value) == candidates.end()) {
        candidates.push_back(choice.value); batch.choices.push_back(std::move(choice));
      }
    }
  }
}
int StoreSegments(const std::string& reading, bool private_mode, std::shared_ptr<mozc::Segments> segments) {
  if (segments->conversion_segments_size() > 64) return 0;
  for (const auto& segment : segments->conversion_segments()) {
    std::vector<std::string> row{std::string(segment.key())};
    for (size_t j = 0; j < segment.candidates_size() && row.size() <= 64; ++j) {
      const auto& candidate = segment.candidate(j);
      if (!candidate.value.empty() &&
          !(candidate.attributes & mozc::converter::Attribute::PARTIALLY_KEY_CONSUMED) &&
          std::find(row.begin() + 1, row.end(), candidate.value) == row.end()) row.push_back(candidate.value);
    }
    if (row.size() < 2) { segment_rows.clear(); return 0; }
    segment_rows.push_back(std::move(row));
  }
  if (!private_mode) {
    segment_batches.push_back({reading, segments});
    while (segment_batches.size() > 4) segment_batches.pop_front();
  }
  return segment_rows.size();
}
}
extern "C" int nihongo_engine_init(const char* dictionary, const char* profile) {
  std::lock_guard<std::mutex> lock(mutex);
  if (engine) return 1;
  mozc::SystemUtil::SetUserProfileDirectory(profile);
  auto data = mozc::DataManager::CreateFromFile(dictionary);
  if (!data.ok()) return 0;
  auto result = mozc::Engine::CreateEngine(std::move(*data));
  if (!result.ok()) return 0;
  engine = std::move(*result);
  return 1;
}
extern "C" int nihongo_engine_convert(const char* reading, int private_mode) {
  std::lock_guard<std::mutex> lock(mutex);
  candidates.clear();
  if (!engine || !reading || !*reading) return 0;
  Batch batch; batch.reading = reading;
  // Keep exact conversion first, then append prefix predictions without losing conversion choices.
  auto exact = std::make_shared<mozc::Segments>();
  auto request = Request(reading, mozc::ConversionRequest::CONVERSION, private_mode);
  if (engine->GetConverter()->StartConversion(request, exact.get())) Append(batch, exact, mozc::ConversionRequest::CONVERSION, 24);
  const size_t exact_count = candidates.size();
  auto predicted = std::make_shared<mozc::Segments>();
  auto prediction = Request(reading, mozc::ConversionRequest::PREDICTION, private_mode);
  if (engine->GetConverter()->StartPrediction(prediction, predicted.get())) Append(batch, predicted, mozc::ConversionRequest::PREDICTION, 64);
  // Surface a few completions beside the best exact choice in the single-row bar.
  if (exact_count > 1 && candidates.size() > exact_count) {
    const size_t end = std::min(candidates.size(), exact_count + 5);
    std::rotate(candidates.begin() + 1, candidates.begin() + exact_count, candidates.begin() + end);
  }
  if (!private_mode) {
    batches.push_back(std::move(batch));
    while (batches.size() > 4) batches.pop_front();
  }
  return candidates.size();
}
extern "C" const char* nihongo_engine_candidate(int index) {
  return index >= 0 && static_cast<size_t>(index) < candidates.size() ? candidates[index].c_str() : "";
}
extern "C" int nihongo_engine_learn(const char* reading, const char* value) {
  std::lock_guard<std::mutex> lock(mutex);
  if (!engine || !reading || !value) return 0;
  for (auto batch = batches.rbegin(); batch != batches.rend(); ++batch) {
    if (batch->reading != reading) continue;
    for (const auto& choice : batch->choices) {
      if (choice.value != value) continue;
      mozc::Segments selected = *choice.segments;
      for (size_t i = 0; i < choice.indices.size(); ++i) {
        if (!engine->GetConverter()->CommitSegmentValue(&selected, i, choice.indices[i])) return 0;
      }
      auto request = Request(reading, choice.type, false);
      engine->GetConverter()->FinishConversion(request, &selected);
      return engine->Sync() && engine->Wait();
    }
  }
  return 0;
}

// Each row contains the segment reading followed by its selectable candidates.
extern "C" int nihongo_engine_segments(const char* reading, int private_mode) {
  std::lock_guard<std::mutex> lock(mutex);
  segment_rows.clear();
  if (!engine || !reading || !*reading) return 0;
  auto segments = std::make_shared<mozc::Segments>();
  auto request = Request(reading, mozc::ConversionRequest::CONVERSION, private_mode);
  if (!engine->GetConverter()->StartConversion(request, segments.get())) return 0;
  return StoreSegments(reading, private_mode, segments);
}

extern "C" int nihongo_engine_segment_size(int index) {
  return index >= 0 && static_cast<size_t>(index) < segment_rows.size() ? segment_rows[index].size() : 0;
}
extern "C" const char* nihongo_engine_segment_value(int index, int candidate) {
  return index >= 0 && static_cast<size_t>(index) < segment_rows.size() && candidate >= 0 &&
    static_cast<size_t>(candidate) < segment_rows[index].size() ? segment_rows[index][candidate].c_str() : "";
}
extern "C" int nihongo_engine_learn_segments(const char* reading, const char* const* values, const char* const* keys, int count) {
  std::lock_guard<std::mutex> lock(mutex);
  if (!engine || !reading || !values || !keys || count <= 0 || count > 64) return 0;
  for (auto batch = segment_batches.rbegin(); batch != segment_batches.rend(); ++batch) {
    if (batch->reading != reading || batch->segments->conversion_segments_size() != static_cast<size_t>(count)) continue;
    bool matches = true;
    for (int i = 0; i < count; ++i) {
      if (!keys[i] || batch->segments->conversion_segment(i).key() != keys[i]) { matches = false; break; }
    }
    if (!matches) continue;
    mozc::Segments selected = *batch->segments;
    std::vector<int> indices;
    for (int i = 0; i < count; ++i) {
      if (!values[i]) return 0;
      const auto& segment = selected.conversion_segment(i);
      int found = -1;
      for (size_t j = 0; j < segment.candidates_size(); ++j) {
        if (segment.candidate(j).value == values[i]) { found = j; break; }
      }
      if (found < 0) return 0;
      indices.push_back(found);
    }
    // Validate the complete selection before committing any segment.
    for (int i = 0; i < count; ++i) {
      if (!engine->GetConverter()->CommitSegmentValue(&selected, i, indices[i])) return 0;
    }
    auto request = Request(reading, mozc::ConversionRequest::CONVERSION, false);
    engine->GetConverter()->FinishConversion(request, &selected);
    return engine->Sync() && engine->Wait();
  }
  return 0;
}

// Stateless boundary request: reconstruct the explicit current boundaries, then resize.
extern "C" int nihongo_engine_resize(const char* reading, const int* lengths, int count, int focus, int delta, int private_mode) {
  std::lock_guard<std::mutex> lock(mutex);
  segment_rows.clear();
  if (!engine || !reading || !*reading || !lengths || count <= 0 || count > 64 || focus < 0 || focus >= count || (delta != -1 && delta != 1)) return 0;
  std::vector<uint8_t> sizes;
  int total = 0;
  for (int i = 0; i < count; ++i) {
    if (lengths[i] <= 0 || lengths[i] > 255) return 0;
    total += lengths[i]; sizes.push_back(lengths[i]);
  }
  if (total != mozc::Util::CharsLen(reading) || lengths[focus] + delta <= 0 ||
      lengths[focus] + delta > 255 || (delta > 0 && focus == count - 1)) return 0;
  auto segments = std::make_shared<mozc::Segments>();
  auto request = Request(reading, mozc::ConversionRequest::CONVERSION, private_mode);
  auto converter = engine->GetConverter();
  if (!converter->StartConversion(request, segments.get()) ||
      !converter->ResizeSegments(segments.get(), request, 0, sizes) ||
      !converter->ResizeSegment(segments.get(), request, focus, delta)) return 0;
  return StoreSegments(reading, private_mode, segments);
}

extern "C" const char* nihongo_engine_reverse(const char* text) {
  std::lock_guard<std::mutex> lock(mutex);
  reverse_reading.clear();
  if (!engine || !text || !*text) return reverse_reading.c_str();
  mozc::Segments segments;
  if (!engine->GetConverter()->StartReverseConversion(&segments, text)) return reverse_reading.c_str();
  for (const auto& segment : segments.conversion_segments()) {
    if (!segment.candidates_size()) { reverse_reading.clear(); break; }
    reverse_reading += segment.candidate(0).value;
  }
  return reverse_reading.c_str();
}
