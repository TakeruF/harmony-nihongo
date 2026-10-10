const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const compile = file => ts.transpileModule(fs.readFileSync(file,'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
const modelExports = {};
vm.runInNewContext(compile('entry/src/main/ets/input/Personalization.ets'), {exports:modelExports,Date});
const {Personalization}=modelExports;
let model = new Personalization();
const list = values => Array.from(values);
assert.equal(model.next('今日は',[])[0],'いい天気');
assert.deepEqual(list(model.next('おはよう',['ございます','☀'])),['ございます','☀']);
for (const [previous,reading,value] of [['映画','みたい','見たい'],['大阪','いきます','行きます'],['架空製品アルファ','はつばい','発売']]) {
  assert.equal(model.next(previous,[]).length,0); // No phrase-table entry.
  assert.equal(model.next(previous,['は'])[0],'は'); // General engine suggestions pass through.
  model.remember(reading,value,previous,1);
  assert.equal(model.next(previous,['は'])[0],value);
  const reloaded=new Personalization();assert(reloaded.restore(JSON.parse(JSON.stringify(model.values))));
  assert.equal(reloaded.next(previous,['は'])[0],value);
}
model.clear();
model.remember('きょうは','今日は','',1);
model.remember('がっこう','学校','今日は',2);
model.remember('がっこう','学校','今日は',3);
assert.equal(model.next('今日は',[])[0],'学校');
assert.equal(model.next('明日は',[]).includes('学校'),false);
assert.equal(model.rank('がっ',['学期'])[0],'学校');
model.values.learning=false;
assert.equal(model.next('今日は',[])[0],'いい天気');
assert.equal(model.remember('ひみつ','秘密','今日は'),false);
assert.deepEqual(list(model.rank('がっ',['学期'])),['学期']);
model.values.learning=true; model.privateMode=true;
assert.deepEqual(list(model.next('今日は',['雨'])),[]);
assert.deepEqual(list(model.rank('がっ',['学期'])),['学期']);
assert.equal(model.remember('ひみつ','秘密','今日は'),false);
model.privateMode=false;model.forget('学校');
assert(!model.next('今日は',['学校']).includes('学校'));
assert(!model.rank('がっ',['学校']).includes('学校'));
assert(!model.remember('がっこう','学校','今日は'));
model.values.nextWord=false;assert.deepEqual(list(model.next('今日は',[])),[]);
model.values.nextWord=true;
assert(!model.remember('a','secret\nline',''));
assert(!model.remember('a'.repeat(129),'a',''));
model.clear();assert.equal(model.values.words.length,0);assert.equal(model.values.blocked.length,0);
assert.equal(model.next('今日は',[])[0],'いい天気');
for(let i=0;i<600;i++)model.remember('よみ'+i,'言葉'+i,'今日は',i+1);
assert.equal(model.values.words.length,512);
for(let i=0;i<150;i++)model.forget('削除'+i);
assert.equal(model.values.blocked.length,128);
const saved = JSON.stringify(model.values);
const fresh = new Personalization();assert(fresh.restore(JSON.parse(saved)));
assert.deepEqual(list(fresh.next('今日は',[])),list(model.next('今日は',[])));
for(const bad of [null,{}, {...JSON.parse(saved),words:[null]}, {...JSON.parse(saved),words:[false]}, {...JSON.parse(saved),nextWord:'true'}]) {
  assert.equal(fresh.restore(bad),false);
}
let partialWrites = true, failRename = false;
const fileIo={OpenMode:{CREATE:1,WRITE_ONLY:2,TRUNC:4},accessSync:fs.existsSync,statSync:fs.statSync,readTextSync:p=>fs.readFileSync(p,'utf8'),openSync:p=>({fd:fs.openSync(p,'w')}),closeSync:file=>fs.closeSync(file.fd),
writeSync:(fd,buffer,options)=>fs.writeSync(fd,Buffer.from(buffer),0,partialWrites?Math.min(11,options.length):options.length),
renameSync:(a,b)=>{if(failRename)throw Error('fail');fs.renameSync(a,b);}};
const storage=new Map();const storeExports={};
vm.runInNewContext(compile('entry/src/main/ets/ime/PersonalizationStore.ets'),{exports:storeExports,require:name=> name==='@kit.CoreFileKit'?{fileIo}:name==='@kit.ArkTS'?{util:{TextEncoder:class{encodeInto(s){return new TextEncoder().encode(s);}}}}:modelExports, AppStorage:{setOrCreate:(k,v)=>storage.set(k,v)},Error});
const store=storeExports.personalizationStore;
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'nihongo-personal-test-'));
try {
 store.load({filesDir:directory});store.model.remember('がっこう','学校','今日は');store.model.values.nextWord=false;
 assert(store.save());const file=path.join(directory,'personalization-v1.json');const intact=fs.readFileSync(file,'utf8');
 assert(intact.includes('学校'));store.model.privateMode=true;store.load({filesDir:directory});
 assert.equal(store.model.privateMode,false);assert.equal(store.model.values.nextWord,false);assert.equal(store.model.rank('がっ',[])[0],'学校');
 failRename=true;store.model.clear();assert.equal(store.save(),false);assert.equal(fs.readFileSync(file,'utf8'),intact);
 failRename=false;fs.writeFileSync(file,'{broken');store.load({filesDir:directory});assert.equal(store.model.values.words.length,0);assert(store.save());
 console.log('Personalization: continuations, prefix/frequency ranking, isolated context, private/disabled learning, suppression, caps, validation, restart, UTF-8 short writes, atomic failure: PASS');
} finally {fs.rmSync(directory,{recursive:true,force:true});}
