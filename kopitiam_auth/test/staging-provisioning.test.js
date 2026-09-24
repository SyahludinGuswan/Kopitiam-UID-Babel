'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../staging-only/Provisioning.js'), 'utf8');

function setup(properties = {}) {
  const values = [['Username', 'Password Hash', 'Salt', 'Iterations', 'Auth Version', 'Status', 'Migrated At', 'Reset Required']];
  let locks = 0;
  let releases = 0;
  const props = new Map(Object.entries({
    AUTH_ENVIRONMENT: 'STAGING',
    AUTH_SPREADSHEET_ID: 'staging-sheet-id',
    AUTH_STAGING_SPREADSHEET_ID: 'staging-sheet-id',
    STAGING_TEST_USERNAME: 'staging.smoke',
    STAGING_TEST_PASSWORD: 'Strong-Staging-Password-2026',
    ...properties,
  }));
  const sheet = {
    getDataRange: () => ({ getDisplayValues: () => values.map(row => row.slice()) }),
    getLastRow: () => values.length,
    getRange: (row, column, rowCount, columnCount) => ({
      setValues(rows) {
        assert.equal(row, values.length + 1);
        assert.equal(column, 1);
        assert.equal(rowCount, 1);
        assert.equal(columnCount, 8);
        values.push(rows[0].slice());
      },
    }),
  };
  const sandbox = {
    AUTH_CONFIG_: { PBKDF2_ITERATIONS: 120000 },
    AUTH_HEADERS_: ['Username', 'Password Hash', 'Salt', 'Iterations', 'Auth Version', 'Status', 'Migrated At', 'Reset Required'],
    PropertiesService: { getScriptProperties: () => ({
      getProperty: key => props.get(key) || null,
      deleteProperty: key => props.delete(key),
    }) },
    LockService: { getScriptLock: () => ({ waitLock: () => { locks++; }, releaseLock: () => { releases++; } }) },
    Utilities: {
      Charset: { UTF_8: 'utf8' },
      DigestAlgorithm: { SHA_256: 'sha256' },
      getUuid: () => crypto.randomUUID(),
      computeDigest: (_algorithm, value) => [...crypto.createHash('sha256').update(String(value)).digest()].map(byte => byte > 127 ? byte - 256 : byte),
    },
    Date,
    String,
    Number,
    Object,
    Array,
    RegExp,
    Error,
    authNormalize_: value => String(value || '').trim().toLowerCase().replace(/\s+/g, ' '),
    authBytesHex_: bytes => bytes.map(byte => ('0' + (byte < 0 ? byte + 256 : byte).toString(16)).slice(-2)).join(''),
    authPbkdf2Hex_: (password, salt, iterations) => crypto.pbkdf2Sync(password, Buffer.from(salt, 'hex'), iterations, 32, 'sha256').toString('hex'),
    authSheet_: () => sheet,
    authHeaderIndex_: headers => Object.fromEntries(headers.map((header, index) => [header.toLowerCase(), index])),
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, { filename: 'Provisioning.js' });
  return { api: sandbox, props, values, lockCounts: () => [locks, releases] };
}

test('staging provisioner creates one active salted credential and clears plaintext inputs', () => {
  const env = setup();
  const result = env.api.provisionStagingTestCredential_();
  assert.deepEqual(JSON.parse(JSON.stringify(result)), { success: true, created: true, username: 'staging.smoke' });
  const row = env.values[1];
  assert.equal(row[0], 'staging.smoke');
  assert.equal(row[1], crypto.pbkdf2Sync('Strong-Staging-Password-2026', Buffer.from(row[2], 'hex'), 120000, 32, 'sha256').toString('hex'));
  assert.equal(row[1].includes('Strong-Staging-Password-2026'), false);
  assert.equal(row[3], 120000);
  assert.equal(row[5], 'Aktif');
  assert.equal(row[7], 'false');
  assert.equal(env.props.has('STAGING_TEST_PASSWORD'), false);
  assert.equal(env.props.has('STAGING_TEST_USERNAME'), false);
  assert.deepEqual(env.lockCounts(), [1, 1]);
});

test('staging provisioner refuses to run outside the explicit staging environment', () => {
  const env = setup({ AUTH_ENVIRONMENT: 'PRODUCTION' });
  assert.throws(() => env.api.provisionStagingTestCredential_(), /hanya diizinkan untuk Auth STAGING/);
  assert.equal(env.values.length, 1);
  assert.equal(env.props.has('STAGING_TEST_PASSWORD'), true);
  assert.deepEqual(env.lockCounts(), [0, 0]);
});

test('staging provisioner rejects a spreadsheet ID mismatch and clears claimed inputs', () => {
  const env = setup({ AUTH_STAGING_SPREADSHEET_ID: 'different-sheet-id' });
  assert.throws(() => env.api.provisionStagingTestCredential_(), /hanya diizinkan untuk Auth STAGING/);
  assert.equal(env.values.length, 1);
  assert.equal(env.props.has('STAGING_TEST_PASSWORD'), true);
});

test('staging provisioner never overwrites an existing username', () => {
  const env = setup();
  env.values.push(['staging.smoke', 'existing-hash', 'existing-salt', 120000, 1, 'Aktif', 'old-date', 'false']);
  assert.throws(() => env.api.provisionStagingTestCredential_(), /sudah ada/);
  assert.equal(env.values.length, 2);
  assert.equal(env.values[1][1], 'existing-hash');
  assert.equal(env.props.has('STAGING_TEST_PASSWORD'), false);
  assert.deepEqual(env.lockCounts(), [1, 1]);
});
