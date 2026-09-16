'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const source = fs.readFileSync(path.join(__dirname, '../ZZZZZZZZZZZZZZ_OperationJournal.js'), 'utf8');

function load() {
  const sandbox = {
    normalize_: value => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' '),
    sha256_: value => crypto.createHash('sha256').update(String(value)).digest('hex'),
    fail_: (kode, message) => ({success: false, kode, message}),
    digestBytes_: bytes => crypto.createHash('sha256').update(Buffer.from(bytes)).digest('hex'),
    Utilities: {base64Decode: value => [...Buffer.from(value, 'base64')]},
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

const body = {rows: [{'Kode WO': 'WO-1', clientPayloadDigest: 'a'.repeat(64)}]};
const session = {username: 'user.a'};
const prepared = {
  'State': 'prepared',
  'Operation ID': 'op-1',
  'Payload Digest': 'a'.repeat(64),
  'Username': 'user.a',
};

function installHappyJournal(api) {
  const events = [];
  api.operationJournalPrepare_ = () => { events.push('prepared'); return prepared; };
  api.operationJournalReplay_ = () => null;
  api.operationJournalMarkAttempt_ = () => events.push('attempt');
  api.operationJournalMarkResult_ = (id, result) => events.push(result.success === true ? 'committed' : 'needs-reconciliation');
  return events;
}

test('journal creation failure blocks all business effects', () => {
  const api = load();
  let executed = false;
  api.operationJournalPrepare_ = () => { throw new Error('journal sheet unavailable'); };
  const result = api.operationJournalRun_('syncWoRow', body, session, () => { executed = true; return {success: true}; });
  assert.equal(result.success, false);
  assert.equal(result.kode, 'OPERATION_JOURNAL_UNAVAILABLE');
  assert.equal(executed, false);
});

test('attempt marker failure blocks executor and records reconciliation failure', () => {
  const api = load();
  let executed = false, marked = null;
  api.operationJournalPrepare_ = () => prepared;
  api.operationJournalReplay_ = () => null;
  api.operationJournalMarkAttempt_ = () => { throw new Error('attempt flush failed'); };
  api.operationJournalMarkResult_ = (id, result) => { marked = result; };
  const result = api.operationJournalRun_('syncWoRow', body, session, () => { executed = true; return {success: true}; });
  assert.equal(executed, false);
  assert.equal(result.kode, 'OPERATION_INTERRUPTED');
  assert.equal(marked.success, false);
});

for (const fault of [
  ['drive-upload', 'WO_PHOTO_UPLOAD_FAILED'],
  ['drive-read-back', 'WO_PHOTO_DIGEST_MISMATCH'],
  ['sheet-write', 'WO_SHEET_WRITE_FAILED'],
  ['sheet-flush', 'WO_SHEET_FLUSH_FAILED'],
  ['sheet-read-back', 'WO_SHEET_VERIFY_FAILED'],
  ['parent-folder-check', 'PHOTO_PARENT_MISMATCH'],
]) {
  test(`fault at ${fault[0]} remains needs-reconciliation`, () => {
    const api = load();
    const events = installHappyJournal(api);
    const result = api.operationJournalRun_('syncWoRow', body, session, () => ({
      success: false,
      kode: fault[1],
      message: `injected ${fault[0]} failure`,
    }));
    assert.equal(result.success, false);
    assert.deepEqual(events, ['prepared', 'attempt', 'needs-reconciliation']);
  });
}

test('executor crash is converted to interrupted and retained for reconciliation', () => {
  const api = load();
  const events = installHappyJournal(api);
  const result = api.operationJournalRun_('syncWoHarJar', body, session, () => { throw new Error('worker crashed'); });
  assert.equal(result.kode, 'OPERATION_INTERRUPTED');
  assert.deepEqual(events, ['prepared', 'attempt', 'needs-reconciliation']);
});

test('journal commit persistence failure never returns business success', () => {
  const api = load();
  let marks = 0;
  api.operationJournalPrepare_ = () => prepared;
  api.operationJournalReplay_ = () => null;
  api.operationJournalMarkAttempt_ = () => {};
  api.operationJournalMarkResult_ = () => { marks++; throw new Error('journal commit flush failed'); };
  const result = api.operationJournalRun_('syncWoRow', body, session, () => ({success: true, receipts: [{committed: true}]}));
  assert.equal(result.success, false);
  assert.equal(result.kode, 'OPERATION_INTERRUPTED');
  assert.equal(marks, 2);
});

test('committed replay skips executor and write stages', () => {
  const api = load();
  let executed = false, attempted = false;
  api.operationJournalPrepare_ = () => ({
    'State': 'committed', 'Operation ID': 'op-1',
    'Receipt JSON': '{"success":true,"receipts":[{"committed":true}]}'
  });
  api.operationJournalMarkAttempt_ = () => { attempted = true; };
  const result = api.operationJournalRun_('syncWoRow', body, session, () => { executed = true; return {success: true}; });
  assert.equal(result.success, true);
  assert.equal(result.replayed, true);
  assert.equal(executed, false);
  assert.equal(attempted, false);
});
