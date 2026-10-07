// Exercises the production pure input modules, without an IME or editor mock.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const dev = process.env.NIHONGO_DEVECO_HOME || '/Applications/DevEco-Studio.app/Contents';
const ts = require(path.join(dev, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js'));
function load(name) {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/input', name + '.ets'), 'utf8');
  const result = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } });
  const context = { exports: {} }; vm.runInNewContext(result.outputText, context); return context.exports;
}
const { KanaComposition } = load('KanaComposition');
const { FlickTracker } = load('FlickTracker');
const c = new KanaComposition();
c.insert('き'); c.insert('よ'); c.transform('small'); c.insert('う'); c.insert('は');
assert.equal(c.reading, 'きょうは');
c.move(-1); c.backspace(); assert.equal(c.reading, 'きょは');
c.insert('う'); assert.equal(c.reading, 'きょうは');
c.clear(); c.insert('か'); c.transform('voice'); c.insert('つ'); c.transform('small'); c.insert('こう');
assert.equal(c.reading, 'がっこう');
c.clear(); c.insert('ひ'); c.transform('voice'); c.transform('voice'); c.insert('ゆ'); c.transform('small');
c.insert('つ'); c.transform('small'); c.insert('と'); assert.equal(c.reading, 'ぴゅっと');
c.move(-100); c.backspace(); assert.equal(c.reading, 'ぴゅっと'); c.move(100); assert.equal(c.cursor, 4);
c.transform('voice'); assert.equal(c.reading, 'ぴゅっど'); c.transform('voice'); assert.equal(c.reading, 'ぴゅっと');
const f = new FlickTracker(); const values = ['あ','い','う','え','お'];
for (const [dx,dy,value] of [[0,0,'あ'],[-30,0,'い'],[0,-30,'う'],[30,0,'え'],[0,30,'お']]) {
  f.begin(1, values, 100, 100, 7); assert.equal(f.end(1,100+dx,100+dy)[0].value, value);
}
f.begin(1,values,0,0,7); f.begin(2,['か','き','く','け','こ'],0,0,7);
assert.equal(f.end(2,0,0).length,0); assert.equal(f.end(1,-30,0).map(x=>x.value).join(''),'いか');
f.begin(1,values,0,0,7); f.begin(2,values,0,0,7); f.end(2,30,0);
assert.equal(f.end(1,0,0,true).map(x=>x.value).join(''),'え');
f.begin(1,values,0,0,7); f.cancelAll(); assert.equal(f.end(1,0,0).length,0);
f.flickEnabled=false; f.begin(1,values,0,0,7); assert.equal(f.end(1,30,0)[0].value,'あ');
f.flickEnabled=true;
for (let i=0;i<100;i++) f.begin(i,values,0,0,7);
let output=''; for (let i=99;i>=0;i--) output+=f.end(i,0,30).map(x=>x.value).join('');
assert.equal(output,'お'.repeat(100));
console.log('Kana state, transformations, five directions, overlap ordering, cancellation: PASS');

const { SettingsValues } = load('SettingsValues');
const settings = new SettingsValues();
assert.equal(settings.valid(),true);
assert.equal(settings.haptics,true);
settings.set('imeHaptics',false); assert.equal(settings.haptics,false);
settings.haptics='invalid'; assert.equal(settings.valid(),false);
settings.haptics=true;
settings.set('imeKeitaiOnly',true); assert.equal(settings.flickOnly,false); assert.equal(settings.keitaiOnly,true);
settings.set('imeFlickOnly',true); assert.equal(settings.keitaiOnly,false);
settings.set('imeFlickOnly',false); assert.equal(settings.valid(),true);
settings.halfSpace='invalid'; assert.equal(settings.valid(),false);
c.clear(); c.tap(['か','き','く','け','こ'],1000); c.tap(['か','き','く','け','こ'],1200);
assert.equal(c.reading,'き'); c.tap(['か','き','く','け','こ'],2000); assert.equal(c.reading,'きか');
c.tap(['か','き','く','け','こ'],2700); assert.equal(c.reading,'きかか');
c.transform('variant'); assert.equal(c.reading,'きかが');
c.clear(); c.insert('つ'); c.transform('variant'); assert.equal(c.reading,'っ'); c.transform('variant'); assert.equal(c.reading,'づ');
console.log('Combined modifier, keitai timing, exclusive settings, malformed values: PASS');
