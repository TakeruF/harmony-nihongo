#!/usr/bin/env python3
from pathlib import Path
import xml.etree.ElementTree as E,json,re,hashlib
import argparse,urllib.request
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description='Generate offline emoji data from pinned Unicode 15.1 / CLDR 44 sources')
parser.add_argument('--source-dir',type=Path,default=root/'.native-build/emoji-sources')
source=parser.parse_args().source_dir;source.mkdir(parents=True,exist_ok=True)
urls={'emoji-test.txt':'https://www.unicode.org/Public/emoji/15.1/emoji-test.txt','ja.xml':'https://raw.githubusercontent.com/unicode-org/cldr/release-44/common/annotations/ja.xml','ja-derived.xml':'https://raw.githubusercontent.com/unicode-org/cldr/release-44/common/annotationsDerived/ja.xml','LICENSE':'https://raw.githubusercontent.com/unicode-org/cldr/release-44/LICENSE'}
expected=json.loads((root/'tools/fixtures/emoji-source-hashes.json').read_text())
for name,url in urls.items():
 file=source/name
 if not file.exists():file.write_bytes(urllib.request.urlopen(url,timeout=30).read())
 if hashlib.sha256(file.read_bytes()).hexdigest()!=expected[name]:raise RuntimeError('Source checksum mismatch: '+name)

annotations={};names={}
for file in ['ja.xml','ja-derived.xml']:
 for a in E.parse(source/file).iter('annotation'):
  key=a.attrib['cp'].replace('\ufe0f','');text=a.text or ''
  if a.get('type')=='tts':names[key]=text
  else:annotations[key]=text
labels={'Smileys & Emotion':('顔文字、気分','☺︎'),'People & Body':('人、体','人'),'Animals & Nature':('動物、自然','♧'),'Food & Drink':('食べ物、飲み物','♨︎'),'Travel & Places':('旅行、場所','⌂'),'Activities':('アクティビティ','⚽'),'Objects':('物','♢'),'Symbols':('記号','♡'),'Flags':('旗','⚑')}
entries=[];group='';groups=[]
for line in (source/'emoji-test.txt').read_text().splitlines():
 if line.startswith('# group: '):group=line[9:]
 if '; fully-qualified' not in line:continue
 cps=line.split(';')[0].split();value=''.join(chr(int(cp,16)) for cp in cps);key=value.replace('\ufe0f','')
 en=re.sub(r'^.*# \S+ E[0-9.]+ ','',line)
 entries.append({'value':value,'name':names.get(key,en),'keywords':annotations.get(key,'')+' | '+en,'variants':[],'group':group})
base=[e for e in entries if not any('\U0001f3fb'<=c<='\U0001f3ff' for c in e['value'])]
by_key={e['value'].replace('\ufe0f',''):e for e in base}
for entry in entries:
 stripped=''.join(c for c in entry['value'] if not '\U0001f3fb'<=c<='\U0001f3ff').replace('\ufe0f','')
 if entry not in base and stripped in by_key:by_key[stripped]['variants'].append(entry['value'])
# First four rows observed on the reference Gboard screen. The remaining list uses Unicode order.
face_order=['😀','😃','😄','😁','😆','😅','😂','🤣','😭','😉','😗','😙','😚','😘','🥰','😍','🤩','🥳','🫠','🙃','🙂','🥲','🥹','😊','☺️','😌','😔','😮‍💨','😏','🤤','😋','😛','😝','😜','🤪','🥴']
for group,(label,icon) in labels.items():
 values=[e for e in base if e['group']==group]
 if group=='Smileys & Emotion':values=[by_key[v.replace('\ufe0f','')] for v in face_order]+[e for e in values if e['value'] not in face_order]
 values=[{k:v for k,v in e.items() if k!='group'} for e in values]
 groups.append({'label':label,'icon':icon,'entries':values})
raw=root/'entry/src/main/resources/rawfile';(raw/'emoji-15.1-ja.json').write_text(json.dumps({'categories':groups},ensure_ascii=False,separators=(',',':'))+'\n')
(root/'licenses').mkdir(exist_ok=True);(root/'licenses/UNICODE-LICENSE.txt').write_bytes((source/'LICENSE').read_bytes())
meta={file:hashlib.sha256((source/file).read_bytes()).hexdigest() for file in ['emoji-test.txt','ja.xml','ja-derived.xml','LICENSE']}
assert meta==expected
print('Categories:',len(groups),'base emojis:',len(base),'all qualified:',len(entries))
