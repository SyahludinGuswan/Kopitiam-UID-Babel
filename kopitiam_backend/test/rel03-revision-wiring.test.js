const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const backend = path.join(__dirname, '..');
const read = (name) => fs.readFileSync(path.join(backend, name), 'utf8');

test('REL-03 metadata contract is external and fail-closed', () => {
  const source = read('RevisionMetadata.js');
  assert.match(source, /REVISION_METADATA_SPREADSHEET_ID/);
  assert.match(source, /REVISION_INDEX/);
  assert.match(source, /REVISION_AUDIT/);
  assert.match(source, /METADATA_CONFIG/);
  assert.match(source, /REVISION_CONFLICT/);
  assert.match(source, /LockService/);
  assert.match(source, /maxHistory: 10/);
});

test('REL-03 writes preserve formulas and immutable cells', () => {
  const helper = read('RevisionMetadataWrites.js');
  const wo = read('WorkOrderCore.js');
  const temuan = read('IdempotentUpload.js');
  const har = read('ZZZZZZZZZZZZZZZZZZZZZZ_REL03RevisionWiring.js');
  assert.match(helper, /revisionWriteChangedCells_/);
  assert.match(wo, /revisionWriteChangedCells_\(sheet/);
  assert.match(temuan, /revisionWriteChangedCells_\(sheet/);
  assert.match(har, /revisionWriteChangedCells_\(sh/);
  assert.doesNotMatch(temuan, /target, 1, 1, headers\.length\)\.setValues\(\[output\]\)/);
  assert.doesNotMatch(wo, /target \+ 1, 1, 1, headers\.length\)\.setValues\(\[output\]\)/);
});

test('REL-03 stable keys cover Temuan and WO records', () => {
  const temuan = read('IdempotentUpload.js');
  const wo = read('WorkOrderCore.js');
  const har = read('ZZZZZZZZZZZZZZZZZZZZZZ_REL03RevisionWiring.js');
  assert.match(temuan, /revisionStableKey_\(\[context\.kodeUlp, kodeWo, code\]\)/);
  assert.match(wo, /revisionStableKey_\(\[access\.kodeUlp, code\]\)/);
  assert.match(har, /revisionStableKey_\(\[sesi\.kodeUlp, kodeWo\]\)/);
});
