#!/usr/bin/env python3
"""Pura 70 portrait: a native prefix prediction committed through the IME."""
import importlib.util
import json
from pathlib import Path
import time
spec=importlib.util.spec_from_file_location('device',Path(__file__).with_name('test-kana-device.py'))
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
out=d.root/'artifacts/phase3'
d.reset()
try:
    d.text('multiInput')
except AssertionError:
    (out/'ime-results.json').write_text(json.dumps({'status':'blocked_locked_or_app_not_visible','detail':'No app-owned editor available; no prediction or learning UI claim'},indent=2))
    raise
if 'com.takeruf.harmonynihongo,' not in d.call('shell','ime -g'):
    d.call('shell','ime -s com.takeruf.harmonynihongo')
assert 'com.takeruf.harmonynihongo,' in d.call('shell','ime -g'), 'Own IME must be selected'
d.flick(628,2128,-100,0) # に
d.flick(875,2128,0,100) # ほ
time.sleep(.5)
d.call('shell','uitest screenCap -p /data/local/tmp/nihongo-prediction.png')
d.call('file','recv','/data/local/tmp/nihongo-prediction.png',str(out/'prediction-ime.png'))
# Single row: best exact 二歩, raw にほ, then first prefix prediction 日本.
d.tap(455,1775)
actual=d.text('multiInput')
(out/'ime-results.json').write_text(json.dumps({'test':'にほ → 日本 prediction commit once','expected':'日本','actual':actual},ensure_ascii=False,indent=2))
assert actual=='日本',actual
log=d.call('shell','hilog -x -T NihongoIME')
(out/'ime-log.txt').write_text('\n'.join(line for line in log.splitlines() if any(marker in line for marker in ['MOZC_READY','MOZC_LEARNING','NATIVE_PROBE'])))
assert 'MOZC_LEARNING saved=1' in log,'No successful learning record'
print('IME prefix prediction commit and learning: PASS')
