'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const source = fs.readFileSync(
  path.join(__dirname, '../ZZZZZZZZZZ_ReceiptGuard.js'),
  'utf8',
);

function load() {
  const normalize = (value) =>
      String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  const sandbox = {
    normalize_: normalize,
    sha256_: (value) =>
        crypto.createHash('sha256').update(String(value)).digest('hex'),
    WO_COMMIT_TRANSPORT_KEYS_: {},
    fail_: (kode, message) => ({success: false, kode, message}),
    woCommitFail_: (kode, message) => {
      const error = Error(message);
      error.woCommitCode = kode;
      throw error;
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('client digest is validated without replacing existing commit guard', () => {
  const api = load();
  const row = {
    'Kode WO': 'WO-1',
    ULP: 'Koba',
    Tanggal: '15 September 2026',
    'Status WO': 'Selesai',
  };
  const digest = api.receiptPayloadDigest_(row);
  assert.doesNotThrow(() =>
    api.receiptValidateRows_([{...row, clientPayloadDigest: digest}]),
  );
  assert.throws(() =>
    api.receiptValidateRows_([
      {...row, clientPayloadDigest: '0'.repeat(64)},
    ]),
  );
});

test('server-derived fields do not change client digest', () => {
  const api = load();
  const row = {
    'Kode WO': 'WO-1',
    ULP: 'Koba',
    Tanggal: '15 September 2026',
  };
  assert.equal(
    api.receiptPayloadDigest_(row),
    api.receiptPayloadDigest_({
      ...row,
      'Folder Path': 'server',
      'Jarak Antar Gardu ke Petugas (WBP)': 12.3,
    }),
  );
});

test('photo is required only for photo modules', () => {
  const api = load();
  const digest = 'a'.repeat(64);
  const rows = [{'Kode WO': 'WO-1', clientPayloadDigest: digest}];
  const base = {
    success: true,
    receipts: [
      {
        committed: true,
        kodeWo: 'WO-1',
        payloadDigest: digest,
        photo: null,
      },
    ],
  };
  assert.equal(
    api.receiptFinalize_(JSON.parse(JSON.stringify(base)), rows, false).success,
    true,
  );
  const blocked = api.receiptFinalize_(
    JSON.parse(JSON.stringify(base)),
    rows,
    true,
  );
  assert.equal(blocked.success, false);
  assert.equal(blocked.kode, 'SYNC_PHOTO_RECEIPT_REQUIRED');
});
