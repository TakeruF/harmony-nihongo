#!/usr/bin/env python3
"""Final layout, conversion, editor action, language selector and rotation checks."""
import importlib.util
import json
import re
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location('reference_device', Path(__file__).with_name('test-gboard-reference-device.py'))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
d.out = d.root / 'artifacts/gboard-extra-device'
d.out.mkdir(parents=True, exist_ok=True)

def wait_id(identifier):
    deadline = time.monotonic() + 8
    while True:
        tree = d.nodes()
        if any(n.get('id') == identifier for n in tree):
            return tree
        assert time.monotonic() < deadline, identifier + ' did not appear'
        time.sleep(.15)

def flick(identifier, dx, dy, expected):
    x, y = d.point(d.one(identifier))
    d.call('shell', f'uinput -T -d {x} {y} -i 80 -u {x+dx} {y+dy}')
    time.sleep(.2)
    d.wait_value(expected)

def reading():
    flick('key-か', -100, 0, 'き')
    flick('key-や', 0, 100, 'きよ')
    d.tap('key-文字変形')
    d.wait_value('きょ')
    flick('key-あ', 0, -100, 'きょう')
    d.tap('key-は')
    d.wait_value('きょうは')

def rectangle(node):
    return list(map(int, re.findall(r'-?\d+', node.get('origBounds') or node['bounds'])))

def fit_keys(tree):
    key_window = d.one('key-あ', tree)['hostWindowId']
    roots = [n for n in tree if n.get('hostWindowId') == key_window and n.get('type') == 'root']
    assert len(roots) == 1
    limit = rectangle(roots[0])
    system_buttons = [rectangle(n) for n in tree if n.get('id') in ['keyboardLeftButton', 'keyboardRightButton']]
    keys = [n for n in tree if n.get('id', '').startswith('key-')]
    assert keys
    for key in keys:
        x0, y0, x1, y1 = rectangle(key)
        assert x0 >= limit[0] - 1 and x1 <= limit[2] + 1 and y0 >= limit[1] and y1 <= limit[3] + 1, key['id']
        for sx0, sy0, sx1, sy1 in system_buttons:
            assert min(x1, sx1) <= max(x0, sx0) or min(y1, sy1) <= max(y0, sy0), (key['id'], key['bounds'], [sx0, sy0, sx1, sy1])

d.reset()
d.capture('kana-idle', '')
d.tap('key-入力モード')
wait_id('key-a')
d.capture('alphabet-idle', '')
flick('key-a', 0, 100, '2')
d.capture('alphabet-digit', '2')
d.tap('key-削除')
d.wait_value('')
x, y = d.point(d.one('key-a'))
d.call('shell', f'uinput -T -d {x} {y} -i 1600 -u {x} {y}')
time.sleep(.4)
remote = '/data/local/tmp/extra-popup.png'
d.call('shell', 'uitest screenCap -p ' + remote)
d.call('file', 'recv', remote, str(d.out / 'alphabet-popup.png'))
time.sleep(1.8)
d.capture('alphabet-popup-released', 'a')

d.reset()
d.tap('key-入力モード')
wait_id('key-a')
d.tap('key-入力モード')
wait_id('key-1')
d.capture('number-idle', '')
flick('key-1', -100, 0, '☆')
d.capture('number-symbol', '☆')
d.tap('key-削除')
d.wait_value('')
flick('key-0', 0, -100, '…')
d.capture('number-ellipsis', '…')

d.reset()
reading()
wait_id('candidate-0')
assert d.one('candidate-0')['text'] == '今日は'
d.capture('kana-candidates', 'きょうは')
d.tap('candidate-0')
d.capture('candidate-commit', '今日は')
d.tap('singleInput')
wait_id('key-検索')
d.tap('key-検索')
deadline = time.monotonic() + 8
while True:
    actual = d.one('searchCount').get('text', '')
    if actual == '検索アクション: 1':
        break
    assert time.monotonic() < deadline, actual
    time.sleep(.15)
d.capture('search-action', '今日は')
d.results.append({'scenario': 'search-action-count', 'expected': '検索アクション: 1', 'actual': actual, 'pass': True})

d.reset()
reading()
d.call('shell', 'aa start -a EntryAbility -b ' + d.args.editor_bundle + ' --pb validationLandscape true')
deadline = time.monotonic() + 10
while True:
    tree = d.wait_value('きょうは')
    right = list(map(int, re.findall(r'-?\d+', d.one('key-さ', tree)['bounds'])))[2]
    if right > 1080:
        try:
            fit_keys(tree)
            time.sleep(.3)
            tree = d.wait_value('きょうは')
            fit_keys(tree)
            break
        except AssertionError:
            pass
    assert time.monotonic() < deadline, 'Landscape layout did not arrive'
    time.sleep(.2)
fit_keys(tree)
assert d.one('composition', tree)['text'] == 'きょうは'
assert d.one('key-確定', tree)
d.capture('landscape-preserves-reading', 'きょうは')
d.call('shell', 'aa start -a EntryAbility -b ' + d.args.editor_bundle + ' --pb validationLandscape false')
deadline = time.monotonic() + 10
while True:
    tree = d.wait_value('きょうは')
    right = list(map(int, re.findall(r'-?\d+', d.one('key-さ', tree)['bounds'])))[2]
    key = rectangle(d.one('key-あ', tree))
    if right <= 1080 and key[3] - key[1] >= 139:
        break
    assert time.monotonic() < deadline, 'Portrait layout did not arrive'
    time.sleep(.2)
fit_keys(tree)
assert d.one('composition', tree)['text'] == 'きょうは'
assert d.one('key-確定', tree)
d.capture('portrait-preserves-reading', 'きょうは')

d.reset()
d.tap('key-入力言語')
time.sleep(.4)
tree = d.nodes()
(d.out / 'language-selector.json').write_text(json.dumps(tree, ensure_ascii=False, indent=2) + '\n')
remote = '/data/local/tmp/language-selector.png'
d.call('shell', 'uitest screenCap -p ' + remote)
d.call('file', 'recv', remote, str(d.out / 'language-selector.png'))
assert any(n.get('type') == 'Dialog' for n in tree), 'Language selector dialog did not open'
print('Final layout, conversion, search action, rotation and language selector: PASS', flush=True)
(d.out / 'input-results.json').write_text(json.dumps(d.results, ensure_ascii=False, indent=2) + '\n')
