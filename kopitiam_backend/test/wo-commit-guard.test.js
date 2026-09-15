'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const targetSource = fs.readFileSync(
  path.join(__dirname, '../ZZZZ_AllWoTargetSecure.js'),
  'utf8',
);
const receiptSource = fs.readFileSync(
  path.join(__dirname, '../ZZZZZZZZZZ_ReceiptGuard.js'),
  'utf8',
);
const source = fs.readFileSync(
  path.join(__dirname, '../ZZZZZ_WoCommitGuard.js'),
  'utf8',
);

function load() {
  const normalize = (value) =>
      String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  const sandbox = {
    console: {error() {}},
    normalize_: normalize,
    headerIndex_: (headers) =>
        Object.fromEntries(headers.map((header, index) => [normalize(header), index])),
    sha256_: (value) =>
        crypto.createHash('sha256').update(String(value)).digest('hex'),
    digestBytes_: (bytes) =>
        crypto.createHash('sha256').update(Buffer.from(bytes)).digest('hex'),
    fail_: (kode, message) => ({success: false, kode, message}),
  };
  vm.createContext(sandbox);
  vm.runInContext(targetSource, sandbox);
  vm.runInContext(receiptSource, sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('canonical comparison accepts equivalent numeric Sheet display values', () => {
  const api = load();
  assert.equal(api.woCommitEqual_('1,50', 1.5), true);
  assert.equal(
    api.woCommitEqual_('  Progress   Pekerjaan ', 'progress pekerjaan'),
    true,
  );
  assert.equal(api.woCommitEqual_('Koba', 'Toboali'), false);
});

test('unmapped local fields fail instead of being silently ignored', () => {
  const api = load();
  assert.throws(
    () => api.woCommitExpected_(['Kode WO', 'ULP', 'Tanggal'], {
      'kode wo': 'WO-1',
      ulp: 'Koba',
      tanggal: '13 September 2026',
      'kolom baru': 'nilai',
    }),
    (error) => error.woCommitCode === 'WO_FIELD_UNMAPPED',
  );
});

test('Drive verification checks MIME, byte count, and digest', () => {
  const api = load();
  const bytes = [255, 216, 255, 217];
  const digest = crypto.createHash('sha256').update(Buffer.from(bytes)).digest('hex');
  const file = {
    getId: () => 'file-1',
    getName: () => 'photo.jpg',
    getUrl: () => 'https://drive/photo',
    getBlob: () => ({
      getContentType: () => 'image/jpeg',
      getBytes: () => bytes,
    }),
  };
  const receipt = api.woCommitVerifyPhoto_({file}, {bytes, digest});
  assert.equal(receipt.fileId, 'file-1');
  assert.equal(receipt.digest, digest);
});

test('Drive digest mismatch blocks acknowledgement', () => {
  const api = load();
  const file = {
    getBlob: () => ({
      getContentType: () => 'image/jpeg',
      getBytes: () => [1, 2, 3],
    }),
  };
  assert.throws(
    () => api.woCommitVerifyPhoto_(
      {file},
      {bytes: [1, 2, 3], digest: 'wrong'},
    ),
    (error) => error.woCommitCode === 'WO_PHOTO_DIGEST_MISMATCH',
  );
});

test('receipt binds WO identity, verified payload digest, and photo', () => {
  const api = load();
  const normalized = {
    'kode wo': 'WO-1',
    ulp: 'Koba',
    tanggal: '13 September 2026',
    'status wo': 'Selesai',
  };
  normalized.clientpayloaddigest = api.receiptPayloadDigest_(normalized);
  const item = {code: 'WO-1', normalized};
  const receipt = api.woCommitReceipt_(
    item,
    {'status wo': 'Selesai'},
    {receipt: {fileId: 'file-1', digest: 'abc'}},
  );
  assert.equal(receipt.committed, true);
  assert.equal(receipt.kodeWo, 'WO-1');
  assert.equal(receipt.photo.fileId, 'file-1');
  assert.equal(receipt.payloadDigest, normalized.clientpayloaddigest);
});
