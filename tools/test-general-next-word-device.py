#!/usr/bin/env python3
"""General Japanese continuation prediction without phrase-table entries or history."""
import importlib.util
import json
import time
from pathlib import Path
spec=importlib.util.spec_from_file_location('device',Path(__file__).with_name('test-gboard-reference-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
d.out=d.root/'artifacts/general-prediction-2026-10-10';d.out.mkdir(parents=True,exist_ok=True)
results=[]
def record(name):
 results.append({'scenario':name,'pass':True})
 (d.out/'device-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
 print(name+': PASS',flush=True)
def wait_id(identifier):
 deadline=time.monotonic()+10
 while True:
  tree=d.nodes()
  if any(n.get('id')==identifier for n in tree):return tree
  assert time.monotonic()<deadline,identifier
  time.sleep(.15)
def candidate(value):
 deadline=time.monotonic()+10
 while True:
  tree=d.nodes();found=[n for n in tree if n.get('text')==value and n.get('id','').startswith('candidate-')]
  if len(found)==1:return found[0]
  assert time.monotonic()<deadline,(value,[(n.get('id'),n.get('text')) for n in tree if n.get('id','').startswith('candidate-')])
  time.sleep(.15)
def select(value):
 d.tap_at(*d.point(candidate(value)));time.sleep(.2)
def roman(word):
 tree=d.nodes()
 if not any(n.get('id')=='key-k' for n in tree):
  x,y=d.point(d.one('key-入力モード',tree));d.call('shell',f'uinput -T -d {x} {y} -i 850 -u {x} {y}');tree=wait_id('key-k')
 points={n['id']:d.point(n) for n in tree if n.get('id','').startswith('key-')}
 for letter in word:d.tap_at(*points['key-'+letter])
 time.sleep(.3)
def set_learning(enabled):
 d.tap('open-prediction-settings');wait_id('prediction-learning')
 for key,wanted in [('nextWord',True),('learning',enabled),('private',False)]:
  node=d.one('prediction-'+key)
  if (node.get('checked')=='true')!=wanted:d.tap('prediction-'+key)
 d.tap('prediction-back')
def screenshot(name):
 remote='/data/local/tmp/nihongo-general-next.jpeg'
 d.call('shell','snapshot_display -f '+remote);d.call('file','recv',remote,str(d.out/name))

assert 'com.takeruf.harmonynihongo' in d.call('shell','ime -g')
d.reset();set_learning(False)
try:
 for reading,value,suffix in [('gakkou','学校','に'),('shigoto','仕事','する'),('nihongo','日本語','の'),('tanoshii','楽しい','です'),('taberu','食べる','と'),('gakkouni','学校に','は')]:
  d.reset();roman(reading);select(value);d.wait_value(value);candidate(suffix)
  screenshot('next-'+reading+'.jpeg');record(value+' has dictionary predictions with personalized learning disabled')
  select(suffix);d.wait_value(value+suffix);record(value+' + '+suffix+' appends the candidate exactly once')
 # Personal continuations also work for words absent from CONTINUATIONS.
 d.reset();set_learning(True);roman('eiga');select('映画');roman('miru');select('見る');d.wait_value('映画見る')
 record('映画 -> 見る learned from ordinary confirmed input')
 d.reset();roman('eiga');select('映画');d.wait_value('映画');candidate('見る')
 choices=[n for n in d.nodes() if n.get('id','').startswith('candidate-')]
 assert choices[0]['text']=='見る',choices
 screenshot('learned-movie.jpeg');select('見る');d.wait_value('映画見る')
 record('arbitrary continuation ranks first after restarting the IME')
finally:
 # Restore the normal learning mode and leave only the disposable editor empty.
 d.reset();set_learning(True);d.reset();d.wait_value('')
record('normal settings restored and fixture cleared')
