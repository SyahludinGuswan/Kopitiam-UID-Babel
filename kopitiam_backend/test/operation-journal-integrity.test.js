'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const source=fs.readFileSync(path.join(__dirname,'../ZZZZZZZZZZZZZZZZZZZ_OperationJournalIntegrity.js'),'utf8');
function load(){const s={normalize_:v=>String(v??'').trim().toLowerCase(),sha256_:v=>crypto.createHash('sha256').update(String(v)).digest('hex')};vm.createContext(s);vm.runInContext(source,s);return s;}
test('payload loader requires stored checksum and verifies bytes',()=>{assert.match(source,/Payload File Digest/);assert.match(source,/sha256_\(raw\)/);assert.match(source,/Checksum payload durable tidak cocok/);});
test('receipt replay requires matching checksum in every terminal state',()=>{const api=load(),raw='{"success":true}',digest=api.sha256_(raw);for(const state of ['committed','archived','purged'])assert.equal(api.operationJournalReplay_({'State':state,'Receipt JSON':raw,'Receipt Digest':digest}).success,true);assert.equal(api.operationJournalReplay_({'State':'committed','Receipt JSON':raw,'Receipt Digest':'0'.repeat(64)}),null);});
test('reconciliation uses verified payload loader',()=>{assert.match(source,/opjExecuteStored_\(record\['Action'\], opjLoadPayloadVerified_\(record\), token\)/);});
test('new journal records persist payload and receipt digest columns',()=>{assert.match(source,/'Payload File Digest': String\(stored\.digest\)/);assert.match(source,/'Receipt Digest': sha256_\(receipt\)/);});
