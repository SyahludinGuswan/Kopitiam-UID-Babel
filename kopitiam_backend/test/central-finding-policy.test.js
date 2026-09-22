'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../RuntimeGuards.js'), 'utf8');

function sheet(rows) { return {getDataRange: () => ({getDisplayValues: () => rows})}; }
function load(sheets) {
  const normalize = value => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  const sandbox = {
    console, Math, Number, String, Date, isFinite,
    CONFIG: {USERS_SHEET: 'Users'}, USER_COL: {role: 6},
    normalize_: normalize,
    normalizeCode_: value => String(value ?? '').replace(/\D/g, '').replace(/^0+/, ''),
    headerIndex_: headers => Object.fromEntries(headers.map((header, index) => [normalize(header), index])),
    fail_: (kode, message) => ({success: false, kode, message}),
    getSpreadsheet_: () => ({getSheetByName: name => sheets[name] || null}),
  };
  vm.createContext(sandbox); vm.runInContext(source, sandbox); return sandbox;
}

test('Tier and non-vegetation priority are derived from one central row', () => {
  const api = load({Master_Temuan: sheet([
    ['Objek Inspeksi', 'Tier', 'Temuan', 'Prioritas'],
    ['Jaringan', 'Tier 2', 'Isolator Retak', 'Mayor'],
  ])});
  assert.deepEqual(
    JSON.parse(JSON.stringify(api.resolveFindingMaster_('Jaringan', 'Isolator Retak', {}))),
    {success: true, object: 'Jaringan', tier: 'Tier 2', finding: 'Isolator Retak', priority: 'Mayor'},
  );
  assert.equal(api.validateFindingMaster_('Jaringan', 'Tier 1', 'Isolator Retak', 'Mayor', {}).kode, 'TIER_MISMATCH');
});

test('vegetation priority is calculated server-side from central finding identity', () => {
  const api = load({Master_Temuan: sheet([
    ['Objek Inspeksi', 'Tier', 'Temuan', 'Prioritas'],
    ['Jaringan', 'Tier 1', 'Tebang Besar', 'Minor'],
  ])});
  const result = api.resolveFindingMaster_('Jaringan', 'Tebang Besar', {
    'Jarak Terhadap Jaringan': 4, 'Tinggi Pohon': 10,
  });
  assert.equal(result.priority, 'Mayor');
});

test('ambiguous central finding is rejected', () => {
  const api = load({Master_Temuan: sheet([
    ['Objek Inspeksi', 'Tier', 'Temuan', 'Prioritas'],
    ['Gardu', 'Tier 1', 'Bushing', 'Mayor'],
    ['Gardu', 'Tier 2', 'Bushing', 'Minor'],
  ])});
  assert.equal(api.resolveFindingMaster_('Gardu', 'Bushing', {}).kode, 'FINDING_MASTER_AMBIGUOUS');
});

test('Gardu asset relation is loaded from the unique ULP master row', () => {
  const api = load({Master_Gardu: sheet([
    ['Kode ULP', 'GARDU', 'PENYULANG', 'PTS/LBS'],
    ['16140', 'G-1', 'Koba', 'KP-1'],
  ])});
  const result = api.resolveFindingAsset_('Gardu', {'Nomor Gardu': 'G-1'}, {kodeUlp: '16140', values: {ULP: 'Koba'}});
  assert.equal(result.success, true);
  assert.equal(result.values.Penyulang, 'Koba');
  assert.equal(result.values.Section, 'KP-1');
});
