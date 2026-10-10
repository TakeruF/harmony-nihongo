const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
function load(file, dependencies = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText, { exports, require: name => dependencies[name], Date });
  return exports;
}
const kana = load('entry/src/main/ets/input/KanaComposition.ets');
const {ClipboardComposition, clipboardTextBoundaries} = load('entry/src/main/ets/input/ClipboardComposition.ets', {'./KanaComposition': kana});
const data = JSON.parse(fs.readFileSync('entry/src/main/resources/rawfile/emoji-15.1-ja.json', 'utf8'));
const sequences = data.categories.flatMap(category => category.entries.flatMap(entry => [entry.value, ...(entry.variants || [])]));
const segmenter = new Intl.Segmenter('ja', {granularity:'grapheme'});
for (const value of [...sequences, 'e\u0301', 'か\u3099', '\r\n']) {
  const expected = [0]; let offset = 0;
  for (const part of segmenter.segment(value)) { offset += part.segment.length; expected.push(offset); }
  assert.deepEqual(Array.from(clipboardTextBoundaries(value)), expected, value);
  const c = new ClipboardComposition(); c.insert('あ' + value + 'b'); c.move(-1);
  assert.equal(c.cursor, 1 + value.length); c.move(-1); assert.equal(c.cursor, 1);
  c.move(1); c.backspace(); assert.equal(c.reading, 'あb'); assert.equal(c.cursor, 1);
}
const c = new ClipboardComposition(); c.tap(['あ','い'], 1000); c.tap(['あ','い'], 1100);
assert.equal(c.reading, 'い'); c.backspace(); assert.equal(c.reading, '');
console.log('Local clip editing: ' + sequences.length + ' catalog sequences checked against Intl.Segmenter; complete deletion, cursor boundaries, combining marks and repeated kana: PASS');
