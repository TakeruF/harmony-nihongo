// Exercise the production service with unavailable hardware and asynchronous failures.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const dev = process.env.NIHONGO_DEVECO_HOME || '/Applications/DevEco-Studio.app/Contents';
const ts = require(path.join(dev, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js'));
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/ime/KeyboardHaptics.ets'), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
function service(supported, failure) {
  let enabled = true, allowed = true, checks = 0, warnings = 0;
  const calls = [];
  const context = { exports: {}, AppStorage: { get: key => key === 'imeHapticsAllowed' ? allowed : enabled }, require: name => {
    if (name === '@kit.SensorServiceKit') return { vibrator: {
      isSupportEffectSync: () => { checks++; return supported; },
      startVibration: (effect, attribute) => {
        calls.push({ effect, attribute });
        if (failure === 'sync') throw { code: 801 };
        if (failure === 'async') return Promise.reject({ code: 201 });
        // A pending motor request must never hold up input.
        return new Promise(() => {});
      }
    } };
    if (name === '@kit.PerformanceAnalysisKit') return { hilog: { warn: () => warnings++ } };
    return {};
  } };
  vm.runInNewContext(compiled, context);
  return { haptics: context.exports.keyboardHaptics, calls, checks: () => checks,
    warnings: () => warnings, disable: () => { enabled = false; }, mode: value => { allowed = value; } };
}
(async () => {
  const preset = service(true);
  preset.haptics.initialize(); preset.haptics.initialize();
  assert.equal(preset.checks(), 1);
  assert.equal(preset.haptics.tap(), undefined);
  assert.equal(preset.calls[0].effect.type, 'preset');
  assert.equal(preset.calls[0].effect.count, 1);
  assert.equal(preset.calls[0].attribute.usage, 'touch');
  preset.disable(); preset.haptics.tap(); assert.equal(preset.calls.length, 1);
  const modes = service(true); modes.mode(false);
  modes.haptics.initialize(); modes.haptics.tap();
  assert.equal(modes.checks(), 0); assert.equal(modes.calls.length, 0);
  modes.mode(true); modes.haptics.tap(); assert.equal(modes.calls.length, 1);
  modes.mode(false); modes.haptics.tap(); assert.equal(modes.calls.length, 1);
  const fallback = service(false); fallback.haptics.initialize(); fallback.haptics.tap();
  assert.equal(fallback.calls[0].effect.type, 'time');
  assert.equal(fallback.calls[0].effect.duration, 10);
  for (const failure of ['sync', 'async']) {
    const broken = service(false, failure); broken.haptics.initialize();
    assert.doesNotThrow(() => { broken.haptics.tap(); broken.haptics.tap(); });
    await Promise.resolve(); assert.equal(broken.warnings(), 1);
  }
  console.log('Haptics: preset/fallback, off switch, nonblocking requests, failure isolation: PASS');
})().catch(error => { console.error(error); process.exitCode = 1; });
