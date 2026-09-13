'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../ZZZ_HarLegacySecure.js'), 'utf8');

function setup(rows) {
  const headers = ['Kode WO', 'ULP', 'Tanggal', 'Status WO', 'Catatan Petugas', 'Folder Path'];
  const data = [headers, ...rows.map((row) => headers.map((header) => row[header] ?? ''))];
  let locked = 0;
  const sheet = {
    getDataRange: () => ({ getDisplayValues: () => data.map((row) => row.map(String)) }),
    getRange: (row, column) => ({ setValue: (value) => { data[row - 1][column - 1] = value; } }),
  };
  const normalize = (value) => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  const sandbox = {
    console: { error() {} },
    CONFIG: { WO_SPREADSHEET_ID: 'wo', WO_HAR_JAR_SHEET: 'WO_Har_Jar', WO_HAR_DU_SHEET: 'WO_Har_Du' },
    WO_HAR_MUTABLE_HEADERS: ['catatan petugas', 'status wo', 'folder path'],
    cekSesi_: () => ({ success: true, sesi: { username: 'koba.harjar', kodeUlp: '16140', ulp: 'Koba' } }),
    woHarAccess_: () => ({ success: true }),
    fail_: (kode, message) => ({ success: false, kode, message }),
    normalize_: normalize,
    headerIndex_: (values) => Object.fromEntries(values.map((value, index) => [normalize(value), index])),
    safePath_: (value) => String(value),
    safeCell_: (value) => String(value ?? ''),
    uploadWoPhoto_: () => { throw new Error('unexpected upload'); },
    SpreadsheetApp: { openById: () => ({ getSheetByName: () => sheet }), flush() {} },
    LockService: { getScriptLock: () => ({ waitLock() { locked++; }, releaseLock() { locked--; } }) },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return { sandbox, data, locked: () => locked };
}

const baseRows = [
  { 'Kode WO': 'HAR-001', ULP: 'Koba', Tanggal: '08 September 2026', 'Status WO': 'Menunggu', 'Catatan Petugas': '', 'Folder Path': 'Kopitiam/A' },
  { 'Kode WO': 'HAR-001', ULP: 'Toboali', Tanggal: '08 September 2026', 'Status WO': 'Menunggu', 'Catatan Petugas': '', 'Folder Path': 'Kopitiam/B' },
  { 'Kode WO': 'HAR-001', ULP: 'Koba', Tanggal: '09 September 2026', 'Status WO': 'Menunggu', 'Catatan Petugas': '', 'Folder Path': 'Kopitiam/C' },
];

test('legacy Har updates only the row where WO, ULP, and work date match together', () => {
  const t = setup(baseRows);
  const result = t.sandbox.syncHarLegacySecure_('token', 'jar', [{
    'Kode WO': 'HAR-001', ULP: 'Koba', 'Tanggal Pekerjaan': '09 September 2026', 'Catatan Petugas': 'target',
  }]);
  assert.equal(result.success, true);
  assert.equal(t.data[1][4], '');
  assert.equal(t.data[2][4], '');
  assert.equal(t.data[3][4], 'target');
  assert.equal(t.data[3][3], 'Selesai');
  assert.equal(t.locked(), 0);
});

test('legacy Har rejects a payload whose ULP differs from the authenticated account', () => {
  const t = setup(baseRows);
  const result = t.sandbox.syncHarLegacySecure_('token', 'jar', [{
    'Kode WO': 'HAR-001', ULP: 'Toboali', Tanggal: '08 September 2026', 'Catatan Petugas': 'blocked',
  }]);
  assert.equal(result.success, false);
  assert.equal(result.kode, 'HAR_ULP_DENIED');
  assert.equal(t.data[2][4], '');
  assert.equal(t.locked(), 0);
});

test('legacy Har rejects duplicate rows with the same three-part key', () => {
  const duplicate = [...baseRows, { ...baseRows[0] }];
  const t = setup(duplicate);
  const result = t.sandbox.syncHarLegacySecure_('token', 'jar', [{
    'Kode WO': 'HAR-001', ULP: 'Koba', Tanggal: '08 September 2026', 'Catatan Petugas': 'blocked',
  }]);
  assert.equal(result.success, false);
  assert.equal(result.kode, 'WO_TARGET_AMBIGUOUS');
  assert.equal(t.data[1][4], '');
  assert.equal(t.data[4][4], '');
  assert.equal(t.locked(), 0);
});

test('legacy Har rejects incomplete three-part target before any write', () => {
  const t = setup(baseRows);
  const result = t.sandbox.syncHarLegacySecure_('token', 'jar', [{
    'Kode WO': 'HAR-001', ULP: 'Koba', 'Catatan Petugas': 'blocked',
  }]);
  assert.equal(result.success, false);
  assert.equal(result.kode, 'HAR_TARGET_INCOMPLETE');
  assert.equal(t.data[1][4], '');
  assert.equal(t.locked(), 0);
});
