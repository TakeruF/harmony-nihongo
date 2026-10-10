#ifdef NIHONGO_HOST_TEST
#include <node_api.h>
#else
#include "napi/native_api.h"
#endif
#include <string>
#include <vector>
#ifndef NIHONGO_HOST_TEST
#include "mozc_napi.h"
#endif

static napi_value Add(napi_env env, napi_callback_info info) {
    size_t count = 2;
    napi_value args[2] = {nullptr, nullptr};
    if (napi_get_cb_info(env, info, &count, args, nullptr, nullptr) != napi_ok || count != 2) {
        napi_throw_type_error(env, nullptr, "add requires two numbers"); return nullptr;
    }
    double a, b;
    if (napi_get_value_double(env, args[0], &a) != napi_ok ||
        napi_get_value_double(env, args[1], &b) != napi_ok) {
        napi_throw_type_error(env, nullptr, "add requires two numbers"); return nullptr;
    }
    napi_value result;
    if (napi_create_double(env, a + b, &result) != napi_ok) { return nullptr; }
    return result;
}
static napi_value Echo(napi_env env, napi_callback_info info) {
    size_t count = 1;
    napi_value args[1] = {nullptr};
    if (napi_get_cb_info(env, info, &count, args, nullptr, nullptr) != napi_ok || count != 1) {
        napi_throw_type_error(env, nullptr, "echo requires a string"); return nullptr;
    }
    size_t length = 0;
    if (napi_get_value_string_utf8(env, args[0], nullptr, 0, &length) != napi_ok) {
        napi_throw_type_error(env, nullptr, "echo requires a string"); return nullptr;
    }
    if (length > 4096) { napi_throw_range_error(env, nullptr, "probe text too long"); return nullptr; }
    std::vector<char> buffer(length + 1);
    size_t copied = 0;
    if (napi_get_value_string_utf8(env, args[0], buffer.data(), buffer.size(), &copied) != napi_ok) {
        return nullptr;
    }
    napi_value result;
    if (napi_create_string_utf8(env, buffer.data(), copied, &result) != napi_ok) { return nullptr; }
    return result;
}
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor methods[] = {
        {"add", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"echo", nullptr, Echo, nullptr, nullptr, nullptr, napi_default, nullptr},
#ifndef NIHONGO_HOST_TEST
        {"initializeMozc", nullptr, InitializeMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"learn", nullptr, LearnMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"reverse", nullptr, ReverseMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"resizeSegments", nullptr, ResizeMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"segments", nullptr, SegmentMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"learnSegments", nullptr, LearnSegmentsMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"convert", nullptr, ConvertMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"predictNext", nullptr, NextMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"clearLearning", nullptr, ClearLearningMozc, nullptr, nullptr, nullptr, napi_default, nullptr},
#endif
    };
    if (napi_define_properties(env, exports, sizeof(methods) / sizeof(methods[0]), methods) != napi_ok) { return nullptr; }
    return exports;
}
static napi_module module = {
    .nm_version = 1, .nm_flags = 0, .nm_filename = nullptr,
    .nm_register_func = Init, .nm_modname = "nihongo", .nm_priv = nullptr, .reserved = {0}
};
extern "C" __attribute__((constructor)) void RegisterNihongoModule() {
    napi_module_register(&module);
}
