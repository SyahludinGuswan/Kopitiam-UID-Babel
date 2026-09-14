'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../ZZZZZZZZZ_LiveAccountQuota.js'), 'utf8');
function load() {
  const cache = new Map();
  const normalize = value => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  const sandbox = {
    ACTION_LIMITS_: {syncWoInsdu:{limit:2,seconds:60},getMasterGardu:{limit:1,seconds:60},loginPerangkat:{limit:2,seconds:60}},
    normalize_: normalize,
    sha256_: value => `hash-${value}`.padEnd(64, '0'),
    fail_: (kode,message) => ({success:false,kode,message}),
    console:{error(){}},
    CacheService:{getScriptCache:()=>({get:key=>cache.get(key)||null,put:(key,value)=>cache.set(key,value)})},
    LockService:{getScriptLock:()=>({waitLock(){},releaseLock(){}})},
  };
  vm.createContext(sandbox);vm.runInContext(source,sandbox);return {api:sandbox,cache};
}
test('all sessions and devices of one live username share a quota bucket',()=>{const {api}=load(),now=Date.UTC(2026,8,14,8);assert.equal(api.consumeLiveAccountQuota_('syncWoInsdu',{username:' Koba.Insdu '},now).success,true);assert.equal(api.consumeLiveAccountQuota_('syncWoInsdu',{username:'koba.insdu'},now).success,true);const blocked=api.consumeLiveAccountQuota_('syncWoInsdu',{username:'KOBA.INSDU'},now);assert.equal(blocked.kode,'ACTION_RATE_LIMIT');});
test('a different verified account has an independent bucket',()=>{const {api}=load(),now=Date.UTC(2026,8,14,8);api.consumeLiveAccountQuota_('syncWoInsdu',{username:'koba.insdu'},now);api.consumeLiveAccountQuota_('syncWoInsdu',{username:'koba.insdu'},now);assert.equal(api.consumeLiveAccountQuota_('syncWoInsdu',{username:'toboali.insdu'},now).success,true);});
test('payload device token cannot influence live account quota',()=>{const {api}=load(),now=Date.UTC(2026,8,14,8);const session={username:'koba.insdu',deviceToken:'verified-device'};assert.equal(api.consumeLiveAccountQuota_('getMasterGardu',session,now).success,true);session.deviceToken='payload-spoof-1';assert.equal(api.consumeLiveAccountQuota_('getMasterGardu',session,now).kode,'ACTION_RATE_LIMIT');});
test('protected quota rejects a missing live principal',()=>{const {api}=load();assert.equal(api.consumeLiveAccountQuota_('syncWoInsdu',null,Date.now()).kode,'SESSION_INVALID');assert.equal(api.consumeLiveAccountQuota_('syncWoInsdu',{},Date.now()).kode,'SESSION_INVALID');});
test('login pre-auth quota is normalized by username',()=>{const {api}=load();assert.equal(api.consumePreAuthQuota_('loginPerangkat',{username:' Koba.Insdu '}).success,true);});
