#!/usr/bin/env python3
"""Check the currently open, empty external editor using the actual IME.

Never sends a message, submits a search, or erases an existing draft.
The caller must open the intended editor first.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import time

parser = argparse.ArgumentParser()
parser.add_argument('--name', required=True)
parser.add_argument('--editor-type', default='android.widget.EditText')
parser.add_argument('--hint')
parser.add_argument('--editor-id')
parser.add_argument('--password', action='store_true')
parser.add_argument('--basic', action='store_true')
parser.add_argument('--rapid', action='store_true')
parser.add_argument('--live-preview', action='store_true')
parser.add_argument('--numeric-only', action='store_true')
parser.add_argument('--no-screenshots', action='store_true')
args = parser.parse_args()
spec = importlib.util.spec_from_file_location('device', Path(__file__).with_name('test-kana-device.py'))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
out = d.root / 'artifacts/external-editors' / args.name
out.mkdir(parents=True, exist_ok=True)
results = []

def nodes():
    d.call('shell', 'uitest dumpLayout -p /data/local/tmp/external-editor.json')
    d.call('file', 'recv', '/data/local/tmp/external-editor.json', '/tmp/external-editor.json')
    found = []
    def walk(node):
        if isinstance(node, dict):
            if node.get('attributes'): found.append(node['attributes'])
            for value in node.values(): walk(value)
        elif isinstance(node, list):
            for value in node: walk(value)
    walk(json.loads(Path('/tmp/external-editor.json').read_text()))
    return found

def editor():
    found = [n for n in nodes() if args.editor_type in n.get('type', '')]
    if args.hint: found = [n for n in found if n.get('hint') == args.hint]
    if args.editor_id: found = [n for n in found if n.get('id') == args.editor_id]
    focused = [n for n in found if n.get('focused') == 'true']
    if focused: found = focused
    assert len(found) == 1, 'Select a single test editor first'
    return found[0]

def center(node):
    b = list(map(int, re.findall(r'-?\d+', node['bounds'])))
    return (b[0] + b[2]) // 2, (b[1] + b[3]) // 2

def key(label):
    found = [n for n in nodes() if n.get('id') == 'key-' + label or n.get('text') == label]
    assert found, 'Key absent: ' + label
    d.tap(*center(found[0]))
    time.sleep(.15)

def check(name, expected):
    actual = editor().get('text', '')
    if actual != expected and (args.hint == 'IME rich' or args.editor_id == 'rich'):
        # ArkWeb exposes its empty contenteditable caret paragraph as "\\n".
        # Verify the controlled page's actual DOM text instead of that AX placeholder.
        dom_result = 'rich=' + json.dumps(expected, ensure_ascii=False)
        if any(n.get('text') == dom_result for n in nodes()): actual = expected
    results.append({'test': name, 'status': 'PASS' if actual == expected else 'FAIL',
                    'expected': expected, 'actual': actual if actual == expected else '[mismatch]'})
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    assert actual == expected, name + ': input differs'
    print(args.name + ': ' + name + ': PASS', flush=True)

def capture(name):
    if args.no_screenshots: return
    d.call('shell', 'snapshot_display -f /data/local/tmp/external-editor.jpeg')
    d.call('file', 'recv', '/data/local/tmp/external-editor.jpeg', str(out / name))

field = editor()
assert field.get('text', '') == '', 'Refuse to alter a nonempty existing draft'
d.tap(*center(field))
time.sleep(.3)
if args.numeric_only:
    assert any(n.get('id') == 'key-1' for n in nodes()), 'Numeric field must open numeric layout'
    for digit in '123': key(digit)
    check('requested numeric layout and input', '123')
    capture('numeric-field.jpeg')
    for _ in range(3): key('削除')
    check('numeric cleanup', '')
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(args.name + ': numeric editor regression: PASS', flush=True)
    raise SystemExit(0)
assert any(n.get('text') == 'あ' for n in nodes()), 'Select Japanese 12-key first'
if args.password:
    key('あa1')
    for character in 'abc': key(character)
    assert any(n.get('text') == 'password length: 3' for n in nodes()), 'Password insertion length differs'
    for _ in range(3): key('削除')
    assert any(n.get('text') == 'password length: 0' for n in nodes()), 'Password deletion length differs'
    results.append({'test': 'password ASCII insertion and deletion', 'status': 'PASS'})
    key('あa1');key('あa1')
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(args.name + ': password insertion/deletion: PASS', flush=True)
    raise SystemExit(0)
d.kyouha()
time.sleep(.7)
assert any(n.get('id') == 'composition' and n.get('text') == 'きょうは' for n in nodes()), 'Kana queue stalled or lost input'
results.append({'test': 'complete kana reading', 'status': 'PASS'})
if args.live_preview: check('unconverted kana is already in editor', 'きょうは')
capture('kana.jpeg')
key('今日は')
check('Mozc candidate commits once', '今日は')
capture('candidate-commit.jpeg')
key('削除')
check('backspace committed text', '今日')
key('削除')
key('削除')
check('clear only test text', '')
# Both ASCII and kana must pass through the same external InputClient.
key('あa1')
for character in 'abc': key(character)
check('ASCII direct input', 'abc')
for _ in range(3): key('削除')
check('ASCII deletion', '')
if args.rapid:
    expected = 'qwert' * 12
    letters = {n['text']: center(n) for n in nodes() if n.get('text') in ['q', 'w', 'e', 'r', 't']}
    commands = [f'uinput -T -c {letters[ch][0]} {letters[ch][1]} 20' for ch in expected]
    started = time.monotonic()
    d.call('shell', '\n'.join(commands))
    elapsed = time.monotonic() - started
    time.sleep(.4)
    check('60 rapid ASCII taps preserve order', expected)
    (out / 'rapid-timing.json').write_text(json.dumps({'taps': 60, 'elapsed_seconds': elapsed}, indent=2))
    key('削除')
    d.call('shell', 'uinput -T -d 1150 2310 -i 5200 -u 1150 2310')
    time.sleep(.3)
    check('held deletion clears rapid input and stops', '')
key('あa1')
key('1')
check('numeric direct input', '1')
key('削除')
key('あa1')
check('mode cycle preserves empty draft', '')
if args.rapid:
    commands = []
    for _ in range(10):
        commands += ['uinput -T -c 379 1945 20', 'uinput -T -c 628 1945 20', 'uinput -T -c 1125 2490 20']
    d.call('shell', '\n'.join(commands))
    time.sleep(.5)
    check('10 rapid kana commits preserve all text', 'あか' * 10)
    d.call('shell', 'uinput -T -d 1125 1945 -i 2500 -u 1125 1945')
    time.sleep(.3)
    check('rapid kana cleanup', '')
if args.basic:
    capture('final-empty.jpeg')
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(args.name + ': basic external editor regression: PASS', flush=True)
    raise SystemExit(0)
d.kyouha()
time.sleep(.4)
key('確定')
check('kana Enter commits once', 'きょうは')
d.tap(130, 2128)
d.tap(130, 2128)
d.tap(875, 1945)
time.sleep(.2)
key('確定')
check('cursor movement and middle insertion', 'きょさうは')
d.call('shell', 'uinput -T -d 1125 2128 -i 1300 -u 1125 2128')
for _ in range(5): key('削除')
check('cursor hold and cleanup', '')
if any(n.get('id') == 'key-改行' for n in nodes()):
    key('改行')
    check('newline does not send', '\n')
    key('削除')
    check('newline cleanup', '')
# Emoji is inserted through the actual panel, then removed through the IME.
opened = [n for n in nodes() if n.get('id') == 'open-emoji']
assert len(opened) == 1
d.tap(*center(opened[0]))
time.sleep(.2)
key('😀')
check('emoji panel input', '😀')
returned = [n for n in nodes() if n.get('id') == 'emoji-return']
assert len(returned) == 1
d.tap(*center(returned[0]))
key('削除')
check('emoji deletion', '')
capture('final-empty.jpeg')
(out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
print(args.name + ': external editor regression: PASS', flush=True)
