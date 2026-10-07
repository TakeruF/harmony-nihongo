#!/usr/bin/env python3
"""Real flick input + first Mozc candidate commit in BASIC mode, Pura 70 portrait."""
import importlib.util
import json
from pathlib import Path
import time

spec = importlib.util.spec_from_file_location('device', Path(__file__).with_name('test-kana-device.py'))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
output = d.root / 'artifacts/phase2'
output.mkdir(parents=True, exist_ok=True)
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('--controls-only', action='store_true')
args = parser.parse_args()
result_file = output / 'conversion-results.json'
results = json.loads(result_file.read_text()) if args.controls_only and result_file.exists() else []
results = [r for r in results if r['expected'] == r['actual']]
def check(name, expected, identifier='multiInput'):
    actual = d.text(identifier)
    results.append({'test': name, 'expected': expected, 'actual': actual})
    (output / 'conversion-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    assert actual == expected, (name, expected, actual)
    print(name + ': PASS', flush=True)
def candidate():
    time.sleep(.4)
    d.tap(135,1775)
def nihongo():
    d.flick(628,2128,-100,0) # に
    d.flick(875,2128,0,100) # ほ
    d.flick(628,2490,0,-100) # ん
    d.flick(628,1945,0,100);d.tap(379,2490) # ご

def capture(name):
    d.call('shell', 'uitest screenCap -p /data/local/tmp/nihongo-phase2.png')
    d.call('file','recv','/data/local/tmp/nihongo-phase2.png',str(output/name))

assert 'BASIC_MODE' in d.call('shell','ime -g')
if not args.controls_only:
    for enter, reading, converted in [(d.kyouha,'きょうは','今日は'),(d.gakkou,'がっこう','学校'),(nihongo,'にほんご','日本語')]:
        d.reset(); enter(); check(reading + ' preview', reading)
        if reading == 'きょうは': capture('candidates.png')
        candidate(); check(converted + ' commit once', converted)
        d.tap(379,1945); d.tap(1125,2490);check(converted + ' next kana preserved', converted+'あ')
    d.reset(single=True); d.kyouha(); check('conversion local fallback before commit', '', 'singleInput')
    candidate(); check('conversion local fallback once', '今日は', 'singleInput')
    check('candidate commit does not submit', '検索アクション: 0','searchCount')
    d.tap(1125,2490);check('Enter after candidate submits', '検索アクション: 1','searchCount')
d.reset();d.kyouha();time.sleep(.4);capture('candidates.png');d.tap(1175,1775);capture('expanded.png')
d.tap(135,1950);check('expanded candidate commit once', '今日は')
d.reset(single=True);d.kyouha();time.sleep(.4)
d.call('shell','uitest uiInput click 628 1190');candidate();check('old candidate cannot commit in new editor','')
d.reset()
commands = '\n'.join(['uinput -T -c 379 1945 10'] * 80)
started = time.monotonic()
d.call('shell', commands)
elapsed = time.monotonic() - started
check('80 rapid injected touches preserve kana', 'あ' * 80)
d.tap(1125,2490);check('80 rapid touches commit once', 'あ' * 80)
(output / 'touch-timing.json').write_text(json.dumps({'touches':80,'elapsed_seconds':elapsed,'injection':'HDC uinput, 10ms down/up; includes process overhead'},indent=2))
print('Mozc device conversion: PASS', flush=True)
