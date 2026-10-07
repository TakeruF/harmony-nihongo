#!/usr/bin/env python3
"""Exercise the actual Node-API probe on macOS; device loading is a separate check."""
import os
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
dev = Path(os.environ.get('NIHONGO_DEVECO_HOME', '/Applications/DevEco-Studio.app/Contents'))
checks = r"""
const assert = require('node:assert/strict');
const probe = require(process.argv[1]);
assert.equal(probe.add(20, 22), 42);
assert.equal(probe.add(-3, 2.5), -0.5);
for (const text of ['', 'abc', 'きょうは', 'がっこう', '😀', 'a\0b']) {
  assert.equal(probe.echo(text), text);
}
assert.throws(() => probe.add('1', 2), TypeError);
assert.throws(() => probe.add(1), TypeError);
assert.throws(() => probe.echo(42), TypeError);
assert.throws(() => probe.echo(), TypeError);
assert.equal(probe.echo('a'.repeat(4096)).length, 4096);
assert.throws(() => probe.echo('a'.repeat(4097)), RangeError);
console.log('Native boundary: arithmetic, UTF-8, empty/NUL strings, invalid arguments, size limits PASS');
"""
with tempfile.TemporaryDirectory(prefix='nihongo-native-test-') as directory:
    module = Path(directory) / 'nihongo.node'
    subprocess.run(['/usr/bin/clang++', '-std=c++20', '-DNIHONGO_HOST_TEST',
                    '-I' + str(dev / 'tools/node/include/node'), '-bundle', '-undefined', 'dynamic_lookup',
                    str(root / 'entry/src/main/cpp/napi_init.cpp'), '-o', str(module)], check=True)
    subprocess.run([str(dev / 'tools/node/bin/node'), '-e', checks, str(module)], check=True)
