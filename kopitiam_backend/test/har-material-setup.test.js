'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const backendDir = path.resolve(__dirname, '..');
const contractSource = fs.readFileSync(path.join(backendDir, 'HarMaterialSheetContract.js'), 'utf8');
const setupSource = fs.readFileSync(path.join(backendDir, 'Setup.js'), 'utf8');
const manifest = JSON.parse(fs.readFileSync(path.join(backendDir, 'runtime-manifest.json'), 'utf8'));

function loadContract() {
  const sandbox = { CONFIG: { MATERIAL_HAR_JAR_SHEET: 'Realisasi_Material_HarJar' } };
  vm.createContext(sandbox);
  vm.runInContext(contractSource, sandbox, { filename: 'HarMaterialSheetContract.js' });
  vm.runInContext(setupSource, sandbox, { filename: 'Setup.js' });
  return sandbox;
}

function sheet(headers) {
  return {
    getName: () => 'Material_WO_Har',
    getLastColumn: () => headers.length,
    getRange: (row, column, rowCount, columnCount) => ({
      getDisplayValues: () => [headers.slice(column - 1, column - 1 + columnCount)],
    }),
  };
}

test('runtime bundle includes the production HAR material contract', () => {
  assert.ok(manifest.sources.includes('HarMaterialSheetContract.js'));
  const backend = loadContract();
  assert.equal(backend.CONFIG.MATERIAL_HAR_JAR_SHEET, 'Material_WO_Har');
});

test('setup accepts the actual Material_WO_Har headers, including trailing blank columns', () => {
  const backend = loadContract();
  const headers = Array.from(backend.HAR_MATERIAL_SETUP_HEADERS_);
  headers.push('', '', '');
  assert.doesNotThrow(() => backend.requireSheet_(
    { getSheetByName: name => name === 'Material_WO_Har' ? sheet(headers) : null },
    backend.CONFIG.MATERIAL_HAR_JAR_SHEET,
    backend.HAR_MATERIAL_SETUP_HEADERS_,
  ));
});

test('setup rejects the old/incorrect Kode WO header and never falls back to the legacy tab', () => {
  const backend = loadContract();
  const headers = Array.from(backend.HAR_MATERIAL_SETUP_HEADERS_);
  headers[headers.indexOf('Kode WO Har')] = 'Kode WO';
  assert.throws(() => backend.requireSheet_(
    { getSheetByName: name => name === 'Material_WO_Har' ? sheet(headers) : null },
    backend.CONFIG.MATERIAL_HAR_JAR_SHEET,
    backend.HAR_MATERIAL_SETUP_HEADERS_,
  ), /Kode WO Har/);
  assert.throws(() => backend.requireSheet_({ getSheetByName: () => null },
    backend.CONFIG.MATERIAL_HAR_JAR_SHEET, backend.HAR_MATERIAL_SETUP_HEADERS_),
  /Material_WO_Har/);
});
