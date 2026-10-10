#pragma once
#include <mutex>
#include <string>
#include <vector>
extern "C" int nihongo_engine_init(const char*, const char*);
extern "C" int nihongo_engine_convert(const char*, int);
extern "C" int nihongo_engine_learn(const char*, const char*);
extern "C" const char* nihongo_engine_candidate(int);
extern "C" int nihongo_engine_segments(const char*, int);
extern "C" int nihongo_engine_segment_size(int);
extern "C" const char* nihongo_engine_segment_value(int, int);
extern "C" int nihongo_engine_learn_segments(const char*, const char* const*, const char* const*, int);
extern "C" int nihongo_engine_resize(const char*, const int*, int, int, int, int);
extern "C" const char* nihongo_engine_reverse(const char*);
extern "C" int nihongo_engine_next(const char*, int);
extern "C" int nihongo_engine_clear_learning();
namespace {
std::mutex workerMutex;
enum class EngineOperation { Initialize, Convert, Learn, Segments, LearnSegments, Resize, Reverse, Next, ClearLearning };
struct EngineWork {
  napi_async_work work; napi_deferred deferred;
  EngineOperation operation;
  bool privateMode = true; bool success = false;
  std::string text, profile;
  int focus = 0, delta = 0;
  std::vector<int> lengths;
  std::vector<std::string> keys;
  std::vector<std::string> candidates;
  std::vector<std::vector<std::string>> rows;
};
bool ReadString(napi_env env, napi_value value, std::string& out) {
  size_t length = 0;
  if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok || length > 4096) return false;
  std::vector<char> buffer(length + 1);
  size_t copied;
  if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &copied) != napi_ok) return false;
  out.assign(buffer.data(), copied);
  return out.find('\0') == std::string::npos;
}
bool ReadStrings(napi_env env, napi_value value, std::vector<std::string>& out) {
  bool array = false; uint32_t count = 0;
  if (napi_is_array(env, value, &array) != napi_ok || !array ||
      napi_get_array_length(env, value, &count) != napi_ok || count == 0 || count > 64) return false;
  for (uint32_t i = 0; i < count; ++i) {
    napi_value element; std::string text;
    if (napi_get_element(env, value, i, &element) != napi_ok || !ReadString(env, element, text) || text.empty()) return false;
    out.push_back(std::move(text));
  }
  return true;
}
bool ReadInt(napi_env env, napi_value value, int low, int high, int& out) {
  double number;
  if (napi_get_value_double(env, value, &number) != napi_ok || !(number >= low && number <= high)) return false;
  out = static_cast<int>(number);
  return number == out;
}
bool ReadLengths(napi_env env, napi_value value, std::vector<int>& out) {
  bool array = false; uint32_t count;
  if (napi_is_array(env, value, &array) != napi_ok || !array || napi_get_array_length(env, value, &count) != napi_ok || count == 0 || count > 64) return false;
  for (uint32_t i = 0; i < count; ++i) {
    napi_value element; int number;
    if (napi_get_element(env, value, i, &element) != napi_ok || !ReadInt(env, element, 1, 255, number)) return false;
    out.push_back(number);
  }
  return true;
}
void ExecuteEngine(napi_env, void* raw) {
  auto* w = static_cast<EngineWork*>(raw);
  std::lock_guard<std::mutex> lock(workerMutex);
  switch (w->operation) {
    case EngineOperation::ClearLearning:
      w->success = nihongo_engine_clear_learning(); break;
    case EngineOperation::Reverse:
      w->profile = nihongo_engine_reverse(w->text.c_str()); w->success = true; break;
    case EngineOperation::Initialize:
      w->success = nihongo_engine_init(w->text.c_str(), w->profile.c_str()); break;
    case EngineOperation::Learn:
      w->success = nihongo_engine_learn(w->text.c_str(), w->profile.c_str()); break;
    case EngineOperation::LearnSegments: {
      std::vector<const char*> values, keys;
      for (const auto& value : w->candidates) values.push_back(value.c_str());
      for (const auto& key : w->keys) keys.push_back(key.c_str());
      w->success = nihongo_engine_learn_segments(w->text.c_str(), values.data(), keys.data(), values.size()); break;
    }
    case EngineOperation::Segments:
    case EngineOperation::Next:
    case EngineOperation::Resize: {
      int count = w->operation == EngineOperation::Next ? nihongo_engine_next(w->text.c_str(), w->privateMode) : w->operation == EngineOperation::Resize ?
        nihongo_engine_resize(w->text.c_str(), w->lengths.data(), w->lengths.size(), w->focus, w->delta, w->privateMode) :
        nihongo_engine_segments(w->text.c_str(), w->privateMode);
      for (int i = 0; i < count; ++i) {
        std::vector<std::string> row;
        for (int j = 0; j < nihongo_engine_segment_size(i); ++j) row.emplace_back(nihongo_engine_segment_value(i, j));
        w->rows.push_back(std::move(row));
      }
      w->success = true; break;
    }
    case EngineOperation::Convert: {
      int count = nihongo_engine_convert(w->text.c_str(), w->privateMode);
      for (int i = 0; i < count; ++i) w->candidates.emplace_back(nihongo_engine_candidate(i));
      w->success = true; break;
    }
  }
}
napi_value StringArray(napi_env env, const std::vector<std::string>& values) {
  napi_value result; napi_create_array_with_length(env, values.size(), &result);
  for (size_t i = 0; i < values.size(); ++i) {
    napi_value text; napi_create_string_utf8(env, values[i].c_str(), values[i].size(), &text);
    napi_set_element(env, result, i, text);
  }
  return result;
}
void CompleteEngine(napi_env env, napi_status status, void* raw) {
  auto* w = static_cast<EngineWork*>(raw);
  napi_value result;
  if (status != napi_ok || !w->success) {
    napi_value message; napi_create_string_utf8(env, "Mozc operation failed", NAPI_AUTO_LENGTH, &message);
    napi_create_error(env, nullptr, message, &result); napi_reject_deferred(env, w->deferred, result);
  } else {
    if (w->operation == EngineOperation::Reverse) napi_create_string_utf8(env, w->profile.c_str(), w->profile.size(), &result);
    else if (w->operation == EngineOperation::Convert) result = StringArray(env, w->candidates);
    else if (w->operation == EngineOperation::Segments || w->operation == EngineOperation::Resize || w->operation == EngineOperation::Next) {
      napi_create_array_with_length(env, w->rows.size(), &result);
      for (size_t i = 0; i < w->rows.size(); ++i) napi_set_element(env, result, i, StringArray(env, w->rows[i]));
    } else napi_get_boolean(env, true, &result);
    napi_resolve_deferred(env, w->deferred, result);
  }
  napi_delete_async_work(env, w->work); delete w;
}
napi_value QueueEngine(napi_env env, napi_callback_info info, EngineOperation operation) {
  size_t count = 5; napi_value args[5];
  napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
  auto* w = new EngineWork{}; w->operation = operation;
  const size_t expected = operation == EngineOperation::ClearLearning ? 0 : operation == EngineOperation::Reverse ? 1 : (operation == EngineOperation::Resize ? 5 : (operation == EngineOperation::LearnSegments ? 3 : 2));
  bool valid = count == expected && (expected == 0 || ReadString(env, args[0], w->text));
  if (valid && operation != EngineOperation::Reverse && operation != EngineOperation::ClearLearning) {
    if (operation == EngineOperation::Initialize || operation == EngineOperation::Learn) valid = ReadString(env, args[1], w->profile);
    else if (operation == EngineOperation::LearnSegments) valid = ReadStrings(env, args[1], w->candidates) && ReadStrings(env, args[2], w->keys) && w->keys.size() == w->candidates.size();
    else if (operation == EngineOperation::Resize) valid = ReadLengths(env, args[1], w->lengths) &&
      ReadInt(env, args[2], 0, 63, w->focus) && ReadInt(env, args[3], -1, 1, w->delta) && w->delta != 0 &&
      napi_get_value_bool(env, args[4], &w->privateMode) == napi_ok;
    else valid = napi_get_value_bool(env, args[1], &w->privateMode) == napi_ok;
  }
  if (!valid) { delete w; napi_throw_type_error(env, nullptr, "Invalid Mozc arguments"); return nullptr; }
  napi_value promise, name;
  napi_create_string_utf8(env, "Mozc", NAPI_AUTO_LENGTH, &name);
  if (napi_create_promise(env, &w->deferred, &promise) != napi_ok) { delete w; return nullptr; }
  if (napi_create_async_work(env, nullptr, name, ExecuteEngine, CompleteEngine, w, &w->work) != napi_ok) {
    delete w; napi_throw_error(env, nullptr, "Cannot create Mozc worker"); return nullptr;
  }
  if (napi_queue_async_work(env, w->work) != napi_ok) {
    napi_delete_async_work(env, w->work); delete w; napi_throw_error(env, nullptr, "Cannot queue Mozc worker"); return nullptr;
  }
  return promise;
}
napi_value InitializeMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::Initialize); }
napi_value LearnMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::Learn); }
napi_value ConvertMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::Convert); }
napi_value SegmentMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::Segments); }
napi_value LearnSegmentsMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::LearnSegments); }
napi_value ReverseMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::Reverse); }
napi_value ResizeMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::Resize); }
napi_value NextMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::Next); }
napi_value ClearLearningMozc(napi_env env, napi_callback_info info) { return QueueEngine(env, info, EngineOperation::ClearLearning); }
}
