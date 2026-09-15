'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../ZZZZZZZZZZZZZ_EvidenceRuntimeGuard.js'), 'utf8');

function load(propertyValue = '') {
  const sandbox = {
    PropertiesService: {getScriptProperties: () => ({getProperty: () => propertyValue, setProperty() {}})},
    DriveApp: {getFolderById: (id) => ({getId: () => id, getName: () => 'Eviden', isTrashed: () => false})},
    evidenceFail_: (code, message) => { const error = new Error(message); error.evidenceCode = code; throw error; },
    evidenceCanonicalPath_: (ulp, object, date, code) => [ulp, object, date, code].join('|'),
    fail_: (kode, message) => ({success: false, kode, message}),
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('missing root Script Property fails closed', () => {
  const api = load('');
  assert.throws(() => api.evidenceRootFolder_(), (error) => error.evidenceCode === 'EVIDENCE_ROOT_NOT_CONFIGURED');
});

test('configured root is resolved by ID', () => {
  const id = '1HAh-FAonWDyXvOEKroQbvu9vi6tlT1iL';
  const api = load(id);
  assert.equal(api.evidenceRootFolder_().getId(), id);
});

test('finding builders use the request Tanggal, not upload time', () => {
  const api = load('1HAh-FAonWDyXvOEKroQbvu9vi6tlT1iL');
  api.EVIDENCE_REQUEST_DATE_ = '14 September 2026';
  assert.equal(api.buildFindingPath_('ULP-01', 'Jaringan', 'WO-1', 'WO-1.TO-001', new Date('2026-09-15')), 'ULP-01|Jaringan|14 September 2026|WO-1.TO-001');
  assert.equal(api.buildC4aFindingPath_('ULP-01', 'Gardu', 'PEG-1.TO-001', new Date('2026-09-15')), 'ULP-01|Gardu|14 September 2026|PEG-1.TO-001');
});

test('router protects Temuan upload with runtime evidence guard', () => {
  const router = fs.readFileSync(path.join(__dirname, '../ZZ_ApiRouterOverride.js'), 'utf8');
  assert.match(router, /syncTemuanWithEvidenceGuard_\(body\.token, body\.row\)/);
});
