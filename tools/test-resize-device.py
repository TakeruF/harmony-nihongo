#!/usr/bin/env python3
"""Pura 70 FULL mode: short presses move, long presses resize, then commit/cancel."""
import importlib.util
import json
from pathlib import Path
import re
import time
spec=importlib.util.spec_from_file_location('device',Path(__file__).with_name('test-kana-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
out=d.root/'artifacts/phase5';out.mkdir(parents=True,exist_ok=True)
results=[]
def nodes():
    d.call('shell','uitest dumpLayout -p /data/local/tmp/nihongo-resize-test.json')
    d.call('file','recv','/data/local/tmp/nihongo-resize-test.json','/tmp/nihongo-resize-test.json')
    found=[]
    def walk(x):
        if isinstance(x,dict):
            if 'attributes' in x:found.append(x['attributes'])
            for v in x.values():walk(v)
        elif isinstance(x,list):
            for v in x:walk(v)
    walk(json.loads(Path('/tmp/nihongo-resize-test.json').read_text()));return found

def candidates():return [n for n in nodes() if n.get('id','').startswith('candidate-')]
def pick(value):
    found=[n for n in candidates() if n.get('text')==value];assert len(found)==1,('not visible',value)
    left,top,right,bottom=map(int,re.findall(r'-?\d+',found[0]['bounds']));d.tap((left+right)//2,(top+bottom)//2)
def check(name,expected):
    actual=d.text('multiInput');results.append({'test':name,'expected':expected,'actual':actual})
    (out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));assert actual==expected,(name,actual)
    print(name+': PASS',flush=True)
def hold(x):d.call('shell',f'uinput -T -d {x} 2128 -i 700 -u {x} 2128');time.sleep(.3)
def phrase():
    d.tap(628,2490);d.tap(379,2128);d.flick(875,1945,-100,0);d.tap(875,2128)
    d.tap(875,2128);d.flick(875,1945,-100,0);d.flick(628,2490,-100,0)
    d.tap(628,2490);d.tap(379,2128);d.flick(875,2310,0,-100)
def begin():
    d.call('shell','aa force-stop com.takeruf.harmonynihongo');d.call('shell','aa start -a EntryAbility -b com.takeruf.harmonynihongo');time.sleep(.3)
    try:d.text('multiInput')
    except AssertionError:
        (out/'device-status.json').write_text(json.dumps({'status':'blocked','reason':'device locked or app not visible'},indent=2));raise
    d.tap(628,1190);time.sleep(.3)
    mode=d.call('shell','ime -g');assert 'com.takeruf.harmonynihongo,' in mode and 'FULL_EXPERIENCE_MODE' in mode,mode

begin();phrase();d.tap(1125,2310);time.sleep(.4)
pick('わたしは');d.tap(1125,2128);pick('箸を');d.tap(1125,2128);pick('渡る')
d.tap(130,2128);d.tap(130,2128)
hold(130);check('shrink preserves other selections and reading','私は箸を渡る')
assert any(n.get('text')=='私' for n in candidates()),'Expected focus on shortened わたし segment'
d.call('shell','uitest screenCap -p /data/local/tmp/nihongo-resize-shrink.png');d.call('file','recv','/data/local/tmp/nihongo-resize-shrink.png',str(out/'shrink-ime.png'))
hold(1125)
assert any(n.get('text')=='わたしは' for n in candidates()),'Expected grown わたしは segment'
pick('わたしは');check('grow retains other segment selections','わたしは箸を渡る')
d.tap(1125,2490);check('adjusted segments commit once','わたしは箸を渡る')
d.tap(379,1945);d.tap(1125,2490);check('next kana preserved','わたしは箸を渡るあ')
log=d.call('shell','hilog -x -T NihongoIME');assert 'MOZC_LEARNING saved=1' in log
(out/'ime-log.txt').write_text('\n'.join(line for line in log.splitlines() if any(x in line for x in ['MOZC_READY','MOZC_LEARNING','EDITOR_LEARNING','MOZC_RESIZE_FAILED'])))
begin();phrase();d.tap(1125,2310);time.sleep(.4);hold(130);d.tap(130,1945)
check('cancel after resize restores complete original kana','わたしははしをわたる')
(out/'device-status.json').write_text(json.dumps({'status':'passed','securityMode':d.call('shell','ime -g').strip()},ensure_ascii=False,indent=2))
print('Boundary gestures, commit, learning, next kana, cancel: PASS',flush=True)
