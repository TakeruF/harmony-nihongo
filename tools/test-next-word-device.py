#!/usr/bin/env python3
"""Real IME: post-commit continuations, learning persistence and privacy controls."""
import importlib.util
import json
import time
from pathlib import Path
spec=importlib.util.spec_from_file_location('device',Path(__file__).with_name('test-gboard-reference-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
d.out=d.root/'artifacts/prediction-2026-10-10';d.out.mkdir(parents=True,exist_ok=True)
results=[]
def record(name):
 results.append({'scenario':name,'pass':True});(d.out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n');print(name+': PASS',flush=True)
def wait_id(identifier):
 deadline=time.monotonic()+10
 while True:
  tree=d.nodes()
  if any(n.get('id')==identifier for n in tree):return tree
  assert time.monotonic()<deadline,identifier
  time.sleep(.15)
def candidate(value):
 deadline=time.monotonic()+8
 while True:
  tree=d.nodes();found=[n for n in tree if n.get('text')==value and n.get('id','').startswith('candidate-')]
  if len(found)==1:return found[0]
  assert time.monotonic()<deadline,(value,[(n.get('id'),n.get('text')) for n in tree if n.get('id','').startswith('candidate-')])
  time.sleep(.2)
def select(value):d.tap_at(*d.point(candidate(value)));time.sleep(.2)
def screenshot(name):
 remote='/data/local/tmp/nihongo-next.jpeg';d.call('shell','snapshot_display -f '+remote);d.call('file','recv',remote,str(d.out/name))
def roman(word):
 tree=d.nodes()
 if not any(n.get('id')=='key-k' for n in tree):
  x,y=d.point(d.one('key-入力モード',tree));d.call('shell',f'uinput -T -d {x} {y} -i 850 -u {x} {y}');tree=wait_id('key-k')
 points={n['id']:d.point(n) for n in tree if n.get('id','').startswith('key-')}
 for letter in word:d.tap_at(*points['key-'+letter])
 time.sleep(.3)
def today():roman('kyouha');select('今日は');d.wait_value('今日は')
def options():d.tap('open-prediction-settings');wait_id('prediction-nextWord')
def back():d.tap('prediction-back');wait_id('key-k')

assert 'com.takeruf.harmonynihongo' in d.call('shell','ime -g')
d.reset();options()
for key in ['nextWord','learning']:
 node=d.one('prediction-'+key)
 if node.get('checked')=='false':d.tap('prediction-'+key)
d.tap('prediction-back');wait_id('key-あ')
today();candidate('いい天気');screenshot('today-next.jpeg');record('今日は commit displays next-word candidates')
select('いい天気');d.wait_value('今日はいい天気');candidate('ですね');screenshot('chained-next.jpeg');record('next candidate appends once and predicts the following phrase')
select('ですね');d.wait_value('今日はいい天気ですね');record('two successive predictions without entering a reading')
# Restart is also the persistence check. Only app-owned fixture text is edited.
d.reset();today();roman('gakkou');select('学校');d.wait_value('今日は学校');record('confirmed continuation learns today to school')
d.reset();today();tree=d.nodes();choices=[n for n in tree if n.get('id','').startswith('candidate-')];assert choices[0]['text']=='学校',choices
screenshot('learned-after-restart.jpeg');record('personalized continuation survives IME process restart')
options();screenshot('prediction-settings.jpeg');d.tap('prediction-nextWord');back();
# Existing text is cleared by restarting the app-owned fixture, never by manipulating user documents.
d.reset();today();assert not [n for n in d.nodes() if n.get('id','').startswith('candidate-')];record('next-word off leaves conversion usable')
options();d.tap('prediction-nextWord');d.tap('prediction-private');back();
for _ in range(3):d.tap('key-削除')
d.wait_value('');today();assert not [n for n in d.nodes() if n.get('id','').startswith('candidate-')];record('incognito suppresses post-commit suggestions')
options();d.tap('prediction-private');d.tap('prediction-learning');back();
d.reset();today();assert candidate('いい天気');tree=d.nodes();choices=[n for n in tree if n.get('id','').startswith('candidate-')];assert choices[0]['text']=='いい天気',choices
record('learning off uses standard predictions without personalized rank')
options();d.tap('prediction-learning');
header=d.one('prediction-back');x,y=d.point(header);d.call('shell',f'uitest uiInput swipe {x+350} {y+560} {x+350} {y+130} 800');time.sleep(.3)
d.tap('prediction-reset');wait_id('prediction-reset-confirm');d.tap('prediction-reset-cancel');record('learning reset has a cancellable confirmation')
back();d.reset();today();candidate('学校');record('cancelling reset retains learned continuation')
# Cursor movement retires stale next-word candidates.
d.tap('key-カーソル左');time.sleep(.3);assert not [n for n in d.nodes() if n.get('id','').startswith('candidate-')];record('moving the caret clears stale post-commit predictions')
d.reset();roman('kyouha');select('今日は');select('いい天気');d.wait_value('今日はいい天気');
d.call('shell','aa start -a EntryAbility -b '+d.args.editor_bundle+' --pb validationLandscape true');time.sleep(.8)
candidate('ですね');screenshot('landscape-next.jpeg');record('next-word bar remains usable in landscape')
d.call('shell','aa start -a EntryAbility -b '+d.args.editor_bundle+' --pb validationLandscape false');time.sleep(.8)
d.reset();tree=d.nodes()
def flick_key(name,dx,dy):
 x,y=d.point(d.one('key-'+name,tree));d.call('shell',f'uinput -T -d {x} {y} -i 40 -u {x+dx} {y+dy}')
flick_key('か',-90,0);flick_key('や',0,90);d.tap_at(*d.point(d.one('key-文字変形',tree)));flick_key('あ',0,-90);d.tap_at(*d.point(d.one('key-は',tree)));time.sleep(.3)
select('今日は');d.wait_value('今日は');node=candidate('いい天気');screenshot('kana-next.jpeg');record('12-key flick commit uses the same next-word bar')
x,y=d.point(node);d.call('shell',f'uitest uiInput longClick {x} {y}');wait_id('candidate-remove-confirm');screenshot('candidate-remove-confirm.jpeg');d.tap('candidate-remove-cancel');d.wait_value('今日は');candidate('いい天気');record('candidate long press opens a cancellable removal without committing')
d.reset();d.wait_value('');record('fixture text cleared and portrait restored')
