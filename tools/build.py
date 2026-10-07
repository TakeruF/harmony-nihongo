#!/usr/bin/env python3
"""Build with the local DevEco SDK; local signing settings stay outside version control."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--release', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
dev = Path(os.environ.get('NIHONGO_DEVECO_HOME', '/Applications/DevEco-Studio.app/Contents'))
profile = root / 'build-profile.json5'
if not profile.exists():
    shutil.copyfile(root / 'build-profile.template.json5', profile)
    profile.chmod(0o600)
local = root / 'local.properties'
if not local.exists():
    local.write_text('sdk.dir=' + str(dev / 'sdk/default') + '\n')
env = os.environ.copy()
env['DEVECO_SDK_HOME'] = str(dev / 'sdk')
env['JAVA_HOME'] = str(dev / 'jbr/Contents/Home')
env['PATH'] = str(dev / 'tools/node/bin') + os.pathsep + env.get('PATH', '')
subprocess.run(['python3', str(root / 'tools/build-mozc.py')], cwd=root, check=True)
subprocess.run([str(dev / 'tools/ohpm/bin/ohpm'), 'install', '--all'], cwd=root, env=env, check=True)
subprocess.run([str(dev / 'tools/hvigor/bin/hvigorw'), 'assembleHap', '--mode', 'module',
                '-p', 'product=default', '-p', 'module=entry@default', '-p',
                'buildMode=' + ('release' if args.release else 'debug'), '--no-daemon'],
               cwd=root, env=env, check=True)
print('HAP outputs:', root / 'entry/build/default/outputs/default')
print('Install only a signed HAP. Configure debug signing in DevEco Project Structure.')
