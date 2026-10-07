#!/usr/bin/env python3
"""Pura70, FULL mode; own app fields, real emoji taps and rotation."""
import importlib.util,json,re,time
from pathlib import Path
spec=importlib.util.spec_from_file_location('d',Path(__file__).with_name('test-kana-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
out=d.root/'artifacts/phase9';out.mkdir(parents=True,exist_ok=True);results=[]
def bounds(a):return list(map(int,re.findall(r'-?\d+',a.get('origBounds') or a.get('bounds',''))))
def nodes():
 d.call('shell','uitest dumpLayout -p /data/local/tmp/emoji-tree.json');d.call('file','recv','/data/local/tmp/emoji-tree.json','/tmp/emoji-tree.json')
 tree=json.loads(Path('/tmp/emoji-tree.json').read_text());roots=[n for n in tree['children'] if n.get('attributes',{}).get('pagePath')=='ime/Keyboard'];assert len(roots)==1,'IME absent'
 found=[]
 def walk(n):
  if isinstance(n,dict):
   if n.get('attributes'):found.append(n['attributes'])
   for v in n.values():walk(v)
  elif isinstance(n,list):
   for v in n:walk(v)
 walk(roots[0]);return found
def find(key, attributes=None):
 matches=[a for a in (nodes() if attributes is None else attributes) if a.get('id')==key or a.get('text')==key];assert matches,(key,'not visible');return matches[0]
def tap(key):
 b=bounds(find(key));d.tap((b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(.15)
def select(value):
 for attempt in range(3):
  attributes=nodes();grid=bounds(find('emoji-grid',attributes));a=find('emoji-'+value,attributes);b=bounds(a)
  if grid[1]+2<=(b[1]+b[3])//2<=grid[3]-2:d.tap((b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(.15);return
  d.call('shell',f'uitest uiInput swipe {(grid[0]+grid[2])//2} {grid[3]-20} {(grid[0]+grid[2])//2} {grid[1]+20} 800');time.sleep(.2)
 raise AssertionError('Emoji not reachable: '+value)
def check(name,expected,identifier='multiInput'):
 actual=d.text(identifier);assert actual==expected,(name,actual,expected)
 results.append({'test':name,'expected':expected,'actual':actual});(out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));print(name+': PASS',flush=True)
def capture(name):
 d.call('shell','uitest screenCap -p /data/local/tmp/emoji-test.png');d.call('file','recv','/data/local/tmp/emoji-test.png',str(out/name))
def orientation(landscape):
 d.call('shell',f'aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape {str(landscape).lower()}');time.sleep(.7)
def reset(single=False):
 d.reset(single);orientation(False)
 if any(a.get('id')=='emoji-return' for a in nodes()):tap('emoji-return')
 for _ in range(2):
  if any(a.get('text')=='あ' for a in nodes()):break
  b=bounds(find('あa1'));x,y=(b[0]+b[2])//2,(b[1]+b[3])//2;d.call('shell',f'uinput -T -d {x} {y} -i 700 -u {x} {y}')
 find('あ')
def openemoji():
 if any(a.get('text')=='☺︎記' for a in nodes()):tap('☺︎記')
 else:tap('open-emoji')
assert 'FULL_EXPERIENCE_MODE' in d.call('shell','ime -g')
reset();openemoji();find('emoji-grid');check('open emoji leaves editor unchanged','');capture('emoji-portrait.png')
select('😀');check('emoji tap inserts once','😀')
tap('emoji-category-1');select('👍🏽');check('skin tone sequence inserted intact','😀👍🏽');tap('emoji-delete');check('delete whole skin tone emoji','😀')
select('❤️');check('heart variation sequence inserted','😀❤️');tap('emoji-delete');check('delete whole heart emoji','😀')
tap('emoji-category-4');select('🇯🇵');check('flag sequence inserted intact','😀🇯🇵');tap('emoji-delete');check('delete whole flag emoji','😀')
tap('emoji-category-5');select('👨‍👩‍👧‍👦');check('family sequence inserted intact','😀👨‍👩‍👧‍👦');tap('emoji-delete');check('delete whole joined family emoji','😀')
tap('emoji-category-0');b=bounds(find('emoji-😀'));x,y=(b[0]+b[2])//2,(b[1]+b[3])//2
start=time.monotonic();d.call('shell','\n'.join(f'uinput -T -c {x} {y} 20' for _ in range(24)));elapsed=time.monotonic()-start;time.sleep(.2);check('24 touch emoji inserts preserved','😀'*25)
(out/'typing-timing.json').write_text(json.dumps({'taps':24,'seconds':elapsed},indent=2))
tap('emoji-return');find('あ')
# Opening the picker commits existing kana, then inserts one complete emoji.
reset();tap('あ');openemoji();select('😀');check('kana committed once before emoji','あ😀');tap('emoji-return');find('あ');check('returns to previous 12-key layout','あ😀')
reset(single=True);tap('あ');openemoji();select('😀');check('unsupported preview commits kana and emoji once','あ😀','singleInput');check('emoji does not submit search','検索アクション: 0','searchCount')
tap('emoji-symbols');find('!');tap('!');check('symbol input from emoji panel','あ😀!','singleInput')
reset();tap('あa1');find('English');openemoji();select('😀');tap('emoji-return');find('English');tap('a');check('return to English layout','😀a')
reset();b=bounds(find('あa1'));x,y=(b[0]+b[2])//2,(b[1]+b[3])//2;d.call('shell',f'uinput -T -d {x} {y} -i 700 -u {x} {y}');find('日本語')
openemoji();select('😀');tap('emoji-return');find('日本語');tap('k');tap('a')
buttons=[bounds(a) for a in nodes() if a.get('type')=='Button'];b=max(buttons,key=lambda b:(b[1],b[0]));d.tap((b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(.2);check('return to Japanese QWERTY and convert kana','😀か')
reset();openemoji();orientation(True);find('emoji-grid');select('😀');check('landscape emoji insertion','😀');capture('emoji-landscape.png')
orientation(False);find('emoji-grid');select('😃');check('emoji panel survives rotation','😀😃');tap('emoji-return');find('あ');capture('emoji-return-kana.png')
(out/'device-mode.txt').write_text(d.call('shell','ime -g'));print('Emoji actual device: PASS',flush=True)
