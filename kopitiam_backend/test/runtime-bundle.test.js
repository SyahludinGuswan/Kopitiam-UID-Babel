'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const path = require('node:path');
const {consolidate, build} = require('../scripts/build-runtime.cjs');

test('explicit selection preserves public names in either source order', () => {
  const sources = [
    {name:'old.js',text:'function doPost(e){return "old";} function triggerHandler(){return doPost();}'},
    {name:'new.js',text:'function doPost(e){return "new";}'}
  ];
  for (const order of [sources, [...sources].reverse()]) {
    const result = consolidate(order, {doPost:'new.js'});
    const context = vm.createContext({}); vm.runInContext(result.code, context);
    assert.equal(context.triggerHandler(), 'new');
    assert.equal(context.doPost.toString(), 'function doPost(e){return "new";}');
  }
});
test('unknown duplicate fails closed', () => {
  assert.throws(() => consolidate([{name:'a.js',text:'function f(){}'},{name:'b.js',text:'function f(){}'}], {}), /Unreviewed duplicate/);
});
test('stale selection fails closed', () => {
  assert.throws(() => consolidate([{name:'a.js',text:'function f(){}'}], {f:'missing.js'}), /not unique/);
});
test('function-looking text and nested declarations remain intact', () => {
  const text = 'function publicEntry(){const s="function fake(){}"; function nested(){return /[{}]/.test(s);} return nested();}';
  const result = consolidate([{name:'a.js',text}], {});
  assert.equal(result.report.functions.length, 1);
  const c = vm.createContext({}); vm.runInContext(result.code, c); assert.equal(c.publicEntry(), true);
});
test('top-level executable overrides are rejected', () => {
  assert.throws(() => consolidate([{name:'a.js',text:'function f(){}; f = function(){};'}], {}), /Unexpected top-level/);
});
test('real bundle preserves every global function and exact selected implementation', () => {
  const result = build(path.resolve(__dirname, '..'));
  const context = vm.createContext({ContentService: {createTextOutput: text => ({text, setMimeType(){return this;}}), MimeType: {JSON:'json'}}});
  vm.runInContext(result.code, context, {timeout: 5000});
  for (const [symbol, entry] of result.winners) {
    assert.equal(typeof context[symbol], 'function', symbol);
    assert.equal(context[symbol].toString(), entry.text, symbol);
  }
  for (const symbol of ['doPost','doGet','setupBackend','bersihkanTokenPerangkatKedaluwarsa','setupOperationJournalTriggers_','operationJournalScheduledMaintenance_','operationJournalScheduledArchive_','testSyncTemuanDummy','testDriveAccess','auditWoSources']) {
    assert.equal(typeof context[symbol], 'function', symbol);
  }
  assert.equal(JSON.parse(context.doGet({parameter:{action:'health'}}).text).success, true);
  assert.equal(JSON.parse(context.doGet({parameter:{action:'write'}}).text).kode, 'POST_REQUIRED');
  assert.equal(result.report.functions.filter(f => f.declarations.length > 1).length, 18);
  assert.equal(consolidate([...result.report.sources].reverse().map(s => ({name:s.file, text:require('node:fs').readFileSync(path.resolve(__dirname,'..',s.file),'utf8')})), require('../runtime-manifest.json').selected).report.functions.length, result.report.functions.length);
});
test('composed runtime rejects corrupt terminal receipt without business execution', () => {
  const result = build(path.resolve(__dirname, '..'));
  const crypto = require('node:crypto');
  const context = vm.createContext({}); vm.runInContext(result.code, context);
  context.sha256_ = text => crypto.createHash('sha256').update(String(text)).digest('hex');
  context.operationJournalPrepare_ = () => ({State:'purged','Receipt JSON':'{"success":true}','Receipt Digest':'bad'});
  let executed = false;
  const response = context.operationJournalRun_('syncWoRow', {rows:[{'Kode WO':'WO-1',clientPayloadDigest:'a'.repeat(64)}]}, {username:'user.a'}, () => {executed = true; return {success:true};});
  assert.equal(response.kode, 'OPERATION_RECEIPT_INTEGRITY_FAILED');
  assert.equal(executed, false);
});
