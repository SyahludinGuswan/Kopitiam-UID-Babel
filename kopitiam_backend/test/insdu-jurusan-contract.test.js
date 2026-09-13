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

test('WBP and LWBP coordinates and canonical capture times are required', () => {
  const api = load();
  assert.doesNotThrow(() => api.validateInsduCoordinates_({
    'Koordinat Penginputan WBP': '-3.019482,106.454827',
    'Waktu Penginputan WBP': '13 September 2026, 16:00:00',
    'Koordinat Penginputan LWBP': '-3.019481,106.454828',
    'Waktu Penginputan LWBP': '13 September 2026, 23:00:00',
  }));
});

test('capture time rejects malformed and impossible dates', () => {
  const api = load();
  for (const value of ['2026-09-13T16:00:00', '13 Sep 2026, 16:00:00', '32 September 2026, 16:00:00', '29 Februari 2025, 16:00:00', '13 September 2026, 24:00:00']) {
    assert.throws(() => api.insduCaptureTime_(value, 'Waktu Penginputan WBP'), (error) => error.insduCode === 'INSDU_CAPTURE_TIME_INVALID');
  }
  assert.equal(api.insduCaptureTime_('29 Februari 2024, 06:07:08', 'Waktu Penginputan WBP'), '29 Februari 2024, 06:07:08');
});

test('coordinate guard rejects malformed, out-of-range, and Null Island values', () => {
  const api = load();
  for (const value of ['abc', '1,2,3', '91,106', '-3,181', '0,0']) {
    assert.throws(() => api.insduCoordinate_(value, 'Koordinat'), (error) => error.insduCode === 'INSDU_COORDINATE_INVALID');
  }
});

test('server recalculates distance in meters from central Gardu coordinate', () => {
  const api = load();
  const gardu = api.insduCoordinate_('-3.019482,106.454827', 'Koordinat Gardu');
  const same = api.insduCoordinate_('-3.019482,106.454827', 'Koordinat Penginputan WBP');
  const nearby = api.insduCoordinate_('-3.019392,106.454827', 'Koordinat Penginputan LWBP');
  assert.equal(api.insduDistanceMeters_(gardu, same), 0);
  assert.ok(api.insduDistanceMeters_(gardu, nearby) >= 9 && api.insduDistanceMeters_(gardu, nearby) <= 11);
});

test('invalid central Gardu coordinate produces no reference distance', () => {
  const api = load();
  assert.equal(api.insduCentralCoordinate_({'Koordinat Gardu': '', Lat: '', Long: ''}), null);
  assert.equal(api.insduCentralCoordinate_({'Koordinat Gardu': 'invalid', Lat: '0', Long: '0'}), null);
  assert.deepEqual(JSON.parse(JSON.stringify(api.insduCentralCoordinate_({'Koordinat Gardu': '', Lat: '-3,019482', Long: '106,454827'}))), {latitude: -3.019482, longitude: 106.454827});
});
