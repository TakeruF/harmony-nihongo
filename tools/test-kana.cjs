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
// Gboard 14.2 Japanese 12-key defaults to combined flick/toggle input.
assert.equal(settings.flickOnly,false);
assert.equal(settings.keitaiOnly,false);
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

const {TwelveKeyLayout}=load('TwelveKeyLayout');
const reference=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/gboard-14.2-alphabet.json'),'utf8'));
const groups=TwelveKeyLayout.alphabet.flat().concat([TwelveKeyLayout.quotes,TwelveKeyLayout.alphabetPunctuation]);
const directions=[[0,0],[-30,0],[0,-30],[30,0],[0,30]];
assert.equal(reference.length,groups.length);
for(let index=0;index<groups.length;index++) {
  const group=groups[index];
  const recorded=Object.values(reference[index].directions);
  for(let direction=0;direction<5;direction++) {
    const tracker=new FlickTracker();tracker.begin(1,group.values,100,100,1);
    const [dx,dy]=directions[direction];
    const actual=tracker.end(1,100+dx,100+dy).map(x=>x.value).join('');
    assert.equal(actual,recorded[direction],reference[index].key+': '+Object.keys(reference[index].directions)[direction]);
  }
}
c.clear();c.insert('a');c.transform('case');assert.equal(c.reading,'A');c.transform('case');assert.equal(c.reading,'a');
c.clear();c.insert('か');c.transform('case');assert.equal(c.reading,'か');
console.log('55 Gboard-recorded alphabet gestures, blank-direction cancellation, letter case: PASS');

const numberReference=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/gboard-14.2-number.json'),'utf8'));
const numberGroups=TwelveKeyLayout.numbers.flat().concat([TwelveKeyLayout.brackets,TwelveKeyLayout.zero,TwelveKeyLayout.numberPunctuation]);
for(let index=0;index<numberGroups.length;index++) {
  for(let direction=0;direction<5;direction++) {
    const tracker=new FlickTracker();tracker.begin(1,numberGroups[index].values,100,100,1);
    const [dx,dy]=directions[direction];
    assert.equal(tracker.end(1,100+dx,100+dy).map(x=>x.value).join(''),Object.values(numberReference[index].directions)[direction]);
  }
}
console.log('60 Gboard-recorded number/symbol gestures, exact Unicode and blank directions: PASS');

const tapReference=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/gboard-14.2-tap-cycles.json'),'utf8'));
for(const [index,group] of [groups[1],groups[0],TwelveKeyLayout.quotes].entries()) {
  const tapValues=TwelveKeyLayout.alphabetTapValues(group.values);
  for(let count=1;count<=tapReference[index].cycles.length;count++) {
    c.clear();for(let tap=0;tap<count;tap++)c.tap(tapValues,1000+tap*100);
    assert.equal(c.reading,tapReference[index].cycles[count-1],tapReference[index].key+' taps='+count);
  }
}
console.log('21 recorded Gboard tap cycles: lowercase, uppercase, digits, punctuation: PASS');

const reverse = new KanaComposition();
reverse.tap(['あ','い','う','え','お'], 1000); reverse.tap(['か','き','く','け','こ'], 2000);
assert.equal(reverse.canReverse, true); reverse.reverseTap(3000); assert.equal(reverse.reading, 'あこ');
reverse.reverseTap(4000); assert.equal(reverse.reading, 'あけ');
reverse.clear(); reverse.insert('い'); reverse.reverseTap(); assert.equal(reverse.reading, 'い'); assert.equal(reverse.canReverse, false);
reverse.clear(); reverse.tap(['か','き','く','け','こ'], 1000); reverse.transform('variant'); reverse.reverseTap(); assert.equal(reverse.reading, 'が');
reverse.clear(); reverse.tap(['a','b','c','A','B','C','2'], 1000);
for (const value of ['2','C','B']) { reverse.reverseTap(); assert.equal(reverse.reading, value); }
console.log('Gboard reverse key: tap cycle backwards, flick and transformed text unchanged: PASS');
