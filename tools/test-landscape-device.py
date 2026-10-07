#!/usr/bin/env python3
"""Actual Pura70 orientation changes; app-owned fields and system IME window."""
import importlib.util,json,re,time
from pathlib import Path
spec=importlib.util.spec_from_file_location('d',Path(__file__).with_name('test-kana-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
out=d.root/'artifacts/phase8';out.mkdir(parents=True,exist_ok=True);results=[]
def tree():
 d.call('shell','uitest dumpLayout -p /data/local/tmp/landscape-test.json');d.call('file','recv','/data/local/tmp/landscape-test.json','/tmp/landscape-test.json')
 return json.loads(Path('/tmp/landscape-test.json').read_text())
def bounds(a):return list(map(int,re.findall(r'-?\d+',a.get('origBounds') or a.get('bounds',''))))
def nodes(root):
 found=[]
 def walk(n):
  if isinstance(n,dict):
   if n.get('attributes'):found.append(n['attributes'])
   for v in n.values():walk(v)
  elif isinstance(n,list):
   for v in n:walk(v)
 walk(root);return found
def ime():
 roots=[n for n in tree()['children'] if n.get('attributes',{}).get('pagePath')=='ime/Keyboard'];assert len(roots)==1,'IME absent'
 return roots[0]
def mapkeys():
 return {a['text']:((bounds(a)[0]+bounds(a)[2])//2,(bounds(a)[1]+bounds(a)[3])//2) for a in nodes(ime()) if a.get('text')}
def tap(text):d.tap(*mapkeys()[text]);time.sleep(.15)
def check(name,expected=None):
 if expected is not None:assert d.text('multiInput')==expected,(name,d.text('multiInput'),expected)
 results.append({'test':name,'status':'PASS'});(out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));print(name+': PASS',flush=True)
def fits(name):
 root=ime();r=bounds(root['attributes']);buttons=[bounds(a) for a in nodes(root) if a.get('type')=='Button']
 if buttons:
  assert all(b[0]>=r[0]-2 and b[1]>=r[1]-2 and b[2]<=r[2]+2 and b[3]<=r[3]+2 for b in buttons),(r,buttons)
 else:
  choices=[bounds(a) for a in nodes(root) if a.get('text')]
  assert choices and all(b[0]>=r[0]-2 and b[2]<=r[2]+2 for b in choices),(r,choices)
  # Expanded candidates scroll vertically; the first candidate must be visible.
  assert r[1]<=mapkeys()['今日は'][1]<=r[3]
 check(name)
def orientation(landscape):
 d.call('shell',f'aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape {str(landscape).lower()}');time.sleep(.7)
def roman(s):
 m=mapkeys();d.call('shell','\n'.join(f'uinput -T -c {m[c][0]} {m[c][1]} 20' for c in s));time.sleep(.3)
def enter():
 buttons=[bounds(a) for a in nodes(ime()) if a.get('type')=='Button'];b=max(buttons,key=lambda b:(b[1],b[0]));d.tap((b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(.2)
def capture(name):
 d.call('shell','uitest screenCap -p /data/local/tmp/landscape-test.png');d.call('file','recv','/data/local/tmp/landscape-test.png',str(out/name))
assert 'FULL_EXPERIENCE_MODE' in d.call('shell','ime -g')
d.call('shell','aa force-stop com.takeruf.harmonynihongo');orientation(True);d.tap(300,800);time.sleep(.7)
fits('landscape 12-key bounds');capture('landscape-kana.png')
x,y=mapkeys()['あa1'];d.call('shell',f'uinput -T -d {x} {y} -i 700 -u {x} {y}');time.sleep(.2)
assert '日本語' in mapkeys();fits('landscape Japanese QWERTY bounds')
roman('kyouha');check('landscape romaji preview','きょうは');capture('landscape-qwerty-candidates.png')
assert '今日は' in mapkeys();tap('今日は');check('landscape Mozc candidate commit once','今日は')
roman('kyou');check('composition before rotation','今日はきょう');orientation(False)
check('rotation preserves preview','今日はきょう');fits('portrait after rotation bounds');roman('ha');tap('今日は');check('continue and commit after rotation','今日は今日は')
orientation(True);fits('landscape after second rotation');roman('kyouha');root=ime();r=bounds(root['attributes']);d.tap(r[2]-65,r[1]+65);time.sleep(.3)
assert 'q' not in mapkeys() and '今日は' in mapkeys(),'Candidate expansion absent';capture('landscape-expanded.png');fits('expanded candidates fit landscape');tap('今日は');check('expanded candidate commit once','今日は今日は今日は')
tap('?123');assert '1' in mapkeys();fits('landscape number key bounds');tap('1');check('landscape numeric input','今日は今日は今日は1')
orientation(False);fits('portrait number bounds after rotation');capture('portrait-return.png')
(out/'device-mode.txt').write_text(d.call('shell','ime -g'))
print('Landscape actual device: PASS',flush=True)
