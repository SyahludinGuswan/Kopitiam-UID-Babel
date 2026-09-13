'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../ZZZZZZ_InsduJurusanContract.js'), 'utf8');
function load() {
  const sandbox = {};
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('Insdu accepts independent Jurusan values from 1 through 4', () => {
  const api = load();
  assert.deepEqual(JSON.parse(JSON.stringify(api.validateInsduJurusan_({'Jurusan Terpasang': 4, 'Jurusan Terpakai': 3}))), {installed: 4, used: 3});
  assert.deepEqual(JSON.parse(JSON.stringify(api.validateInsduJurusan_({'Jurusan Terpasang': '1', 'Jurusan Terpakai': '1'}))), {installed: 1, used: 1});
});

test('Insdu rejects zero, values above four, fractions, blanks, and text', () => {
  const api = load();
  for (const value of [0, 5, 1.5, '', null, '2.0', 'abc']) {
    assert.throws(() => api.validateInsduJurusan_({'Jurusan Terpasang': value, 'Jurusan Terpakai': 1}), (error) => error.insduCode === 'INSDU_JURUSAN_RANGE_INVALID');
  }
});

test('Jurusan Terpakai cannot exceed Jurusan Terpasang', () => {
  const api = load();
  assert.throws(() => api.validateInsduJurusan_({'Jurusan Terpasang': 2, 'Jurusan Terpakai': 3}), (error) => error.insduCode === 'INSDU_JURUSAN_RELATION_INVALID');
});

test('WBP and LWBP coordinates and capture times are required', () => {
  const api = load();
  assert.doesNotThrow(() => api.validateInsduCoordinates_({
    'Koordinat Penginputan WBP': '-3.019482,106.454827',
    'Waktu Penginputan WBP': '13 September 2026, 16:00:00',
    'Koordinat Penginputan LWBP': '-3.019481,106.454828',
    'Waktu Penginputan LWBP': '13 September 2026, 23:00:00',
  }));
  assert.throws(() => api.validateInsduCoordinates_({
    'Koordinat Penginputan WBP': '', 'Waktu Penginputan WBP': '',
    'Koordinat Penginputan LWBP': '-3,106', 'Waktu Penginputan LWBP': 'now',
  }), (error) => error.insduCode === 'INSDU_COORDINATE_INVALID');
});

test('coordinate guard rejects malformed, out-of-range, and Null Island values', () => {
  const api = load();
  for (const value of ['abc', '1,2,3', '91,106', '-3,181', '0,0']) {
    assert.throws(() => api.insduCoordinate_(value, 'Koordinat'), (error) => error.insduCode === 'INSDU_COORDINATE_INVALID');
  }
});
