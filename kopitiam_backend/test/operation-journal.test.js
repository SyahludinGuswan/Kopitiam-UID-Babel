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
    normalize_: v => String(v ?? '').trim().toLowerCase().replace(/\s+/g, ' '),
    sha256_: v => crypto.createHash('sha256').update(String(v)).digest('hex'),
    fail_: (kode, message) => ({success: false, kode, message}),
    digestBytes_: bytes => crypto.createHash('sha256').update(Buffer.from(bytes)).digest('hex'),
    Utilities: {base64Decode: value => [...Buffer.from(value, 'base64')]},
  };
  vm.createContext(sandbox); vm.runInContext(source, sandbox); return sandbox;
}

test('operation id binds live user, action, object and digest', () => {
  const api = load(), body = {rows: [{'Kode WO': 'WO-1', clientPayloadDigest: 'a'.repeat(64)}]};
  const a = api.operationJournalIdentity_('syncWoRow', body, {username: 'USER.A'});
  const b = api.operationJournalIdentity_('syncWoRow', body, {username: 'user.b'});
  assert.equal(a.payloadDigest, 'a'.repeat(64));
  assert.notEqual(a.operationId, b.operationId);
});

test('committed journal replays the original receipt', () => {
  const api = load();
  const replay = api.operationJournalReplay_({'State':'committed','Receipt JSON':'{"success":true,"receipts":[]}','Operation ID':'op-1'});
  assert.equal(replay.success, true); assert.equal(replay.replayed, true); assert.equal(replay.operationId, 'op-1');
});

test('prepared and reconciliation states never replay success', () => {
  const api = load();
  assert.equal(api.operationJournalReplay_({'State':'prepared','Receipt JSON':'{"success":true}'}), null);
  assert.equal(api.operationJournalReplay_({'State':'needs-reconciliation','Receipt JSON':'{"success":true}'}), null);
});

test('router journals every write action', () => {
  const router = fs.readFileSync(path.join(__dirname, '../ZZ_ApiRouterOverride.js'), 'utf8');
  for (const action of ['syncWoInsjar','syncWoInsdu','syncWoRow','syncWoHarJar','syncWoHarDu','syncTemuanInspeksi']) {
    assert.match(router, new RegExp("action === '" + action + "'"));
  }
  assert.ok((router.match(/operationJournalRun_/g) || []).length >= 5);
});
