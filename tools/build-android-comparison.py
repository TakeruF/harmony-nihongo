#!/usr/bin/env python3
"""Build the isolated Android editor used to measure Gboard; not the Harmony app."""
import argparse
import os
import subprocess
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--sdk', type=Path, required=True)
parser.add_argument('--java-home', type=Path, required=True)
parser.add_argument('--build-tools', default='36.0.0')
parser.add_argument('--serial', help='Optionally install on a selected Android emulator')
args = parser.parse_args()
if args.serial:
    assert args.serial.startswith('emulator-'), 'This fixture installer targets emulators only'
root = Path(__file__).resolve().parents[1]
fixture = root / 'tools/fixtures/android-editor'
out = root / 'artifacts/android-editor'
for name in ['classes', 'dex']:
    (out / name).mkdir(parents=True, exist_ok=True)
java = args.java_home.resolve()
sdk = args.sdk.resolve()
bt = sdk / 'build-tools' / args.build_tools
android_jar = sdk / 'platforms/android-36/android.jar'
env = dict(os.environ, JAVA_HOME=str(java))

def run(*command):
    subprocess.run([str(part) for part in command], check=True, env=env)

run(java / 'bin/javac', '--release', '8', '-classpath', android_jar,
    '-d', out / 'classes', fixture / 'MainActivity.java')
run(bt / 'd8', '--lib', android_jar, '--output', out / 'dex',
    *sorted((out / 'classes').rglob('*.class')))
run(bt / 'aapt2', 'link', '-o', out / 'unsigned.apk', '-I', android_jar,
    '--manifest', fixture / 'AndroidManifest.xml')
with zipfile.ZipFile(out / 'unsigned.apk', 'a') as archive:
    archive.write(out / 'dex/classes.dex', 'classes.dex')
key = out / 'fixture-only.p12'
if not key.exists():
    run(java / 'bin/keytool', '-genkeypair', '-keystore', key, '-storepass', 'comparison-fixture',
        '-keypass', 'comparison-fixture', '-alias', 'fixture', '-keyalg', 'RSA', '-keysize', '2048',
        '-validity', '30', '-dname', 'CN=Local emulator comparison fixture')
    key.chmod(0o600)
run(bt / 'apksigner', 'sign', '--ks', key, '--ks-pass', 'pass:comparison-fixture',
    '--key-pass', 'pass:comparison-fixture', '--out', out / 'comparison-probe.apk', out / 'unsigned.apk')
if args.serial:
    run(sdk / 'platform-tools/adb', '-s', args.serial, 'install', '--no-incremental', '-r', out / 'comparison-probe.apk')
print(out / 'comparison-probe.apk')
