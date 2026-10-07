#!/usr/bin/env python3
"""Pura70 app-owned field checks for flick feedback and held-key lifecycle."""
import importlib.util
import json
from pathlib import Path
import subprocess
import time

spec = importlib.util.spec_from_file_location('device', Path(__file__).with_name('test-kana-device.py'))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
out = d.root / 'artifacts/gboard-polish'
out.mkdir(parents=True, exist_ok=True)
results = []

def check(name, expected):
    actual = d.text('multiInput')
    assert actual == expected, (name, actual, expected)
    results.append({'test': name, 'status': 'PASS'})
    print(name + ': PASS', flush=True)

def capture(name):
    d.call('shell', 'snapshot_display -f /data/local/tmp/polish.jpeg')
    d.call('file', 'recv', '/data/local/tmp/polish.jpeg', str(out / name))

def hold(x, y, duration=1300):
    d.call('shell', f'uinput -T -d {x} {y} -i {duration} -u {x} {y}')
    time.sleep(.2)

def has_key(label):
    d.call('shell', 'uitest dumpLayout -p /data/local/tmp/polish-tree.json')
    d.call('file', 'recv', '/data/local/tmp/polish-tree.json', '/tmp/polish-tree.json')
    found = []
    def walk(node):
        if isinstance(node, dict):
            if node.get('attributes', {}).get('id') == 'key-' + label:
                found.append(node)
            for value in node.values(): walk(value)
        elif isinstance(node, list):
            for value in node: walk(value)
    walk(json.loads(Path('/tmp/polish-tree.json').read_text()))
    return len(found) == 1

assert 'com.takeruf.harmonynihongo,' in d.call('shell', 'ime -g')
d.reset()
assert has_key('改行'), 'Multiline field must show newline action'
results.append({'test': 'multiline newline icon', 'status': 'PASS'})
capture('kana-idle.jpeg')
proc = subprocess.Popen([d.hdc, 'shell', 'uinput -T -d 379 1945 -i 1800 -u 379 1945'], stdout=subprocess.PIPE)
try:
    time.sleep(.35)
    capture('flick-popup.jpeg')
finally:
    proc.communicate(timeout=10)
time.sleep(.3)
check('popup does not duplicate the tap', 'あ')
d.tap(1125, 2490)
check('popup release commits once', 'あ')
capture('kana-committed.jpeg')

seed = 'あか' * 5
d.reset()
for _ in range(5):
    d.tap(379, 1945)
    d.tap(628, 1945)
d.tap(1125, 2490)
check('repeat setup text', seed)
hold(1125, 1945)
check('hold deletes committed text', '')
d.tap(875, 1945)
time.sleep(.6)
check('release stops deletion', 'さ')
d.tap(1125, 2490)

d.reset()
for _ in range(5):
    d.tap(379, 1945)
    d.tap(628, 1945)
d.tap(1125, 2490)
hold(130, 2128)
d.tap(875, 1945)
d.tap(1125, 2490)
check('hold cursor reaches beginning', 'さ' + seed)
capture('cursor-repeat.jpeg')

d.reset()
for _ in range(5):
    d.tap(379, 1945)
    d.tap(628, 1945)
hold(1125, 1945)
check('hold deletes uncommitted kana', '')
d.tap(379, 1945)
time.sleep(.6)
check('new reading survives released hold', 'あ')
capture('kana-candidates.jpeg')
assert has_key('確定'), 'Composition must show commit action'
d.reset(single=True)
assert has_key('検索'), 'Search field must show search action'
capture('search-action.jpeg')
d.call('shell', 'uitest uiInput click 628 1190')
time.sleep(.3)
assert has_key('改行'), 'Editor switch must refresh action icon'
results.append({'test': 'search to multiline action refresh', 'status': 'PASS'})
(out / 'polish-device-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
print('Keyboard polish device regression: PASS', flush=True)
