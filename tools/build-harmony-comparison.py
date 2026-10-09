#!/usr/bin/env python3
"""Build an independent native editor for IME comparison. No signing/installation."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/harmony-editor')
parser.add_argument('--deveco', type=Path, default=Path('/Applications/DevEco-Studio.app/Contents'))
args = parser.parse_args()
out = args.output.resolve()
if out == ROOT or ROOT.is_relative_to(out):
    raise SystemExit('Choose a separate output folder')
marker = out / '.harmony-comparison-generated'
if out.exists() and any(out.iterdir()) and not marker.exists():
    raise SystemExit('Output is not an empty or generated fixture folder')
out.mkdir(parents=True, exist_ok=True)
marker.write_text('Generated independent editor fixture\n')
for name in ['hvigorfile.ts', 'oh-package.json5', 'hvigor/hvigor-config.json5', 'entry/hvigorfile.ts']:
    dest = out / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / name, dest)
shutil.copy2(ROOT / 'build-profile.template.json5', out / 'build-profile.json5')
shutil.copytree(ROOT / 'AppScope', out / 'AppScope', dirs_exist_ok=True)
shutil.copytree(ROOT / 'entry/src/main/resources', out / 'entry/src/main/resources', dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('rawfile'))
app = json.loads((out / 'AppScope/app.json5').read_text())
app['app'].update(bundleName='com.takeruf.imecompareharmony', versionCode=1, versionName='1.0.0')
(out / 'AppScope/app.json5').write_text(json.dumps(app, ensure_ascii=False, indent=2) + '\n')
module = json.loads((ROOT / 'entry/src/main/module.json5').read_text())
module['module'].pop('extensionAbilities')
module['module']['requestPermissions'] = []
(out / 'entry/src/main/module.json5').write_text(json.dumps(module, indent=2) + '\n')
(out / 'entry/build-profile.json5').write_text(json.dumps({
    'apiType': 'stageMode', 'buildOption': {}, 'targets': [{'name': 'default'}]
}, indent=2) + '\n')
(out / 'entry/oh-package.json5').write_text('{"name":"entry","version":"1.0.0","dependencies":{}}\n')
(out / 'entry/src/main/resources/base/profile/main_pages.json').write_text('{"src":["pages/Index"]}\n')
ets = out / 'entry/src/main/ets'
for name in ['pages', 'entryability', 'input']:
    (ets / name).mkdir(parents=True, exist_ok=True)
index = (ROOT / 'entry/src/main/ets/pages/Index.ets').read_text().replace('Harmony Nihongo', 'IME 比較')
start = index.index("        Button() { Text('設定')")
end = index.index('\n      }.width', start)
index = index[:start] + index[end:]
(ets / 'pages/Index.ets').write_text(index)
shutil.copy2(ROOT / 'entry/src/main/ets/input/PreviewFieldValue.ets', ets / 'input/PreviewFieldValue.ets')
shutil.copy2(ROOT / 'tools/fixtures/harmony-editor/EntryAbility.ets', ets / 'entryability/EntryAbility.ets')
env = os.environ.copy()
env.update(DEVECO_SDK_HOME=str(args.deveco / 'sdk'), JAVA_HOME=str(args.deveco / 'jbr/Contents/Home'))
env['PATH'] = str(args.deveco / 'tools/node/bin') + os.pathsep + env['PATH']
subprocess.run([str(args.deveco / 'tools/hvigor/bin/hvigorw'), 'assembleHap', '--mode', 'module',
                '-p', 'product=default', '-p', 'module=entry@default', '-p', 'buildMode=debug', '--no-daemon'],
                cwd=out, env=env, check=True)
print('Independent editor unsigned HAP:', out / 'entry/build/default/outputs/default/entry-default-unsigned.hap')
