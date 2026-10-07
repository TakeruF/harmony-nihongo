#!/usr/bin/env python3
import importlib.util,time,json,re
from pathlib import Path
spec=importlib.util.spec_from_file_location('device',Path(__file__).with_name('test-kana-device.py'));d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
def nodes():
 d.call('shell','uitest dumpLayout -p /data/local/tmp/nihongo-reconv-tree.json');d.call('file','recv','/data/local/tmp/nihongo-reconv-tree.json','/tmp/nihongo-reconv-tree.json');found=[]
 def walk(x):
  if isinstance(x,dict):
   if 'attributes' in x:found.append(x['attributes'])
   for v in x.values():walk(v)
  elif isinstance(x,list):
   for v in x:walk(v)
 walk(json.loads(Path('/tmp/nihongo-reconv-tree.json').read_text()));return found
def pick(value):
 def matches():
  result=[]
  for n in nodes():
   if n.get('text')!=value:continue
   b=list(map(int,re.findall(r'-?\d+',n.get('bounds',''))))
   if len(b)==4 and b[1]>=1690 and b[3]<=2590:result.append((n,b))
  return result
 got=matches()
 if not got:d.tap(1175,1775);got=matches()
 assert len(got)==1,(value,len(got))
 b=got[0][1];d.tap((b[0]+b[2])//2,(b[1]+b[3])//2)

out=d.root/'artifacts/phase6';out.mkdir(parents=True,exist_ok=True)
results=[]
def check(name,expected,identifier='multiInput'):
 actual=d.text(identifier);results.append({'test':name,'expected':expected,'actual':actual})
 (out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));assert actual==expected,(name,actual)
 print(name+': PASS',flush=True)
def fill(single=False):
 d.reset(single=single);assert 'FULL_EXPERIENCE_MODE' in d.call('shell','ime -g')
 d.tap(379,2310);d.flick(379,1945,100,0);time.sleep(.4);pick('前');d.tap(1125,2310)
 d.tap(875,2128);d.flick(875,1945,-100,0);time.sleep(.4);pick('橋');d.tap(1125,2310)
 d.tap(379,1945);d.flick(379,2128,0,100);time.sleep(.4);pick('後')
 check('source text prepared','前　橋　後','singleInput' if single else 'multiInput')
def select_bridge(single=False):
 y=835 if single else 1035
 d.call('shell',f'uinput -T -d 265 {y} -i 700 -u 265 {y}');time.sleep(.2)
 assert any(n.get('text')=='再変換' for n in nodes()),'No reconvert key for selection'
 d.tap(130,1945);time.sleep(.4)
 assert any(n.get('text')=='箸' and n.get('id','').startswith('candidate-') for n in nodes()),'No reconversion candidates'
def capture(name):
 d.call('shell','uitest screenCap -p /data/local/tmp/nihongo-reconversion.png');d.call('file','recv','/data/local/tmp/nihongo-reconversion.png',str(out/name))
fill();select_bridge();pick('箸');check('selected preview preserves prefix and suffix','前　箸　後');capture('reconversion-ime.png')
d.tap(130,1945);check('cancel restores original selected text','前　橋　後')
select_bridge();pick('箸');d.tap(1125,2490);check('selected replacement commits once','前　箸　後')
# Put the caret at the end before continuing input, through the app UI.
d.tap(415,1035);d.tap(379,1945);d.tap(1125,2490);check('next input preserved','前　箸　後あ')
fill(single=True);select_bridge(single=True);pick('箸');check('unsupported preview keeps original until commit','前　橋　後','singleInput')
d.tap(130,1945);check('unsupported preview cancel keeps original','前　橋　後','singleInput')
select_bridge(single=True);pick('箸');d.tap(1125,2490);check('unsupported preview replaces selection once','前　箸　後','singleInput')
check('reconversion does not submit search','検索アクション: 0','searchCount')
(out/'device-mode.txt').write_text(d.call('shell','ime -g'))
log=d.call('shell','hilog -x -T NihongoIME');(out/'ime-log.txt').write_text('\n'.join(line for line in log.splitlines() if any(k in line for k in ['MOZC_READY','MOZC_LEARNING','MOZC_RECONVERSION_FAILED'])))
print('Reconversion UI, replacement, cancel, fallback, next input: PASS',flush=True)
