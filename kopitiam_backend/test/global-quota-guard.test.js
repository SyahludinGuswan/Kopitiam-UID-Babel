'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '../ZZZZZZZZ_GlobalQuotaGuard.js'),
  'utf8',
);

function load({lockFails = false} = {}) {
  const cache = new Map();
  let locked = 0;
  const sandbox = {
    console: {error() {}},
    ACTION_LIMITS_: {
      syncWoInsdu: {limit: 3, seconds: 60},
      getWoInsdu: {limit: 2, seconds: 60},
    },
    CacheService: {
      getScriptCache: () => ({
        get: (key) => cache.get(key) || null,
        put: (key, value) => cache.set(key, value),
      }),
    },
    LockService: {
      getScriptLock: () => ({
        waitLock() {
          if (lockFails) throw Error('busy');
          locked++;
        },
        releaseLock() {
          locked--;
        },
      }),
    },
    fail_: (kode, message) => ({success: false, kode, message}),
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return {api: sandbox, cache, locked: () => locked};
}

test('global quota is shared by all callers of the same action', () => {
  const t = load();
  const now = Date.UTC(2026, 8, 14, 5, 0, 0);
  for (let index = 0; index < 3; index++) {
    assert.equal(t.api.consumeGlobalActionQuota_('syncWoInsdu', now).success, true);
  }
  const blocked = t.api.consumeGlobalActionQuota_('syncWoInsdu', now);
  assert.equal(blocked.success, false);
  assert.equal(blocked.kode, 'SERVER_BUSY');
  assert.equal(t.locked(), 0);
});

test('different actions have independent global buckets', () => {
  const t = load();
  const now = Date.UTC(2026, 8, 14, 5, 0, 0);
  for (let index = 0; index < 3; index++) {
    t.api.consumeGlobalActionQuota_('syncWoInsdu', now);
  }
  assert.equal(t.api.consumeGlobalActionQuota_('getWoInsdu', now).success, true);
});

test('fixed window resets without carrying the old count', () => {
  const t = load();
  const first = Date.UTC(2026, 8, 14, 5, 0, 59);
  for (let index = 0; index < 3; index++) {
    t.api.consumeGlobalActionQuota_('syncWoInsdu', first);
  }
  assert.equal(
    t.api.consumeGlobalActionQuota_('syncWoInsdu', first + 1000).success,
    true,
  );
});

test('lock failure fails closed as SERVER_BUSY', () => {
  const t = load({lockFails: true});
  const result = t.api.consumeGlobalActionQuota_('syncWoInsdu', Date.now());
  assert.equal(result.success, false);
  assert.equal(result.kode, 'SERVER_BUSY');
  assert.equal(t.locked(), 0);
});

test('unknown action does not consume a global bucket', () => {
  const t = load();
  assert.equal(t.api.consumeGlobalActionQuota_('health', Date.now()).success, true);
  assert.equal(t.cache.size, 0);
});
