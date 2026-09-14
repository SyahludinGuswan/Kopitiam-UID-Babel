'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../ZZZZZZZ_LiveAuthorizationGuard.js'), 'utf8');
function load({cached, current, active = true, failRead = false}) {
  let revoked = false;
  const normalize = (value) => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  const sandbox = {
    console: {error() {}},
    normalize_: normalize,
    normalizeCode_: (value) => String(value ?? '').replace(/[^A-Z0-9]/gi, '').toUpperCase().replace(/^0+/, ''),
    cekSesi_: () => ({success: true, sesi: cached}),
    findUser_: () => { if (failRead) throw Error('sheet unavailable'); return current ? ['row'] : null; },
    accountStatus_: () => ({exists: !!current, active}),
    userFromRow_: () => current,
    revokeBoundSession_: () => { revoked = true; },
    fail_: (kode, message) => ({success: false, kode, message}),
  };
  vm.createContext(sandbox); vm.runInContext(source, sandbox);
  return {api: sandbox, revoked: () => revoked};
}
const profile = {username:'koba.insdu',kodeUiw:'16',kodeUp3:'161',kodeUlp:'16140',ulp:'Koba',role:'Petugas',bidang:'Distribusi',tim:'Inspeksi',subTim:'Insdu',aksesMenu:'Insdu',deviceToken:'device'};
test('protected request accepts an unchanged live profile', () => {
  const t = load({cached: profile, current: {...profile}});
  assert.equal(t.api.requireLiveAuthorization_('syncWoInsdu', 'token').success, true);
  assert.equal(t.revoked(), false);
});
test('role, ULP, team, or sub-team change revokes cached session and device', () => {
  for (const [field, value] of [['role','Admin'],['kodeUlp','16150'],['tim','Har'],['subTim','Har Du']]) {
    const t = load({cached: profile, current: {...profile, [field]: value}});
    const result = t.api.requireLiveAuthorization_('syncWoInsdu', 'token');
    assert.equal(result.kode, 'AUTHORIZATION_CHANGED');
    assert.equal(t.revoked(), true);
  }
});
test('inactive account is revoked and central read failure fails closed', () => {
  const inactive = load({cached: profile, current: {...profile}, active:false});
  assert.equal(inactive.api.requireLiveAuthorization_('getWoInsdu', 'token').kode, 'ACCOUNT_INACTIVE');
  assert.equal(inactive.revoked(), true);
  const unavailable = load({cached: profile, current: {...profile}, failRead:true});
  assert.equal(unavailable.api.requireLiveAuthorization_('getWoInsdu', 'token').kode, 'AUTHORIZATION_UNAVAILABLE');
});
test('login and logout remain available without a live profile', () => {
  const t = load({cached: profile, current: null, failRead:true});
  for (const action of ['login','loginPerangkat','cekPerangkat','logout','logoutPerangkat']) {
    assert.equal(t.api.requireLiveAuthorization_(action, '').success, true);
  }
});
