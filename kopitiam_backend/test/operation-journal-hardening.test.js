'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '../ZZZZZZZZZZZZZZZ_OperationJournalHardening.js'),
  'utf8',
);

function load() {
  const sandbox = {
    normalize_: value => String(value ?? '').trim().toLowerCase(),
    fail_: (kode, message) => ({success: false, kode, message}),
    operationJournalIdentity_: () => ({
      operationId: 'op',
      objectId: 'WO-1',
      payloadDigest: 'a'.repeat(64),
    }),
    operationJournalReplay_: () => null,
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  // The hardening module intentionally overrides operationJournalPrepare_.
  // Stub it after evaluation so orchestration tests do not touch Apps Script I/O.
  sandbox.operationJournalPrepare_ = () => ({
    State: 'prepared',
    'Operation ID': 'op',
  });
  return sandbox;
}

test('concurrent duplicate is blocked before executor', () => {
  const api = load();
  let ran = false;
  api.opjClaim_ = () => ({busy: true});
  const output = api.operationJournalRun_('syncWoRow', {}, {}, () => {
    ran = true;
    return {success: true};
  });
  assert.equal(output.kode, 'OPERATION_IN_PROGRESS');
  assert.equal(ran, false);
});

test('plain success without final receipt is rejected', () => {
  const api = load();
  api.opjClaim_ = () => ({token: 'lease'});
  api.opjFinish_ = () => {};
  const output = api.operationJournalRun_(
    'syncWoRow',
    {},
    {},
    () => ({success: true}),
  );
  assert.equal(output.kode, 'OPERATION_RECEIPT_INVALID');
});

test('WO commit requires one matching committed receipt', () => {
  const api = load();
  const identity = {objectId: 'WO-1', payloadDigest: 'a'.repeat(64)};
  assert.equal(
    api.opjVerifiedSuccess_(
      'syncWoRow',
      {
        success: true,
        receipts: [{
          committed: true,
          kodeWo: 'WO-1',
          payloadDigest: 'a'.repeat(64),
        }],
      },
      identity,
    ),
    true,
  );
  assert.equal(
    api.opjVerifiedSuccess_('syncWoRow', {success: true, receipts: []}, identity),
    false,
  );
});

test('Temuan commit requires both verified photo parents', () => {
  const api = load();
  const result = {
    success: true,
    folderPath: 'Eviden/x',
    photoReceipts: {
      fotoTemuan: {fileId: 'a', parentFolderId: 'p'},
      fotoLingkungan: {fileId: 'b', parentFolderId: 'p'},
    },
  };
  assert.equal(api.opjVerifiedSuccess_('syncTemuanInspeksi', result, {}), true);
  delete result.photoReceipts.fotoLingkungan.parentFolderId;
  assert.equal(api.opjVerifiedSuccess_('syncTemuanInspeksi', result, {}), false);
});

test('hardening stores payload and implements archive', () => {
  assert.match(source, /Payload File ID/);
  assert.match(source, /opjStorePayload_/);
  assert.match(source, /operationJournalArchive_/);
  assert.match(source, /createTextFinder/);
});
