// Persist only explicit pins; process restarts and failed writes must not lose them.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const compile = name => ts.transpileModule(fs.readFileSync(name, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS }
}).outputText;
const history = {};
vm.runInNewContext(compile('entry/src/main/ets/input/ClipboardHistory.ets'), { exports: history, Date });
let failRename = false;
const fileIo = {
  OpenMode: { CREATE: 1, WRITE_ONLY: 2, TRUNC: 4 }, accessSync: fs.existsSync, statSync: fs.statSync,
  readTextSync: name => fs.readFileSync(name, 'utf8'), openSync: name => ({ fd: fs.openSync(name, 'w') }),
  writeSync: fs.writeSync, closeSync: file => fs.closeSync(file.fd),
  renameSync: (from, to) => { if (failRename) throw Error('Unavailable storage'); fs.renameSync(from, to); }
};
const storeExports = {};
vm.runInNewContext(compile('entry/src/main/ets/ime/ClipboardStore.ets'), {
  exports: storeExports, require: name => name === '@kit.CoreFileKit' ? { fileIo } : history
});
const store = storeExports.clipboardStore, h = history.clipboardHistory;
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'nihongo-pin-test-'));
const savedPath = path.join(directory, 'clipboard-pins.json');
try {
  store.load({ filesDir: directory });
  h.remember('Do not persist ordinary clipboard contents');
  const clip = h.remember('  固定した日本語😀\n二行目  '); h.pin([clip.id], true);
  assert(store.save());
  const first = fs.readFileSync(savedPath, 'utf8');
  assert.deepEqual(JSON.parse(first).pinned, [clip.text]);
  assert(!first.includes('ordinary clipboard'));
  store.stop(); h.clear(); assert.equal(store.save(), false);
  store.load({ filesDir: directory }); assert.equal(h.snapshot().length, 1); assert.equal(h.snapshot()[0].text, clip.text);
  assert.equal(h.snapshot()[0].pinned, true);
  h.setEnabled(false); assert(store.save()); store.stop(); h.clear(); h.enabled = true;
  store.load({ filesDir: directory }); assert.equal(h.enabled, false); assert.equal(h.snapshot().length, 1);
  const intact = fs.readFileSync(savedPath, 'utf8');
  h.clear(); failRename = true; assert.equal(store.save(), false); assert.equal(fs.readFileSync(savedPath, 'utf8'), intact);
  failRename = false; store.stop(); fs.writeFileSync(savedPath, '{broken');
  assert.doesNotThrow(() => store.load({ filesDir: directory })); assert(store.save()); assert.doesNotThrow(() => JSON.parse(fs.readFileSync(savedPath, 'utf8')));
  console.log('Clipboard storage: pins only, Unicode intact, restart, disabled state, stopped store, atomic failure and malformed-file recovery: PASS');
} finally { fs.rmSync(directory, { recursive: true, force: true }); }
