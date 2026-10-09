#!/usr/bin/env python3
"""Compare actual Harmony IME input with recorded Gboard scenarios, using UI bounds."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--target', required=True, help='HDC target from hdc list targets')
parser.add_argument('--editor-bundle', default='com.takeruf.harmonynihongo', choices=['com.takeruf.harmonynihongo','com.takeruf.imecompareharmony'], help='Own editor fixture to restart; independent fixture leaves the IME running')
parser.add_argument('--full', action='store_true', help='Also check all 170 recorded kana, alphabet and number directions')
parser.add_argument('--hdc', default='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / 'artifacts/gboard-reference-device'
out.mkdir(parents=True, exist_ok=True)
command = [args.hdc, '-t', args.target]
results = []

def call(*values):
    return subprocess.check_output(command + list(values), text=True, timeout=20)

def nodes():
    remote = '/data/local/tmp/harmony-reference-tree.json'
    call('shell', 'uitest dumpLayout -p ' + remote)
    path = out / 'latest-tree.json'
    call('file', 'recv', remote, str(path))
    data = json.loads(path.read_text())
    found = []
    def walk(item, bundle=''):
        if isinstance(item, dict):
            if 'attributes' in item:
                attributes = item['attributes']
                bundle = attributes.get('bundleName') or bundle
                found.append(dict(attributes, bundleName=bundle))
            for value in item.values():
                walk(value, bundle)
        elif isinstance(item, list):
            for value in item:
                walk(value, bundle)
    walk(data)
    return found

def one(identifier, tree=None):
    found = [n for n in (tree if tree is not None else nodes()) if n.get('id') == identifier and (identifier not in ['multiInput','singleInput','searchCount'] or n.get('bundleName') == args.editor_bundle)]
    assert len(found) == 1, (identifier, len(found))
    return found[0]

def point(node):
    x0, y0, x1, y1 = map(int, re.findall(r'-?\d+', node['bounds']))
    return (x0 + x1) // 2, (y0 + y1) // 2

def tap_at(x, y):
    call('shell', f'uinput -T -c {x} {y} 20')

def tap(identifier):
    tap_at(*point(one(identifier)))

def reset():
    call('shell', 'power-shell wakeup')
    call('shell', 'aa force-stop ' + args.editor_bundle)
    # aa returns before the old window closes; never focus its stale TextArea.
    deadline = time.monotonic() + 8
    while any(n.get('id') == 'multiInput' and n.get('bundleName') == args.editor_bundle for n in nodes()):
        assert time.monotonic() < deadline, 'Previous fixture window did not close'
        time.sleep(.2)
    call('shell', 'aa start -a EntryAbility -b ' + args.editor_bundle)
    deadline = time.monotonic() + 15
    while True:
        tree = nodes()
        inputs = [n for n in tree if n.get('id') == 'multiInput' and n.get('bundleName') == args.editor_bundle]
        if len(inputs) == 1:
            tap_at(*point(inputs[0]))
            break
        assert time.monotonic() < deadline, 'Fixture activity did not appear'
        time.sleep(.2)
    deadline = time.monotonic() + 8
    while True:
        tree = nodes()
        editor = one('multiInput', tree)
        bound_id = 'ime-editor-window-' + editor['hostWindowId']
        if any(n.get('id') == 'key-あ' for n in tree) and any(n.get('id') == bound_id for n in tree):
            assert one('multiInput', tree).get('text') == ''
            # App/IME processes and editor binding finish asynchronously after force-stop.
            time.sleep(.6)
            tree = nodes()
            assert one('multiInput', tree).get('focused') == 'true'
            assert one('multiInput', tree).get('text') == ''
            return tree
        assert time.monotonic() < deadline, 'Keyboard did not appear after focusing the fixture'
        if any(n.get('id') in ['key-a','key-1'] for n in tree):
            tap_at(*point(one('key-入力モード', tree)))
        elif any(n.get('id') == 'emoji-return' for n in tree):
            tap_at(*point(one('emoji-return', tree)))
        elif any(n.get('id') == 'clipboard-return' for n in tree):
            tap_at(*point(one('clipboard-return', tree)))
        else:
            tap_at(*point(one('multiInput', tree)))
        time.sleep(.3)

def wait_value(expected):
    deadline = time.monotonic() + 5
    while True:
        tree = nodes()
        actual = one('multiInput', tree).get('text', '')
        if actual == expected:
            return tree
        if time.monotonic() >= deadline:
            record = {'expected': expected, 'actual': actual, 'nodes': tree}
            (out / 'failure-state.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
            remote = '/data/local/tmp/reference-failure.png'
            call('shell', 'uitest screenCap -p ' + remote)
            call('file', 'recv', remote, str(out / 'failure-screen.png'))
            (out / 'failure-ime.log').write_text(call('shell', 'hilog -x -T NihongoIME'))
            raise AssertionError({'expected': expected, 'actual': actual})
        time.sleep(.15)

def capture(name, expected, screenshot=True):
    tree = wait_value(expected)
    actual = one('multiInput', tree).get('text', '')
    record = {'scenario': name, 'expected': expected, 'actual': actual, 'pass': actual == expected}
    results.append(record)
    (out / 'input-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
    if screenshot:
        (out / (name + '.json')).write_text(json.dumps(tree, ensure_ascii=False, indent=2) + '\n')
    assert actual == expected, record
    if screenshot:
        remote = '/data/local/tmp/harmony-reference-screen.png'
        call('shell', 'uitest screenCap -p ' + remote)
        call('file', 'recv', remote, str(out / (name + '.png')))
    print(name + ': PASS (' + actual + ')', flush=True)

if __name__ == '__main__':
    assert 'com.takeruf.harmonynihongo' in call('shell', 'ime -g')
    for name, dx, dy, expected in [('tap-a', 0, 0, 'あ'), ('flick-left', -100, 0, 'い'),
                                   ('flick-up', 0, -100, 'う'), ('flick-right', 100, 0, 'え'),
                                   ('flick-down', 0, 100, 'お')]:
        tree = reset()
        x, y = point(one('key-あ', tree))
        call('shell', f'uinput -T -d {x} {y} -i 40 -u {x+dx} {y+dy}')
        # Input injection returns before release/render; allow a frame before UI inspection.
        time.sleep(.3)
        capture(name, expected)

    tree = reset()
    x, y = point(one('key-あ', tree))
    # Capture after both releases; the timestamps arrive close enough to toggle.
    call('shell', f'uinput -T -c {x} {y} 20')
    call('shell', f'uinput -T -c {x} {y} 20')
    capture('combined-tap', 'い')
    print('Harmony/Gboard recorded basic input scenarios: PASS', flush=True)

    for name, dx, expected in [('hold-popup', 0, 'あ'), ('left-popup', -100, 'い')]:
        tree = reset()
        x, y = point(one('key-あ', tree))
        gesture = (f'uinput -T -d {x} {y} -i 2000 -u {x} {y}' if dx == 0 else
                   f'uinput -T -m {x} {y} {x+dx} {y} -k 2000 150')
        call('shell', gesture)
        time.sleep(.5)
        remote = '/data/local/tmp/harmony-popup.png'
        call('shell', 'uitest screenCap -p ' + remote)
        call('file', 'recv', remote, str(out / (name + '.png')))
        # uinput queues events asynchronously; allow the up event before reading.
        time.sleep(2.3)
        capture(name + '-released', expected)

    if args.full:
        for mode, taps in [('kana', 0), ('alphabet', 1), ('number', 2)]:
            tree = reset()
            for _ in range(taps):
                tap('key-入力モード')
                time.sleep(.2)
            reference = json.loads((root / ('tools/fixtures/gboard-14.2-' + mode + '.json')).read_text())
            time.sleep(.3)
            tree = nodes()
            deletion = point(one('key-削除', tree))
            for group in reference:
                center = group['directions']['center']
                x, y = point(one('key-' + center, tree))
                for direction, (dx, dy) in zip(['center', 'left', 'up', 'right', 'down'],
                                              [(0, 0), (-100, 0), (0, -100), (100, 0), (0, 100)]):
                    expected = group['directions'][direction]
                    call('shell', f'uinput -T -d {x} {y} -i 80 -u {x+dx} {y+dy}')
                    time.sleep(.25)
                    name = mode + '-' + group['key'] + '-' + direction
                    capture(name, expected, screenshot=False)
                    if expected:
                        tap_at(*deletion)
                        wait_value('')
            capture(mode + '-idle', '')
        tree = reset()
        tap('key-入力モード')
        time.sleep(.3)
        tree = nodes()
        deletion = point(one('key-削除', tree))
        cycles = json.loads((root / 'tools/fixtures/gboard-14.2-tap-cycles.json').read_text())
        for group, key in zip(cycles, ['a', '@', "'"]):
            x, y = point(one('key-' + key, tree))
            for count, expected in enumerate(group['cycles'], 1):
                for _ in range(count):
                    tap_at(x, y)
                    time.sleep(.03)
                time.sleep(.2)
                capture('alphabet-cycle-' + group['key'] + '-' + str(count), expected, screenshot=False)
                tap_at(*deletion)
                wait_value('')
        print('All 170 directions and 21 tap cycles against recorded Gboard: PASS', flush=True)
