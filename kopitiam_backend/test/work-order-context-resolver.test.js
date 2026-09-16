'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../WorkOrderContext.js'), 'utf8');

function load() {
  const sandbox = {
    CONFIG: {WO_INSJAR_SHEET: 'WO_Ins_Jar', WO_INSDU_SHEET: 'WO_Ins_Du'},
    normalize_: (value) => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' '),
    fail_: (kode, message) => ({success: false, kode, message}),
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('Insjar resolves only to Jaringan parent sheet', () => {
  const api = load();
  assert.deepEqual(
    JSON.parse(JSON.stringify(api.woContextMode_({subTim: 'Inspeksi Jaringan', username: 'a.insjar'}))),
    {success: true, mode: 'insjar', object: 'Jaringan', sheetName: 'WO_Ins_Jar'},
  );
});

test('Insdu resolves only to Gardu parent sheet', () => {
  const api = load();
  assert.deepEqual(
    JSON.parse(JSON.stringify(api.woContextMode_({subTim: 'Inspeksi Gardu', username: 'a.insdu'}))),
    {success: true, mode: 'insdu', object: 'Gardu', sheetName: 'WO_Ins_Du'},
  );
});

test('ambiguous or unrelated account fails closed', () => {
  const api = load();
  assert.equal(api.woContextMode_({subTim: 'Insjar Insdu'}).kode, 'WO_CONTEXT_AMBIGUOUS');
  assert.equal(api.woContextMode_({subTim: 'ROW'}).kode, 'WO_CONTEXT_DENIED');
});

test('source enforces unique parent and object filter', () => {
  assert.match(source, /matches\.length > 1/);
  assert.match(source, /jenis object/);
  assert.match(source, /context\.object/);
});
