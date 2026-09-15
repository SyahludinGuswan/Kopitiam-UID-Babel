'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../ZZZZZZZZZZZZ_EvidenceFindingPath.js'), 'utf8');

function load() {
  const sandbox = {
    Session: {getScriptTimeZone: () => 'Asia/Jakarta'},
    Utilities: {
      formatDate: (date, zone, format) => {
        assert.equal(zone, 'Asia/Jakarta');
        if (format === 'dd') return '15';
        if (format === 'MM') return '09';
        if (format === 'yyyy') return '2026';
        throw new Error('unexpected format');
      },
    },
    evidenceFail_: (code, message) => { const error = new Error(message); error.evidenceCode = code; throw error; },
    evidenceCanonicalPath_: (ulp, object, date, code) => [ulp, object, date, code].join('|'),
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('new WO finding path excludes Kode WO and uses Kode Temuan', () => {
  const api = load();
  assert.equal(
    api.buildFindingPath_('ULP-01', 'Jaringan', 'WO-IGNORED', 'WO-1.TO-001', new Date('2026-09-15T10:00:00Z')),
    'ULP-01|Jaringan|15 September 2026|WO-1.TO-001',
  );
});

test('new C4A finding uses the same canonical path builder', () => {
  const api = load();
  assert.equal(
    api.buildC4aFindingPath_('ULP-01', 'Gardu', 'PEG-1.TO-001', new Date('2026-09-15T10:00:00Z')),
    'ULP-01|Gardu|15 September 2026|PEG-1.TO-001',
  );
});
