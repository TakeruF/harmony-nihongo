#!/usr/bin/env python3
"""Pura 70 portrait touch regression; resets only the app-owned test field."""
import subprocess,time,json
from pathlib import Path
hdc='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
def call(*args): return subprocess.run([hdc,*args],check=True,capture_output=True,text=True)
assert 'com.takeruf.harmonynihongo,' in call('shell','ime -g').stdout, 'Select Harmony Nihongo before running this Pura 70 portrait test'
call('shell','aa force-stop com.takeruf.harmonynihongo')
call('shell','aa start -a EntryAbility -b com.takeruf.harmonynihongo')
time.sleep(.4)
call('shell','uitest uiInput click 628 1190')
time.sleep(.4)
call('shell', 'uitest uiInput click 130 2490')
time.sleep(.2)
commands=[]
for i in range(60):
 x=[68,191,316,440,565][i%5];commands.append(f'uinput -T -d {x} 1945 -i 20 -u {x} 1945')
for i in range(10): commands.append('uinput -T -d 128 1945 -i 20 -u 128 1945')
for i in range(10): commands.append('uinput -T -d 68 1945 -i 20 -u 130 1945')
t=time.monotonic();r=call('shell','\n'.join(commands));duration=time.monotonic()-t
assert 'error' not in r.stdout.lower(),r.stdout[-500:]
call('shell','uitest dumpLayout -b com.takeruf.harmonynihongo -p /data/local/tmp/rapid.json')
call('file','recv','/data/local/tmp/rapid.json','/tmp/rapid.json')
texts=[]
def visit(n):
 if isinstance(n,dict):
  a=n.get('attributes',{})
  if a.get('id')=='multiInput': texts.append(a.get('text',''))
  for v in n.values(): visit(v)
 elif isinstance(n,list):
  for v in n: visit(v)
visit(json.loads(Path('/tmp/rapid.json').read_text()))
result={'stage':'regression','durationSeconds':round(duration,3),'expected':'qwert'*12+'q'*20,'actual':texts[0]}
Path('/tmp/rapid-'+'regression'+'-result.json').write_text(json.dumps(result,indent=2))
print(result)

assert result['actual'] == result['expected'], 'Input missing, duplicated or out of order'
