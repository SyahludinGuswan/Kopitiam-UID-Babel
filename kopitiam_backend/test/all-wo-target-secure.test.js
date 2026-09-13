'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../ZZZZ_AllWoTargetSecure.js'), 'utf8');
function load() {
  const normalize = (value) => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  const sandbox = {
    normalize_: normalize,
    headerIndex_: (headers) => Object.fromEntries(headers.map((header, index) => [normalize(header), index])),
    console: { error() {} },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

const headers = ['Kode WO', 'ULP', 'Tanggal', 'Status WO'];
const values = [headers,
  ['WO-1', 'Koba', '08 September 2026', 'Menunggu'],
  ['WO-1', 'Toboali', '08 September 2026', 'Menunggu'],
  ['WO-1', 'Koba', '09 September 2026', 'Menunggu'],
];

test('all WO modules resolve one row from WO, ULP, and work date together', () => {
  const api = load();
  for (const mode of ['insjar', 'insdu', 'row', 'harjar', 'hardu']) {
    const result = api.woVerifiedPrepareTargets_({ ulp: 'Koba' }, values, headers, [{
      'Kode WO': 'WO-1', ULP: 'Koba', Tanggal: '09 September 2026', module: mode,
    }]);
    assert.equal(result.prepared.length, 1);
    assert.equal(result.prepared[0].rowIndex, 3);
  }
});

test('cross-ULP payload is rejected even when WO and date exist', () => {
  const api = load();
  assert.throws(() => api.woVerifiedPrepareTargets_({ ulp: 'Koba' }, values, headers, [{
    'Kode WO': 'WO-1', ULP: 'Toboali', Tanggal: '08 September 2026',
  }]), (error) => error.woCode === 'WO_ULP_DENIED');
});

test('duplicate three-part keys are rejected instead of choosing the first row', () => {
  const api = load();
  const duplicate = values.concat([['WO-1', 'Koba', '08 September 2026', 'Menunggu']]);
  assert.throws(() => api.woVerifiedPrepareTargets_({ ulp: 'Koba' }, duplicate, headers, [{
    'Kode WO': 'WO-1', ULP: 'Koba', 'Tanggal Pekerjaan': '08 September 2026',
  }]), (error) => error.woCode === 'WO_TARGET_AMBIGUOUS');
});

test('missing WO, ULP, or work date is rejected', () => {
  const api = load();
  assert.throws(() => api.woVerifiedPrepareTargets_({ ulp: 'Koba' }, values, headers, [{
    'Kode WO': 'WO-1', ULP: 'Koba',
  }]), (error) => error.woCode === 'WO_TARGET_INCOMPLETE');
});
