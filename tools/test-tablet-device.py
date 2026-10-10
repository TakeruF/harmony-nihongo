#!/usr/bin/env python3
"""Tablet keyboard regression on a selected HarmonyOS device/emulator, using UI bounds."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--target', required=True)
parser.add_argument('--out', type=Path, default=Path('artifacts/tablet-2026-10-10/harmony'))
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
cmd = ['/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc', '-t', args.target]
env = dict(os.environ, HDC_SERVER_PORT='8710')
results = []

def call(*values):
    return subprocess.check_output(cmd + list(values), text=True, env=env, timeout=25)

def tree():
    call('shell', 'uitest dumpLayout -p /data/local/tmp/nihongo-tablet.json')
    path = args.out / 'latest-tree.json'
    call('file', 'recv', '/data/local/tmp/nihongo-tablet.json', str(path.resolve()))
    found = []
    def walk(item):
        if isinstance(item, dict):
            if 'attributes' in item:
                found.append(item['attributes'])
            for value in item.values():
                walk(value)
        elif isinstance(item, list):
            for value in item:
                walk(value)
    walk(json.loads(path.read_text()))
    return found

def one(identifier, nodes):
    hits = [n for n in nodes if n.get('id') == identifier]
    assert len(hits) == 1, (identifier, len(hits))
    return hits[0]

def bounds(node):
    return list(map(int, re.findall(r'-?\d+', node.get('origBounds') or node['bounds'])))

def tap(identifier):
    b = bounds(one(identifier, tree()))
    call('shell', f'uinput -T -c {(b[0]+b[2])//2} {(b[1]+b[3])//2} 20')
    time.sleep(.18)

def wait(predicate, label):
    deadline = time.monotonic() + 15
    while True:
        nodes = tree()
        if predicate(nodes):
            return nodes
        if time.monotonic() >= deadline:
            capture('failure')
            raise AssertionError(label)
        time.sleep(.2)

def record(label):
    results.append({'test': label, 'pass': True})
    (args.out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2)+'\n')
    print(label + ': PASS', flush=True)

def value(expected, label):
    wait(lambda ns: one('multiInput', ns).get('text') == expected, (label, expected))
    record(label)

def capture(name):
    call('shell', 'uitest screenCap -p /data/local/tmp/nihongo-tablet.png')
    call('file', 'recv', '/data/local/tmp/nihongo-tablet.png', str((args.out / (name+'.png')).resolve()))

def fits(label, qwerty=False):
    nodes = wait(lambda ns: any(n.get('id') == ('key-q' if qwerty else 'key-あ') for n in ns), label)
    roots = [n for n in nodes if n.get('pagePath') == 'ime/Keyboard']
    assert len(roots) == 1
    left, top, right, bottom = bounds(roots[0])
    keys = [n for n in nodes if n.get('id', '').startswith('key-')]
    assert keys
    for key in keys:
        x0,y0,x1,y1 = bounds(key)
        assert left-2 <= x0 < x1 <= right+2 and top-2 <= y0 < y1 <= bottom+2, (label,key)
        assert y1-y0 >= 75, (label, 'key too short', key)
    # The actual tablet should have a broad surface and a bounded keyboard body.
    assert right-left >= 1500 and bottom-top < 1000, (label,roots[0])
    record(label)

def roman(text):
    for character in text:
        tap('key-'+character)

def main():
    assert 'com.takeruf.harmonynihongo' in call('shell', 'ime -g')
    call('shell', 'aa force-stop com.takeruf.harmonynihongo')
    call('shell', 'aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape true')
    wait(lambda ns: any(n.get('id') == 'multiInput' for n in ns), 'app startup')
    tap('multiInput')
    fits('landscape 12-key fit')
    capture('landscape-kana')
    tap('key-あ')
    value('あ', 'kana preview')
    tap('key-確定')
    value('あ', 'kana commit once')
    tap('key-削除')
    value('', 'kana deletion')
    tap('tablet-layout-toggle')
    fits('landscape tablet QWERTY fit', True)
    for identifier in ['key-Tab','key-Caps Lock','key-左Shift','key-ー']:
        one(identifier, tree())
    record('tablet function keys present')
    roman('kyouha')
    value('きょうは', 'romaji preview')
    nodes = wait(lambda ns: any(n.get('text') == '今日は' and n.get('id','').startswith('candidate-') for n in ns), 'Mozc candidate')
    choice = next(n for n in nodes if n.get('text') == '今日は' and n.get('id','').startswith('candidate-'))
    tap('candidate-expand')
    wait(lambda ns: not any(n.get('id')=='key-q' for n in ns), 'expanded candidates')
    capture('landscape-expanded-candidates')
    record('expanded tablet candidates')
    tap('expanded-candidate-今日は')
    value('今日は', 'Mozc commit once')
    # Rotate an in-progress composition, then finish using the same session.
    roman('kyou')
    value('今日はきょう', 'composition before rotation')
    call('shell', 'aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape false')
    fits('portrait tablet QWERTY fit', True)
    value('今日はきょう', 'rotation preserves composition')
    roman('ha')
    value('今日はきょうは', 'continue after rotation')
    tap('key-確定')
    value('今日はきょうは', 'commit after rotation')
    capture('portrait-qwerty')
    tap('key-入力モード')
    wait(lambda ns: any(n.get('id') == 'key-a' for n in ns), 'alphabet mode')
    tap('tablet-layout-toggle')
    fits('tablet English QWERTY fit', True)
    tap('key-左Shift')
    tap('key-Q')
    value('今日はきょうはQ', 'Shift produces one uppercase letter')
    tap('key-q')
    value('今日はきょうはQq', 'Shift releases after one letter')
    tap('key-Caps Lock')
    tap('key-Q')
    tap('key-W')
    value('今日はきょうはQqQW', 'Caps Lock remains active')
    tap('key-Caps Lock')
    tap('key-q')
    value('今日はきょうはQqQWq', 'Caps Lock releases')
    capture('portrait-english')
    tap('key-Tab')
    value('今日はきょうはQqQWq\t', 'Tab inserts a tab')
    tap('key-入力モード')
    tap('key-1')
    value('今日はきょうはQqQWq\t1', 'tablet number input')
    tap('key-入力モード')
    tap('open-emoji')
    wait(lambda ns: any(n.get('id')=='emoji-grid' for n in ns), 'emoji panel')
    capture('portrait-emoji')
    record('emoji panel opens')
    tap('emoji-return')
    tap('open-clipboard')
    wait(lambda ns: any(n.get('id')=='clipboard-header' for n in ns), 'clipboard panel')
    capture('portrait-clipboard')
    record('clipboard panel opens')
    tap('clipboard-return')
    call('shell', 'aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape true')
    fits('landscape after roundtrip', True)
    capture('landscape-qwerty')
    (args.out/'ime.log').write_text(call('shell', 'hilog -x -T NihongoIME'))
    print(f'Tablet checks: {len(results)} PASS', flush=True)

if __name__ == "__main__":
    main()
