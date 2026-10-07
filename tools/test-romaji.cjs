const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/input/RomajiInput.ets','utf8'),{
  compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}
}).outputText,{exports:exportsObject});
const {RomajiInput} = exportsObject;
function decode(text) { const r=new RomajiInput(); let kana=''; for(const ch of text) kana+=r.feed(ch); return kana+r.finish(); }
for(const [roman,kana] of [
  ['kyouha','きょうは'],['watashihahashiwowataru','わたしははしをわたる'],
  ['gakkou','がっこう'],['konnichiha','こんにちは'],['konnichiwa','こんにちわ'],['kanna','かんな'],['shinnyuu','しんにゅう'],
  ['kan','かん'],['kann','かん'],["kin'en",'きんえん'],['nya','にゃ'],['nn','ん'],['nnn','んん'],
  ['matcha','まっちゃ'],['shussha','しゅっしゃ'],['xtsuxyaxuxwa','っゃぅゎ'],
  ['thi-favoxe','てぃーふぁゔぉぇ'],['KYOUHA.','きょうは。'],['kan,','かん、'],['ky','ky'],['qa','qあ']
]) assert.equal(decode(roman),kana,roman);
const r=new RomajiInput(); assert.equal(r.feed('k'),'');assert.equal(r.pending,'k');
assert.equal(r.feed('y'),'');assert.equal(r.pending,'ky');assert(r.erase());assert.equal(r.pending,'k');
assert.equal(r.feed('a'),'か');assert.equal(r.pending,'');
r.feed('n');assert.equal(r.finish(),'ん');assert.equal(r.pending,'');
assert.equal(r.feed('nn'),'ん');assert.equal(r.pending,'');assert.equal(r.finish(),'');
assert.equal(r.feed('nn'),'ん');assert.equal(r.erase(),false);assert.equal(r.feed('a'),'あ');
console.log('Romaji: incremental letters, n/nn, contractions, doubled consonants, small kana, pending deletion: PASS');
