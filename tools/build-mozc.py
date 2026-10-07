#!/usr/bin/env python3
"""Pinned Mozc OSS dictionary + ARM64 HarmonyOS library. macOS ARM64 / DevEco SDK."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.native-build'
SOURCE = CACHE / 'mozc'
SRC = SOURCE / 'src'
REVISION = '60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98'
BAZEL = CACHE / 'bin/bazel'
BAZEL_SHA256 = '2c3cce548a4b6a97a2a5267712187b784b52714c4a2b0613e7386b15669d783c'
BAZEL_ROOT = '/tmp/nihongo-bazel-root'

def copy(source, destination):
    source, destination = Path(source), Path(destination)
    if destination.is_dir(): destination = destination / source.name
    if destination.exists(): destination.chmod(0o644)
    shutil.copyfile(source, destination)
    destination.chmod(0o644)

def run(args, cwd=SRC):
    subprocess.run(args, cwd=cwd, check=True)

def bazel(*args):
    run([str(BAZEL), '--output_user_root=' + BAZEL_ROOT, *args])

CACHE.mkdir(exist_ok=True)
if not BAZEL.exists():
    BAZEL.parent.mkdir(exist_ok=True)
    urllib.request.urlretrieve('https://github.com/bazelbuild/bazel/releases/download/9.0.0/bazel-9.0.0-darwin-arm64', BAZEL)
if hashlib.sha256(BAZEL.read_bytes()).hexdigest() != BAZEL_SHA256:
    raise SystemExit('Bazel SHA256 mismatch')
BAZEL.chmod(0o755)
if not SOURCE.exists():
    run(['git', 'clone', 'https://github.com/google/mozc.git', str(SOURCE)], cwd=ROOT)
    run(['git', 'checkout', '--detach', REVISION], cwd=SOURCE)
if (SOURCE / '.git').exists():
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=SOURCE, text=True).strip()
else:
    actual = (SOURCE / '.nihongo-source-revision').read_text().strip()
if actual != REVISION:
    raise SystemExit('Cached Mozc source revision mismatch')
# The generated checkout is private to this build; no Android NDK is needed.
p = SRC / 'MODULE.bazel'
p.write_text(p.read_text().replace('register_toolchains("@androidndk//:all")', ''))
# Clang 15 compatibility: equivalent initialization/capture, no conversion changes.
p = SRC / 'dictionary/file/codec.cc'
p.write_text(p.read_text().replace('sections->emplace_back(absl::string_view(ptr, data_size), fingerprint);',
    'sections->push_back(DictionaryFileSection{absl::string_view(ptr, data_size), fingerprint});'))
p = SRC / 'prediction/user_history_predictor.cc'
p.write_text(p.read_text().replace('auto [request_key, base_key, expanded] = GetInputKeyFromRequest(request);',
    'auto input_keys = GetInputKeyFromRequest(request);\n  auto request_key = std::get<0>(input_keys);\n  auto base_key = std::get<1>(input_keys);\n  auto expanded = std::move(std::get<2>(input_keys));'))
(SRC / 'harmony').mkdir(exist_ok=True)
copy(ROOT / 'tools/mozc/ohos_toolchain.bzl', SRC / 'harmony')
copy(ROOT / 'tools/mozc/BUILD.toolchain', SRC / 'harmony/BUILD.bazel')
copy(ROOT / 'tools/mozc/engine.cc', SRC / 'android/jni/nihongo_engine.cc')
p = SRC / 'android/jni/BUILD.bazel'
if 'name = "libnihongo_engine.so"' not in p.read_text():
    with p.open('a') as file:
        file.write('''\nmozc_cc_binary(
 name = "libnihongo_engine.so", srcs = ["nihongo_engine.cc"],
 linkshared = True, linkstatic = True, linkopts = ["-Wl,-soname,libnihongo_engine.so"],
 deps = ["//composer", "//engine", "//data_manager", "//base:system_util", "//base:util", "//converter:converter_interface", "//converter:segments", "//request:conversion_request"],
)\n''')
p.write_text(p.read_text().replace('deps = ["//engine", "//data_manager"', 'deps = ["//composer", "//engine", "//data_manager"'))
p.write_text(p.read_text().replace('"//base:system_util", "//converter', '"//base:system_util", "//base:util", "//converter'))
bazel('build', '//data_manager/oss:mozc.data', '--config=oss_macos', '--config=release_build', '--jobs=6')
raw = ROOT / 'entry/src/main/resources/rawfile'
raw.mkdir(exist_ok=True)
copy(SRC / 'bazel-bin/data_manager/oss/mozc.data', raw / 'mozc.data')
bazel('build', '//android/jni:libnihongo_engine.so', '--noenable_platform_specific_config', '--config=compiler_gcc_like', '--define', 'TARGET=oss_linux', '--platforms=//harmony:arm64', '--extra_toolchains=//harmony:toolchain', '--compilation_mode=opt', '--jobs=6')
copy(SRC / 'bazel-bin/android/jni/libnihongo_engine.so', CACHE / 'libnihongo_engine.so')
libs = ROOT / 'entry/libs/arm64-v8a'
libs.mkdir(parents=True, exist_ok=True)
copy(CACHE / 'libnihongo_engine.so', libs)
# Include every dictionary and linked dependency notice in the installed HAP.
base = subprocess.check_output([str(BAZEL), '--output_user_root=' + BAZEL_ROOT, 'info', 'output_base'], cwd=SRC, text=True).strip()
ext = Path(base) / 'external'
notices = [SOURCE / 'LICENSE', SRC / 'data/dictionary_oss/README.txt']
for dep in ['abseil-cpp+', 'protobuf+', 'zlib+', 're2+', '+http_archive+ja_usage_dict']:
    folder = ext / dep
    for name in ['LICENSE', 'LICENSE.txt', 'COPYING', 'NOTICE']:
        if (folder / name).is_file(): notices.append(folder / name)
    if (folder / 'third_party/utf8_range/LICENSE').is_file(): notices.append(folder / 'third_party/utf8_range/LICENSE')
output = 'Harmony Nihongo uses Mozc OSS ' + REVISION + '\n\n'
for notice in notices:
    output += '\n===== ' + str(notice.relative_to(SOURCE) if notice.is_relative_to(SOURCE) else notice.relative_to(ext)) + ' =====\n' + notice.read_text() + '\n'
(raw / 'third-party-notices.txt').write_text(output)
print('Mozc build ready:', CACHE / 'libnihongo_engine.so')
