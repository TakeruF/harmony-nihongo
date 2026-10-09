#!/usr/bin/env python3
"""Own editor only: reverse tap, emoji grid/search/history/skin tones and return mode."""
import importlib.util
import json
import re
import time
from pathlib import Path
spec = importlib.util.spec_from_file_location('reference_device', Path(__file__).with_name('test-gboard-reference-device.py'))
d = importlib.util.module_from_spec(spec); spec.loader.exec_module(d)
d.out = d.root / 'artifacts/gboard-emoji-device'; d.out.mkdir(parents=True, exist_ok=True)

def wait_id(identifier, timeout=8):
    deadline=time.monotonic()+timeout
    while True:
        tree=d.nodes()
        if any(n.get('id')==identifier for n in tree):
            time.sleep(.3); return d.nodes()
        assert time.monotonic()<deadline, identifier+' did not appear'
        time.sleep(.2)

def query(expected):
    deadline=time.monotonic()+8
    while True:
        tree=d.nodes();actual=d.one('emoji-search-query',tree).get('text')
        if actual==expected:return tree
        assert time.monotonic()<deadline,(expected,actual)
        time.sleep(.2)

d.reset();d.tap('key-あ');d.wait_value('あ');d.tap('key-か');d.wait_value('あか')
d.tap('key-逆順');d.capture('reverse-kana-1','あこ');d.tap('key-逆順');d.capture('reverse-kana-2','あけ')
d.reset();x,y=d.point(d.one('key-あ'));d.call('shell',f'uinput -T -d {x} {y} -i 80 -u {x-100} {y}');d.wait_value('い')
d.tap('key-逆順');d.capture('reverse-flick-unchanged','い')
d.reset();d.tap('key-入力モード');wait_id('key-a');d.tap('key-a');d.wait_value('a')
for value in ['2','C','B']:
    d.tap('key-逆順');d.capture('reverse-alphabet-'+value,value)

d.reset();d.tap('open-emoji');wait_id('emoji-😭')
tree=wait_id('emoji-😭')
row=[d.one('emoji-'+value,tree) for value in ['😀','😃','😄','😁','😆','😅','😂','🤣','😭']]
positions=[list(map(int,re.findall(r'-?\d+',n['bounds']))) for n in row]
assert len({p[1] for p in positions})==1,positions
assert all(positions[i][2]<=positions[i+1][0] for i in range(8)),positions
d.capture('emoji-nine-columns','')
d.tap('emoji-😀');d.capture('emoji-insert','😀');d.tap('emoji-recent');wait_id('emoji-😀')
d.capture('emoji-recents','😀');d.tap('emoji-return');wait_id('key-あ');d.wait_value('😀')
d.tap('open-emoji');wait_id('emoji-search');d.tap('emoji-search');wait_id('emoji-search-query')
x,y=d.point(d.one('key-あ'));d.call('shell',f'uinput -T -d {x} {y} -i 80 -u {x-100} {y}');query('い')
x,y=d.point(d.one('key-な'));d.call('shell',f'uinput -T -d {x} {y} -i 80 -u {x} {y-100}');query('いぬ')
d.capture('emoji-query-does-not-edit-app','😀');d.tap('key-絵文字記号');wait_id('emoji-🐶')
d.capture('emoji-query-return-key','😀');d.tap('emoji-search');query('いぬ');d.tap('key-絵文字検索');wait_id('emoji-🐶')
d.capture('emoji-search-results','😀');d.tap('emoji-🐶');d.capture('emoji-search-insert','😀🐶')
d.tap('emoji-return');wait_id('key-あ');d.wait_value('😀🐶')
d.tap('open-emoji');wait_id('emoji-category-1');d.tap('emoji-category-1');wait_id('emoji-👍')
x,y=d.point(d.one('emoji-👍'));d.call('shell',f'uinput -T -d {x} {y} -i 1000 -u {x} {y}')
wait_id('emoji-variant-👍🏽');time.sleep(1.1);d.wait_value('😀🐶')
d.tap('emoji-variant-👍🏽');d.capture('emoji-skin-tone','😀🐶👍🏽')
d.tap('emoji-delete');d.capture('emoji-delete-sequence','😀🐶')
d.tap('emoji-return');wait_id('key-あ');d.wait_value('😀🐶')
d.tap('open-emoji');wait_id('emoji-search');d.tap('emoji-search');wait_id('emoji-search-query')
x,y=d.point(d.one('key-あ'));d.call('shell',f'uinput -T -d {x} {y} -i 80 -u {x-100} {y}');query('い')
d.tap('singleInput');tree=wait_id('key-あ')
assert not any(n.get('id')=='emoji-search-query' for n in tree), 'Search survived editor replacement'
d.tap('key-か');wait_id('composition');d.tap('key-確定')
deadline=time.monotonic()+8
while True:
    tree=d.nodes()
    if d.one('singleInput',tree).get('text')=='か':break
    assert time.monotonic()<deadline, 'New editor did not receive kana'
    time.sleep(.2)
assert d.one('searchCount',tree).get('text')=='検索アクション: 0'
d.capture('emoji-search-editor-replacement','😀🐶')
print('Reverse tap, nine columns, recents, isolated Japanese search, skin tones and return: PASS',flush=True)
