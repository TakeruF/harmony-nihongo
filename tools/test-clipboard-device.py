#!/usr/bin/env python3
"""Pura70/FULL: actual system copy menu, secure paste control, transient history."""
import importlib.util,json,re,time,shlex
from pathlib import Path
spec=importlib.util.spec_from_file_location('d',Path(__file__).with_name('test-kana-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
out=d.root/'artifacts/phase10';out.mkdir(parents=True,exist_ok=True);results=[]
def bounds(a):return list(map(int,re.findall(r'-?\d+',a.get('bounds',''))))
def nodes():
 d.call('shell','uitest dumpLayout -p /data/local/tmp/clipboard-tree.json');d.call('file','recv','/data/local/tmp/clipboard-tree.json','/tmp/clipboard-tree.json');found=[]
 def walk(n):
  if isinstance(n,dict):
   if n.get('attributes'):found.append(n['attributes'])
   for v in n.values():walk(v)
  elif isinstance(n,list):
   for v in n:walk(v)
 walk(json.loads(Path('/tmp/clipboard-tree.json').read_text()));return found
def find(key):
 matches=[a for a in nodes() if a.get('id')==key or a.get('text')==key];assert matches,('Control absent',key);return matches[0]
def tap(key):
 b=bounds(find(key));d.tap((b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(.15)
def openclip():
 if not any(a.get('id')=='clipboard-paste' for a in nodes()):tap('open-clipboard')
def check(name,expected=None,identifier='multiInput'):
 if expected is not None:assert d.text(identifier)==expected,name
 results.append({'test':name,'status':'PASS'});(out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));print(name+': PASS',flush=True)
def read():tap('clipboard-paste');time.sleep(.2)
def copy_source(word):
 d.call('shell',f'uitest uiInput inputText 600 835 {shlex.quote(word)}');assert d.text('singleInput')==word,'Source text mismatch'
 d.call('shell','uitest uiInput longClick 230 835');tap('复制')
 d.call('shell','uitest uiInput click 628 1190');time.sleep(.2);openclip()
def entries():return [a for a in nodes() if a.get('id','').startswith('clipboard-item-')]
def capture(name):
 d.call('shell','uitest screenCap -p /data/local/tmp/clipboard-test.png');d.call('file','recv','/data/local/tmp/clipboard-test.png',str(out/name))
def enter():
 attrs=nodes();root=next(a for a in attrs if a.get('pagePath')=='ime/Keyboard');r=bounds(root)
 buttons=[bounds(a) for a in attrs if a.get('type')=='Button' and bounds(a)[1]>=r[1]];b=max(buttons,key=lambda b:(b[1],b[0]));d.tap((b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(.2)
assert 'FULL_EXPERIENCE_MODE' in d.call('shell','ime -g')
d.reset();copy_source('ClipAlpha');read();check('system copy then secure paste once','ClipAlpha');capture('clipboard-portrait.png')
read();check('second explicit paste inserts once more','ClipAlphaClipAlpha');assert len(entries())==1;check('duplicate reads keep one history item')
item=entries()[0]['id'];tap(item);check('history item pastes without reread','ClipAlpha'*3)
# Copy another controlled value without restarting the IME; only the source editor changes.
d.call('shell','uitest uiInput click 628 835');d.call('shell','uitest uiInput longClick 230 835')
# The single word is selected. Typing replaces that selection.
d.call('shell','uitest uiInput text ClipBeta');assert d.text('singleInput')=='ClipBeta','Selected source replacement failed'
d.call('shell','uitest uiInput longClick 230 835');tap('复制');d.call('shell','uitest uiInput click 628 1190');openclip();read()
check('second copied value pastes','ClipAlpha'*3+'ClipBeta');assert len(entries())==2;check('two history items preserved across editor changes')
item=next(a for a in entries() if a.get('text')=='ClipAlpha');tap(item['id']);check('older history value reused','ClipAlpha'*3+'ClipBetaClipAlpha')
newest=next(a for a in entries() if a.get('text')=='ClipBeta');tap(newest['id'].replace('clipboard-item-','clipboard-remove-'));assert len(entries())==1;check('individual history removal')
tap('clipboard-clear');assert len(entries())==0;check('clear history empties list')
read();check('history clear leaves system clipboard intact','ClipAlpha'*3+'ClipBetaClipAlphaClipBeta');assert len(entries())==1;capture('clipboard-history.png')
tap('clipboard-return');find('あ');tap('あ');enter();check('return to kana input','ClipAlpha'*3+'ClipBetaClipAlphaClipBetaあ')
d.reset(single=True);openclip();read();check('paste into nonpreview single field once','ClipBeta','singleInput');check('paste does not submit search','検索アクション: 0','searchCount')
tap('clipboard-return');b=bounds(find('あa1'));x,y=(b[0]+b[2])//2,(b[1]+b[3])//2;d.call('shell',f'uinput -T -d {x} {y} -i 700 -u {x} {y}');find('日本語');openclip();read();tap('clipboard-return');find('日本語');tap('k');tap('a');enter();check('return to Japanese QWERTY','ClipBetaClipBetaか','singleInput')
d.reset();openclip();d.call('shell','aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape true');time.sleep(.7);read();check('landscape secure paste','ClipBeta');capture('clipboard-landscape.png')
d.call('shell','aa start -a EntryAbility -b com.takeruf.harmonynihongo --pb validationLandscape false');time.sleep(.7);read();check('paste after rotation','ClipBetaClipBeta')
(out/'device-mode.txt').write_text(d.call('shell','ime -g'));print('Clipboard actual device: PASS',flush=True)
