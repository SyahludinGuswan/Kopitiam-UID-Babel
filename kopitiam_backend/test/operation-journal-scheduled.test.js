'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../ZZZZZZZZZZZZZZZZZ_OperationJournalScheduled.js'),'utf8');
function load(){const sandbox={normalize_:v=>String(v??'').trim().toLowerCase()};vm.createContext(sandbox);vm.runInContext(source,sandbox);return sandbox;}
test('archived and purged receipts replay without re-executing',()=>{const api=load();for(const state of ['committed','archived','purged']){const out=api.operationJournalReplay_({'State':state,'Receipt JSON':'{"success":true}','Operation ID':'op'});assert.equal(out.success,true);assert.equal(out.journalState,state);}});
test('failed archived receipt never replays success',()=>{const api=load();assert.equal(api.operationJournalReplay_({'State':'archived','Receipt JSON':'{"success":false}'}),null);});
test('Temuan verifier requires central Sheet read-back and digest',()=>{assert.match(source,/temuanSheet_/);assert.match(source,/getDataRange\(\)\.getDisplayValues/);assert.match(source,/sheetDigest/);assert.match(source,/Payload File ID/);});
test('scheduled maintenance and archive triggers are installed',()=>{assert.match(source,/everyMinutes\(15\)/);assert.match(source,/everyDays\(1\)/);assert.match(source,/operationJournalSweepStaleLeases_/);assert.match(source,/operationJournalArchive_/);});
test('unattended maintenance never bypasses live authorization',()=>{assert.match(source,/Business replay[\s\S]*requires a live user session/);assert.doesNotMatch(source,/issueSession_/);});
