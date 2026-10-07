#!/usr/bin/env python3
"""Pura 70 portrait, FULL mode: real flicks and visible candidates (no test IPC)."""
import importlib.util
import json
from pathlib import Path
import re
import time
spec=importlib.util.spec_from_file_location('device',Path(__file__).with_name('test-kana-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
out=d.root/'artifacts/phase4';out.mkdir(parents=True,exist_ok=True)
results=[]
def nodes():
    d.call('shell','uitest dumpLayout -p /data/local/tmp/nihongo-segment-test.json')
    d.call('file','recv','/data/local/tmp/nihongo-segment-test.json','/tmp/nihongo-segment-test.json')
    found=[]
    def walk(x):
        if isinstance(x,dict):
            if 'attributes' in x: found.append(x['attributes'])
            for value in x.values():walk(value)
        elif isinstance(x,list):
            for value in x:walk(value)
    walk(json.loads(Path('/tmp/nihongo-segment-test.json').read_text()))
    return found

def pick(value):
    choices=[n for n in nodes() if n.get('id','').startswith('candidate-') and n.get('text')==value]
    assert len(choices)==1,('Candidate is not visible',value)
    left,top,right,bottom=map(int,re.findall(r'-?\d+',choices[0]['bounds']))
    d.tap((left+right)//2,(top+bottom)//2)

def check(name,expected,identifier='multiInput'):
    actual=d.text(identifier)
    results.append({'test':name,'expected':expected,'actual':actual})
    (out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    assert actual==expected,(name,expected,actual)
    print(name+': PASS',flush=True)

def phrase():
    d.tap(628,2490);d.tap(379,2128);d.flick(875,1945,-100,0);d.tap(875,2128)
    d.tap(875,2128);d.flick(875,1945,-100,0);d.flick(628,2490,-100,0)
    d.tap(628,2490);d.tap(379,2128);d.flick(875,2310,0,-100)

def begin(single=False):
    d.reset(single=single)
    # This test uses UI candidate bounds; BASIC mode intentionally hides that window from dumps.
    mode=d.call('shell','ime -g')
    assert 'com.takeruf.harmonynihongo,' in mode and 'FULL_EXPERIENCE_MODE' in mode,mode
    d.text('singleInput' if single else 'multiInput') # Stop if device is locked.

begin();phrase();d.tap(1125,2310);time.sleep(.4)
pick('わたしは');d.tap(1125,2128);pick('箸を');d.tap(1125,2128);pick('渡る')
check('multiple segment choices stay unconfirmed','わたしは箸を渡る')
d.tap(1125,2490);check('segments commit once','わたしは箸を渡る')
d.tap(379,1945);d.tap(1125,2490);check('next kana preserved','わたしは箸を渡るあ')
log=d.call('shell','hilog -x -T NihongoIME');assert 'MOZC_LEARNING saved=1' in log
begin();phrase();d.tap(1125,2310);time.sleep(.4);d.tap(130,1945)
check('cancel returns to original kana','わたしははしをわたる')
d.tap(130,1945);check('second cancel clears kana','')
begin(single=True);phrase();d.tap(1125,2310);time.sleep(.4)
pick('わたしは');d.tap(1125,2128);pick('箸を');d.tap(1125,2128);pick('渡る')
check('unsupported preview remains local','','singleInput')
d.tap(1125,2490);check('fallback commits all segments once','わたしは箸を渡る','singleInput')
check('candidate commit does not submit search','検索アクション: 0','searchCount')
begin();phrase();d.tap(1125,2310);time.sleep(.4)
check('selected segments survive IME process restart','わたしは箸を渡る')
begin();d.flick(628,2128,-100,0);d.flick(875,2128,0,100);time.sleep(.4)
pick('日本');check('prefix prediction still commits','日本')
(out/'device-mode.txt').write_text(d.call('shell','ime -g'))
print('Segment UI, commit/cancel/fallback, prediction: PASS',flush=True)
