'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../TemuanSheetHelpers.js'), 'utf8');

function load() {
  const sandbox = {
    normalize_: (value) => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' '),
    safePath_: (value) => {
      const text = String(value ?? '').trim().replace(/[\\/:*?"<>|\x00-\x1F]/g, '_').substring(0, 120);
      if (!text || text === '.' || text === '..') throw new Error('Invalid path');
      return text;
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('canonical evidence path is derived from central finding fields', () => {
  const api = load();
  assert.equal(
    api.evidenceCanonicalPath_('ULP-01', 'Jaringan', '15 September 2026', 'WO-1.TO-001'),
    'Eviden/ULP-01/Jaringan/2026/09. September/15/WO-1.TO-001/',
  );
});

test('invalid calendar date fails closed', () => {
  const api = load();
  assert.throws(
    () => api.evidenceCanonicalPath_('ULP-01', 'Jaringan', '31 Februari 2026', 'WO-1.TO-001'),
    (error) => error.evidenceCode === 'FINDING_DATE_INVALID',
  );
});

test('resolver strips only known root prefixes', () => {
  const api = load();
  assert.equal(
    api.evidenceRelativePath_('Eviden/ULP-01/Jaringan/2026/09. September/15/WO-1.TO-001/'),
    'ULP-01/Jaringan/2026/09. September/15/WO-1.TO-001',
  );
  assert.equal(
    api.evidenceRelativePath_('Kopitiam/Rekap Temuan Inspeksi/ULP-01/Jaringan/2026/09. September/15/WO-1.TO-001/'),
    'ULP-01/Jaringan/2026/09. September/15/WO-1.TO-001',
  );
});

test('router uses evidence guard for ROW and both Har modules', () => {
  const router = fs.readFileSync(path.join(__dirname, '../ZZ_ApiRouterOverride.js'), 'utf8');
  assert.match(router, /syncWoPhotoWithEvidenceGuard_\(body\.token, 'row'/);
  assert.match(router, /syncHarWithEvidenceGuard_\(body\.token/);
});
