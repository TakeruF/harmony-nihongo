#!/usr/bin/env python3
"""Portrait Pura 70 / FULL mode: own app fields and real touch keyboard."""
import importlib.util,json,re,time,os
from pathlib import Path
spec=importlib.util.spec_from_file_location('device',Path(__file__).with_name('test-kana-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
out=Path(os.environ.get('NIHONGO_TEST_ARTIFACT_DIR',str(d.root/'artifacts/phase7')));out.mkdir(parents=True,exist_ok=True);results=[]
def nodes():
 d.call('shell','uitest dumpLayout -p /data/local/tmp/romaji-tree.json')
 d.call('file','recv','/data/local/tmp/romaji-tree.json','/tmp/romaji-tree.json');found=[]
 def walk(n):
  if isinstance(n,dict):
   a=n.get('attributes',{});b=list(map(int,re.findall(r'-?\d+',a.get('bounds',''))))
   if len(b)==4 and b[1]>=1690 and b[3]<=2590:found.append((a,b))
   for v in n.values():walk(v)
  elif isinstance(n,list):
   for v in n:walk(v)
 walk(json.loads(Path('/tmp/romaji-tree.json').read_text()));return found
def keymap():
 return {a['text']:((b[0]+b[2])//2,(b[1]+b[3])//2) for a,b in nodes() if a.get('text')}
def pick(value):
 m=keymap()
 if value not in m:d.tap(1175,1775);m=keymap()
 assert value in m,(value,list(m));d.tap(*m[value]);time.sleep(.15)
def roman(text):
 m=keymap();start=time.monotonic()
 # A single shell request removes repeated host round trips; each actual tap takes 20ms.
 commands=[f'uinput -T -c {m[ch][0]} {m[ch][1]} 20' for ch in text]
 d.call('shell','\n'.join(commands));elapsed=time.monotonic()-start;time.sleep(.2);return elapsed
def ensure_romaji(single=False):
 d.reset(single=single);assert 'FULL_EXPERIENCE_MODE' in d.call('shell','ime -g')
 m=keymap()
 if '日本語' not in m:
  x,y=m['あa1'];d.call('shell',f'uinput -T -d {x} {y} -i 700 -u {x} {y}')
 assert '日本語' in keymap(),'Japanese QWERTY not visible'
def enter():d.tap(1150,2490)
def check(name,expected,identifier='multiInput'):
 actual=d.text(identifier);results.append({'test':name,'expected':expected,'actual':actual})
 (out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
 assert actual==expected,(name,actual,expected);print(name+': PASS',flush=True)
def capture(name):
 d.call('shell','uitest screenCap -p /data/local/tmp/romaji.png');d.call('file','recv','/data/local/tmp/romaji.png',str(out/name))
ensure_romaji();roman('kyouha');check('romaji kana preview','きょうは');time.sleep(.3)
pick('今日は');check('Mozc candidate tap commits once','今日は');capture('qwerty-ime.png')
ensure_romaji();roman('ky');check('pending letters visible','ky');d.tap(1150,2310);roman('a');check('pending deletion then kana','か')
ensure_romaji();roman('kan');enter();check('n finalized on enter','かん')
ensure_romaji();roman('kann');enter();check('nn finalized without duplicate n','かん')
ensure_romaji();elapsed=roman('gakkou'*12);check('72 touch letters preserved','がっこう'*12)
(out/'typing-timing.json').write_text(json.dumps({'letters':72,'elapsed_seconds':elapsed,'letters_per_second':72/elapsed},indent=2))
ensure_romaji();roman('watashihahashiwowataru');pick('日本語');time.sleep(.4)
assert any(a.get('text')=='私は' for a,b in nodes()),'Segment candidates absent'
pick('私は')
enter();check('QWERTY segment conversion commit','私は箸を渡る' if '箸' in d.text('multiInput') else '私は橋を渡る');capture('qwerty-segments.png')
ensure_romaji(single=True);roman('kyouha');check('unsupported preview remains local','','singleInput');time.sleep(.3)
pick('今日は');check('fallback candidate inserts once','今日は','singleInput');check('candidate does not submit search','検索アクション: 0','searchCount')
# Long press returns to the existing flick layout, with no added mode strip.
x,y=keymap()['あa1'];d.call('shell',f'uinput -T -d {x} {y} -i 700 -u {x} {y}')
assert 'あ' in keymap(),'12-key layout absent';d.flick(379,1945,-100,0);d.tap(1125,2490)
check('flick input after QWERTY switch','今日はい','singleInput')
ensure_romaji();pick('あa1');assert 'English' in keymap(),'English mode absent'
roman('abc');pick('あa1');pick('1');pick('あa1');assert '日本語' in keymap(),'Selected Japanese layout lost'
roman('ka');enter();check('English and number cycle returns selected Japanese layout','abc1か')
(out/'device-mode.txt').write_text(d.call('shell','ime -g'))
print('Japanese QWERTY actual device: PASS',flush=True)
