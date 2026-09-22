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

test('completed WO cannot transition back to progress', () => {
  const api = load();
  const finished = [headers, ['WO-1', 'Koba', '08 September 2026', 'Selesai']];
  assert.throws(() => api.woVerifiedPrepareTargets_({ ulp: 'Koba' }, finished, headers, [{
    'Kode WO': 'WO-1', ULP: 'Koba', Tanggal: '08 September 2026',
    'Status WO': 'Progress Pekerjaan',
  }]), (error) => error.woCode === 'WO_STATUS_TRANSITION_DENIED');
});

test('immutable WO identity fields cannot be changed', () => {
  const api = load();
  const identityHeaders = ['Kode WO', 'ULP', 'Tanggal', 'Status WO', 'Kode Temuan'];
  const identityValues = [identityHeaders, ['WO-1', 'Koba', '08 September 2026', 'Menunggu', 'TO-1']];
  assert.throws(() => api.woVerifiedPrepareTargets_({ ulp: 'Koba' }, identityValues, identityHeaders, [{
    'Kode WO': 'WO-1', ULP: 'Koba', Tanggal: '08 September 2026',
    'Status WO': 'Progress Pekerjaan', 'Kode Temuan': 'TO-LAIN',
  }]), (error) => error.woCode === 'WO_IMMUTABLE_FIELD');
});

test('ROW and Har assignment policy is enforced from the existing row', () => {
  const api = load();
  const rowHeaders = ['Kode WO', 'ULP', 'Tanggal', 'Status WO', 'Tim Eksekusi', 'Tindak Lanjut'];
  const rowValues = [rowHeaders, ['WO-1', 'Koba', '08 September 2026', 'Menunggu', 'ROW A', '']];
  assert.throws(() => api.woVerifiedPrepareTargets_({ ulp: 'Koba', subTim: 'ROW B' }, rowValues, rowHeaders, [{
    'Kode WO': 'WO-1', ULP: 'Koba', Tanggal: '08 September 2026', 'Status WO': 'Selesai',
  }]), (error) => error.woCode === 'WO_ASSIGNMENT_DENIED');

  const harHeaders = ['Kode WO', 'ULP', 'Tanggal', 'Status WO', 'Tim Eksekusi', 'Catatan Petugas'];
  const harValues = [harHeaders, ['WO-2', 'Koba', '08 September 2026', 'Menunggu', 'petugas.a', '']];
  assert.throws(() => api.woVerifiedPrepareTargets_({ ulp: 'Koba', username: 'petugas.b' }, harValues, harHeaders, [{
    'Kode WO': 'WO-2', ULP: 'Koba', Tanggal: '08 September 2026', 'Status WO': 'Selesai',
  }]), (error) => error.woCode === 'WO_ASSIGNMENT_DENIED');
});
