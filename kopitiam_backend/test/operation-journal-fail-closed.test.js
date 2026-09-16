'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '../ZZZZZZZZZZZZZZZZZZZZ_OperationJournalFailClosed.js'),
  'utf8',
);

function load() {
  const sandbox = {
    normalize_: value => String(value ?? '').trim().toLowerCase(),
    fail_: (kode, message) => ({success: false, kode, message}),
    operationJournalIdentity_: () => ({operationId: 'op-1'}),
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

test('corrupt terminal receipt fails closed without executor', () => {
  const api = load();
  let executed = false;
  api.operationJournalPrepare_ = () => ({
    State: 'purged',
    'Receipt JSON': '{"success":true}',
    'Receipt Digest': 'corrupt',
  });
  api.operationJournalReplay_ = () => null;
  const result = api.operationJournalRun_('syncWoRow', {}, {}, () => {
    executed = true;
    return {success: true};
  });
  assert.equal(result.kode, 'OPERATION_RECEIPT_INTEGRITY_FAILED');
  assert.equal(executed, false);
});

test('valid terminal replay skips claim and executor', () => {
  const api = load();
  let claimed = false;
  let executed = false;
  api.operationJournalPrepare_ = () => ({State: 'archived'});
  api.operationJournalReplay_ = () => ({success: true, replayed: true});
  api.opjClaim_ = () => { claimed = true; };
  const result = api.operationJournalRun_('syncWoRow', {}, {}, () => {
    executed = true;
    return {success: true};
  });
  assert.equal(result.success, true);
  assert.equal(claimed, false);
  assert.equal(executed, false);
});

test('payload verification occurs only outside lock scopes', () => {
  const prepare = source.slice(
    source.indexOf('function operationJournalPrepare_'),
    source.indexOf('function operationJournalRun_'),
  );
  const firstRelease = prepare.indexOf('lock.releaseLock()');
  const firstVerify = prepare.indexOf('opjLoadPayloadVerified_');
  assert.ok(firstRelease >= 0);
  assert.ok(firstVerify > firstRelease);
  assert.doesNotMatch(
    prepare.slice(prepare.lastIndexOf('lock = LockService.getScriptLock()')),
    /opjLoadPayloadVerified_[\s\S]*finally[\s\S]*lock\.releaseLock/,
  );
});

test('terminal states are checked before claim', () => {
  const run = source.slice(source.indexOf('function operationJournalRun_'));
  assert.ok(run.indexOf("var terminal") < run.indexOf('opjClaim_'));
  assert.match(run, /Never re-execute a terminal operation/);
});
