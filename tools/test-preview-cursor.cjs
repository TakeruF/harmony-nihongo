const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const pending = new Map(); let timer = 0;
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/input/PreviewCursorProbe.ets', 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, {
  exports: exportsObject,
  setTimeout: (fn, ms) => { assert.equal(ms, 400); pending.set(++timer, fn); return timer; },
  clearTimeout: id => pending.delete(id)
});
(async () => {
  const probe = exportsObject.probePreviewCursor;
  assert.equal(await probe(() => Promise.resolve(17)), 17); assert.equal(pending.size, 0);
  let release;
  const result = probe(() => new Promise(resolve => { release = resolve; }));
  const callback = pending.get(timer); pending.delete(timer); callback();
  assert.equal(await result, undefined);
  release(42); await Promise.resolve(); assert.equal(await result, undefined); assert.equal(pending.size, 0);
  await assert.rejects(probe(() => Promise.reject(new Error('lost editor'))), /lost editor/);
  assert.equal(pending.size, 0);
  console.log('Preview cursor: normal position, missing reply deadline, ignored late reply, error propagation: PASS');
})().catch(error => { console.error(error); process.exitCode = 1; });
