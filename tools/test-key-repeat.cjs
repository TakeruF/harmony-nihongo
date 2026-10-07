const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const pending = new Map(); let next = 0; let now = 0;
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/input/KeyRepeatTracker.ets', 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, {
  exports: exportsObject,
  setTimeout: (fn, delay) => { const id = ++next; pending.set(id, { fn, at: now + delay }); return id; },
  clearTimeout: id => pending.delete(id)
});
function advance(ms) {
  const end = now + ms;
  while (true) {
    const entry = [...pending].sort((a, b) => a[1].at - b[1].at)[0];
    if (!entry || entry[1].at > end) break;
    pending.delete(entry[0]); now = entry[1].at; entry[1].fn();
  }
  now = end;
}
const keys = new exportsObject.KeyRepeatTracker(); let count = 0;
keys.begin(1, () => count++); assert.equal(count, 1);
advance(399); assert.equal(count, 1); advance(1); assert.equal(count, 2);
advance(140); assert.equal(count, 4); keys.end(1); advance(1000); assert.equal(count, 4);
keys.begin(2, () => count++); const stale = [...pending.values()][0].fn;
keys.end(2); stale(); assert.equal(count, 5); assert.equal(pending.size, 0);
keys.begin(3, () => count++); keys.begin(4, () => count++); keys.clear(); advance(1000);
assert.equal(count, 7); assert.equal(pending.size, 0);
// Session invalidation can cancel from inside a callback without rearming.
keys.begin(5, () => keys.end(5)); assert.equal(pending.size, 0);
keys.begin(6, () => count++); keys.begin(6, () => count++); advance(400);
assert.equal(count, 10); keys.clear(); assert.equal(pending.size, 0);
console.log('Key repeat: immediate press, delay, cadence, release/cancel, stale callback, overlap, cleanup: PASS');
