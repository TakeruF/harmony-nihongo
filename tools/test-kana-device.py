#!/usr/bin/env python3
"""Pura 70 portrait regression against the real IME and app-owned test fields."""
import json
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
hdc = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
output = root / 'artifacts/phase1'
output.mkdir(parents=True, exist_ok=True)
results = []

def call(*args):
    return subprocess.run([hdc, *args], check=True, capture_output=True, text=True).stdout

def reset(single=False):
    call('shell', 'aa force-stop com.takeruf.harmonynihongo')
    call('shell', 'aa start -a EntryAbility -b com.takeruf.harmonynihongo')
    time.sleep(.3)
    call('shell', 'uitest uiInput click 628 ' + ('835' if single else '1190'))
    time.sleep(.3)

def tap(x, y):
    call('shell', f'uinput -T -c {x} {y} 20')

def flick(x, y, dx, dy):
    call('shell', f'uinput -T -d {x} {y} -i 20 -u {x+dx} {y+dy}')

def text(identifier):
    call('shell', 'uitest dumpLayout -b com.takeruf.harmonynihongo -p /data/local/tmp/kana-check.json')
    call('file', 'recv', '/data/local/tmp/kana-check.json', '/tmp/nihongo-kana-check.json')
    found = []
    def walk(node):
        if isinstance(node, dict):
            attributes = node.get('attributes', {})
            if attributes.get('id') == identifier:
                found.append(attributes.get('text', ''))
            for value in node.values(): walk(value)
        elif isinstance(node, list):
            for value in node: walk(value)
    walk(json.loads(Path('/tmp/nihongo-kana-check.json').read_text()))
    assert len(found) == 1, (identifier, found)
    return found[0]

def check(name, expected, identifier='multiInput'):
    actual = text(identifier)
    results.append({'test': name, 'expected': expected, 'actual': actual})
    (output / 'kana-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    assert actual == expected, (name, actual, expected)
    print(name + ': PASS', flush=True)

def kyouha():
    flick(628,1945,-100,0); flick(628,2310,0,100); tap(379,2490)
    flick(379,1945,0,-100); tap(875,2128)

def gakkou():
    tap(628,1945); tap(379,2490); flick(379,2128,0,-100); tap(379,2490)
    flick(628,1945,0,100); flick(379,1945,0,-100)

def pyutto():
    flick(875,2128,-100,0); tap(379,2490); tap(379,2490)
    flick(628,2310,0,-100); tap(379,2490)
    flick(379,2128,0,-100); tap(379,2490); flick(379,2128,0,100)

if __name__ == '__main__':
    assert 'com.takeruf.harmonynihongo,' in call('shell','ime -g'), 'Select Harmony Nihongo first'
    for word, enter in [('きょうは', kyouha), ('がっこう', gakkou), ('ぴゅっと', pyutto)]:
        reset(); enter(); check(word + ' preview', word)
        tap(1125,2490); check(word + ' commit once', word)
    reset(); kyouha(); tap(130,2128); tap(1125,1945)
    check('composition cursor/backspace', 'きょは')
    flick(379,1945,0,-100); check('composition insert in middle', 'きょうは')
    tap(130,1945); check('composition cancellation', '')
    reset(single=True); kyouha(); check('unsupported preview stays local', '', 'singleInput')
    tap(1125,2490); check('fallback commit once', 'きょうは', 'singleInput')
    check('commit does not submit', '検索アクション: 0', 'searchCount')
    tap(1125,2490); check('next Enter submits search', '検索アクション: 1', 'searchCount')
    reset(single=True); tap(628,1945)
    call('shell','uitest uiInput click 628 1190')
    tap(1125,2490); check('editor switch drops old local reading', '\n')
    reset(); tap(1125,2310); check('default kana space full width', '　')
    print('Device kana regression: PASS')
