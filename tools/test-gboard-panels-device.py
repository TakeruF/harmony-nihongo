#!/usr/bin/env python3
"""Pura70: Gboard panel layout, secure paste, editing, pins and isolated clip input."""
import importlib.util
import json
import re
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location('reference_device', Path(__file__).with_name('test-gboard-reference-device.py'))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
d.out = d.root / 'artifacts/gboard-panel-parity-2026-10-10'
d.out.mkdir(parents=True, exist_ok=True)
results = []

def record(name):
    results.append({'scenario': name, 'pass': True})
    (d.out / 'panel-device-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
    print(name + ': PASS', flush=True)

def wait_id(identifier):
    deadline = time.monotonic() + 12
    while True:
        tree = d.nodes()
        if any(n.get('id') == identifier for n in tree):
            return tree
        assert time.monotonic() < deadline, identifier
        time.sleep(.2)

def capture(name):
    remote = '/data/local/tmp/nihongo-panels.jpeg'
    d.call('shell', 'snapshot_display -f ' + remote)
    d.call('file', 'recv', remote, str(d.out / name))

def rectangle(node):
    return list(map(int, re.findall(r'-?\d+', node.get('origBounds') or node['bounds'])))

def items(tree=None):
    return [n for n in (tree or d.nodes()) if n.get('id', '').startswith('clipboard-item-')]

def item(text):
    found = [n for n in items() if n.get('text') == text]
    assert len(found) == 1, (text, found)
    return found[0]

def add_clip(key, expected, with_emoji=False):
    d.tap('clipboard-edit'); d.tap('clipboard-add'); wait_id('clipboard-draft')
    d.tap('key-' + key)
    assert d.one('clipboard-draft').get('text') == expected
    if with_emoji:
        d.tap('key-絵文字記号'); wait_id('emoji-😀'); d.tap('emoji-😀'); d.tap('emoji-back'); wait_id('clipboard-draft')
        expected += '😀'
        assert d.one('clipboard-draft').get('text') == expected
        d.tap('key-削除'); assert d.one('clipboard-draft').get('text') == expected[:-1]
        d.tap('key-絵文字記号'); wait_id('emoji-😀'); d.tap('emoji-😀'); d.tap('emoji-back'); wait_id('clipboard-draft')
        assert d.one('clipboard-draft').get('text') == expected
    d.wait_value('ClipboardProbeA')
    d.tap('clipboard-add-save'); wait_id('clipboard-edit')
    item(expected); d.wait_value('ClipboardProbeA')
    record('add ' + expected + ' without editing the app')

assert 'FULL_EXPERIENCE_MODE' in d.call('shell', 'ime -g')
d.reset(); d.tap('open-clipboard'); tree = wait_id('clipboard-header')
assert not items(tree), 'Use a fresh unpinned test installation'
header = d.one('clipboard-header', tree)
window = next(n for n in tree if n.get('type') == 'root' and n.get('hostWindowId') == header['hostWindowId'])
b = rectangle(window); width = b[2] - b[0]
for identifier, expected in [('clipboard-return', 39/608), ('clipboard-toggle', 485/608), ('clipboard-edit', 569/608)]:
    x, _ = d.point(d.one(identifier, tree))
    assert abs((x-b[0])/width-expected) < .018, (identifier, x, width, expected)
capture('clipboard-empty.jpeg'); record('Gboard back/toggle/edit positions')
d.tap('clipboard-return'); wait_id('key-あ'); record('top left back returns to kana')

source = d.one('singleInput'); x, y = d.point(source)
d.call('shell', f'uitest uiInput inputText {x} {y} ClipboardProbeA')
assert d.one('singleInput').get('text') == 'ClipboardProbeA'
b = rectangle(d.one('singleInput'))
d.call('shell', f'uitest uiInput longClick {b[0]+100} {(b[1]+b[3])//2}')
tree = d.nodes(); copy = [n for n in tree if n.get('text') == '复制']; assert len(copy) == 1
d.tap_at(*d.point(copy[0])); d.tap('multiInput'); wait_id('key-あ')
d.tap('open-clipboard'); wait_id('clipboard-paste'); d.tap('clipboard-paste')
d.wait_value('ClipboardProbeA'); item('ClipboardProbeA'); record('secure paste inserts once and remembers the clip')
add_clip('あ', 'あ', with_emoji=True); add_clip('か', 'か')
tree = d.nodes(); cards = items(tree); assert len(cards) == 3
xs = {rectangle(n)[0] for n in cards}; assert len(xs) == 2, xs
capture('clipboard-cards.jpeg'); record('three clips arranged in two columns')
d.tap('clipboard-edit'); d.tap('clipboard-add'); wait_id('clipboard-draft')
x,y=d.point(d.one('key-入力モード'));d.call('shell',f'uinput -T -d {x} {y} -i 1000 -u {x} {y}')
wait_id('key-k'); d.tap('key-k'); d.tap('key-i')
assert d.one('clipboard-draft').get('text') == 'き'
d.wait_value('ClipboardProbeA'); d.tap('clipboard-add-save'); wait_id('clipboard-edit'); item('き')
record('QWERTY romaji clip input remains isolated from the app')

d.tap('clipboard-edit'); tree = wait_id('clipboard-pin')
assert d.one('clipboard-clear', tree).get('enabled') == 'false'
assert d.one('clipboard-pin', tree).get('enabled') == 'false'
d.tap(item('あ😀')['id']); capture('clipboard-selection.jpeg')
assert d.one('clipboard-title').get('text') == '1件を選択中'
d.tap('clipboard-pin'); record('selected clip pinned from the top toolbar')
d.tap('clipboard-return'); wait_id('clipboard-edit'); d.tap('clipboard-return'); wait_id('key-あ')
d.reset(); d.tap('open-clipboard'); wait_id('clipboard-header')
assert [n.get('text') for n in items()] == ['あ😀']
capture('clipboard-pin-restart.jpeg'); record('pin survives restart while transient clips disappear')
d.tap('clipboard-toggle'); wait_id('clipboard-enable'); capture('clipboard-disabled.jpeg')
d.tap('clipboard-enable'); wait_id('clipboard-edit'); item('あ😀'); record('disable and enable preserve the pin')

d.call('shell', 'aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape true')
deadline = time.monotonic() + 12
while True:
    tree = d.nodes(); header = d.one('clipboard-header', tree)
    limits = rectangle(header)
    if limits[2] - limits[0] > 1256:
        break
    assert time.monotonic() < deadline, 'Landscape did not arrive'
    time.sleep(.2)
for identifier in ['clipboard-return','clipboard-toggle','clipboard-edit']:
    r = rectangle(d.one(identifier, tree))
    assert r[0] >= limits[0]-1 and r[2] <= limits[2]+1 and r[1] >= limits[1]-1 and r[3] <= limits[3]+1
capture('clipboard-landscape.jpeg'); record('landscape header buttons fit')
d.call('shell', 'aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape false')
time.sleep(.4)
d.tap('clipboard-edit'); d.tap(item('あ😀')['id']); d.tap('clipboard-clear')
assert not items(); d.tap('clipboard-return'); d.tap('clipboard-return'); wait_id('key-あ')
record('selected clip deleted and back returns to input')

d.tap('key-入力モード'); wait_id('key-a'); d.tap('open-clipboard'); d.tap('clipboard-return'); wait_id('key-a')
record('back preserves alphabet input mode')
d.reset(); d.tap('open-emoji'); wait_id('emoji-back'); capture('emoji-panel.jpeg')
d.tap('emoji-back'); wait_id('key-あ'); record('emoji top left back returns to input')
d.reset(); record('controlled app fields cleaned')
