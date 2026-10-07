#!/usr/bin/env python3
"""Actual pinned Mozc host integration: predictions, choice learning, process restart."""
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / '.native-build/mozc/src'
OUT = ROOT / 'artifacts/phase6'
OUT.mkdir(parents=True, exist_ok=True)
p = SRC / 'android/jni/BUILD.bazel'
s = p.read_text()
if 'nihongo_host_probe' not in s:
    s += '\nmozc_cc_binary(name = "nihongo_host_probe", srcs = ["nihongo_engine.cc", "nihongo_probe.cc"], deps = ["//composer", "//engine", "//data_manager", "//base:system_util", "//base:util", "//converter:converter_interface", "//converter:segments", "//request:conversion_request"])\n'
    p.write_text(s)
p.write_text(p.read_text().replace('"//base:system_util", "//converter', '"//base:system_util", "//base:util", "//converter'))
shutil.copyfile(ROOT/'tools/mozc/engine.cc', SRC/'android/jni/nihongo_engine.cc')
shutil.copyfile(ROOT/'tools/mozc/engine_probe.cc', SRC/'android/jni/nihongo_probe.cc')
with (OUT/'host-build.txt').open('w') as log:
    subprocess.run([str(ROOT/'.native-build/bin/bazel'), '--output_user_root=/tmp/nihongo-bazel-root', 'build', '//android/jni:nihongo_host_probe', '--config=oss_macos', '--config=release_build', '--jobs=6'],cwd=SRC,stdout=log,stderr=subprocess.STDOUT,check=True)
with tempfile.TemporaryDirectory(prefix='nihongo-learning-') as profile:
    for name, reading, value in [('prediction','にほ','日本'),('learning','はし','箸'),('learning-restart','はし','箸'),('segments','わたしははしをわたる','--segments'),('resize','わたしははしをわたる','--resize'),('reverse','橋','--reverse')]:
        result = subprocess.run([str(SRC/'bazel-bin/android/jni/nihongo_host_probe'), str(ROOT/'entry/src/main/resources/rawfile/mozc.data'),profile,reading,value],text=True,capture_output=True)
        (OUT/(name+'.txt')).write_text(result.stdout+result.stderr)
        if result.returncode: raise RuntimeError(name+': '+result.stdout+result.stderr)
        if name == 'learning' and result.stdout.startswith('0\t箸\n'): raise RuntimeError('Test requires a non-first candidate before learning')
        if name == 'learning-restart' and not result.stdout.startswith('0\t箸\n'): raise RuntimeError('Learning did not survive restart')
        print(name+': PASS')
