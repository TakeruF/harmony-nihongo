#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
extern "C" int nihongo_engine_init(const char*, const char*);
extern "C" int nihongo_engine_convert(const char*, int);
extern "C" const char* nihongo_engine_candidate(int);
extern "C" int nihongo_engine_learn(const char*, const char*);
extern "C" int nihongo_engine_segments(const char*, int);
extern "C" int nihongo_engine_segment_size(int);
extern "C" const char* nihongo_engine_segment_value(int, int);
extern "C" int nihongo_engine_learn_segments(const char*, const char* const*, const char* const*, int);
extern "C" int nihongo_engine_resize(const char*, const int*, int, int, int, int);
extern "C" const char* nihongo_engine_reverse(const char*);
extern "C" int nihongo_engine_next(const char*, int);
extern "C" int nihongo_engine_clear_learning();
int main(int argc, char** argv) {
  if (argc != 5 || !nihongo_engine_init(argv[1], argv[2])) return 2;
  if (std::strcmp(argv[4], "--next") == 0) {
    const int count = nihongo_engine_next(argv[3], 1);
    std::printf("NEXT_COUNT=%d\n", count);
    if (count == 0) return 40;
    bool found = false;
    for (int i = 0; i < count; ++i) {
      const char* key = nihongo_engine_segment_value(i, 0);
      const char* value = nihongo_engine_segment_value(i, 1);
      std::printf("NEXT=%s\t%s\n", key, value);
      if (!*key || !*value || std::strcmp(value, argv[3]) == 0) return 41;
      if (std::strcmp(value, "ございます") == 0) found = true;
    }
    if (std::strcmp(argv[3], "おはよう") == 0 && !found) return 42;
    if (nihongo_engine_next("", 0) != 0) return 43;
    return 0;
  }
  if (std::strcmp(argv[4], "--clear") == 0) {
    if (!nihongo_engine_clear_learning()) return 44;
    nihongo_engine_convert("はし", 0);
    if (std::strcmp(nihongo_engine_candidate(0), "箸") == 0) return 45;
    if (nihongo_engine_learn("きょうは", "今日は")) return 46;
    std::puts("CLEAR_LEARNING=PASS"); return 0;
  }
  if (std::strcmp(argv[4], "--reverse") == 0) {
    const std::string reading = nihongo_engine_reverse(argv[3]);
    std::printf("REVERSE=%s\n",reading.c_str());
    if (reading != "はし") return 30;
    nihongo_engine_convert(reading.c_str(),0);
    bool found=false;
    for (int i=0;i<64;i++) if (std::strcmp(nihongo_engine_candidate(i),"箸")==0) found=true;
    return found ? 0 : 31;
  }
  if (std::strcmp(argv[4], "--segments") == 0) {
    const int count = nihongo_engine_segments(argv[3], 0);
    if (count < 2) return 8;
    std::string reading, best, chosen;
    std::vector<std::string> selected, keys;
    for (int i = 0; i < count; ++i) {
      keys.emplace_back(nihongo_engine_segment_value(i, 0));
      reading += keys.back();
      best += nihongo_engine_segment_value(i, 1);
      const int index = i < 2 && nihongo_engine_segment_size(i) > 2 ? 2 : 1;
      selected.emplace_back(nihongo_engine_segment_value(i, index));
      chosen += selected.back();
      std::printf("SEGMENT_%d=%s -> %s\n", i, nihongo_engine_segment_value(i, 0), selected.back().c_str());
    }
    if (reading != argv[3] || best == chosen) return 9;
    std::vector<const char*> values, key_ptrs;
    for (const auto& key : keys) key_ptrs.push_back(key.c_str());
    for (const auto& value : selected) values.push_back(value.c_str());
    values.back() = "not-a-candidate";
    if (nihongo_engine_learn_segments(argv[3], values.data(), key_ptrs.data(), count)) return 10;
    values.back() = selected.back().c_str();
    if (nihongo_engine_learn_segments(argv[3], values.data(), key_ptrs.data(), count - 1)) return 11;
    if (!nihongo_engine_learn_segments(argv[3], values.data(), key_ptrs.data(), count)) return 12;
    std::printf("COMBINED=%s\nSEGMENT_LEARNING=PASS\n", chosen.c_str());
    return 0;
  }
  if (std::strcmp(argv[4], "--resize") == 0) {
    const int lengths[] = {4,3,3};
    if (nihongo_engine_resize(argv[3], lengths, 3, 0, -1, 0) < 2) return 20;
    if (std::strcmp(nihongo_engine_segment_value(0,0), "わたし") != 0) return 21;
    std::string all;
    const int count = nihongo_engine_resize(argv[3], lengths, 3, 0, 1, 0);
    if (count < 2 || std::strcmp(nihongo_engine_segment_value(0,0), "わたしはは") != 0) return 22;
    std::vector<std::string> values, keys;
    for (int i = 0; i < count; ++i) {
      keys.emplace_back(nihongo_engine_segment_value(i,0)); all += keys.back();
      values.emplace_back(nihongo_engine_segment_value(i,1));
      std::printf("RESIZED_%d=%s -> %s\n",i,keys.back().c_str(),values.back().c_str());
    }
    if (all != argv[3]) return 23;
    std::vector<const char*> v, k;
    for (int i=0;i<count;++i) { v.push_back(values[i].c_str());k.push_back(keys[i].c_str()); }
    k[0]="wrong-boundary";
    if (nihongo_engine_learn_segments(argv[3],v.data(),k.data(),count)) return 24;
    k[0]=keys[0].c_str();
    if (!nihongo_engine_learn_segments(argv[3],v.data(),k.data(),count)) return 25;
    const int one[] = {10};
    if (nihongo_engine_resize(argv[3], one, 1, 0, 1, 0)) return 26;
    const int invalid[] = {4,3,2};
    if (nihongo_engine_resize(argv[3], invalid, 3, 0, 1, 0)) return 27;
    std::puts("BOUNDARY_RESIZE_AND_LEARNING=PASS");return 0;
  }
  // Private queries do not retain learnable snapshots, even with matching text.
  nihongo_engine_convert(argv[3], 1);
  if (nihongo_engine_learn(argv[3], argv[4])) return 6;
  if (nihongo_engine_learn(argv[3], "not-a-candidate")) return 7;
  int count = nihongo_engine_convert(argv[3], 0);
  int index = -1;
  for (int i = 0; i < count; ++i) {
    const char* value = nihongo_engine_candidate(i);
    std::printf("%d\t%s\n", i, value);
    if (std::strcmp(value, argv[4]) == 0) index = i;
  }
  if (index < 0) return 3;
  std::printf("FOUND=%d\n", index);
  if (std::strcmp(argv[3], "はし") == 0) {
    if (!nihongo_engine_learn(argv[3], argv[4])) return 4;
    nihongo_engine_convert(argv[3], 0);
    std::printf("LEARNED_FIRST=%s\n", nihongo_engine_candidate(0));
    if (std::strcmp(nihongo_engine_candidate(0), argv[4]) != 0) return 5;
  }
  return 0;
}
