'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '..', 'AuthService.js'), 'utf8');

function signed(bytes) { return [...bytes].map((byte) => byte > 127 ? byte - 256 : byte); }
function unsigned(bytes) { return bytes.map((byte) => byte < 0 ? byte + 256 : byte); }
function load() {
  const cache = new Map(), properties = new Map([['AUTH_SERVICE_SHARED_SECRET', 's'.repeat(32)]]);
  let byteHmacCalls = 0;
  let newBlobCalls = 0;
  const sandbox = {
    console: {error() {}}, Date, JSON, Math, Number, String, Array, Object, parseInt,
    PropertiesService: {getScriptProperties: () => ({getProperty: key => properties.get(key) || null, setProperty: (key, value) => properties.set(key, String(value)), deleteProperty: key => properties.delete(key), getProperties: () => Object.fromEntries(properties)})},
    CacheService: {getScriptCache: () => ({get: key => cache.get(key) || null, put: (key, value) => cache.set(key, String(value)), remove: key => cache.delete(key)})},
    Utilities: {
      Charset: {UTF_8: 'utf8'},
      DigestAlgorithm: {SHA_256: 'sha256'},
      computeDigest(_algorithm, value) {
        const bytes = Array.isArray(value) ? Buffer.from(unsigned(value)) : Buffer.from(String(value), 'utf8');
        return signed(crypto.createHash('sha256').update(bytes).digest());
      },
      computeHmacSha256Signature(value, key, charset) {
        if (Array.isArray(value) && Array.isArray(key)) {
          byteHmacCalls++;
          return signed(crypto.createHmac('sha256', Buffer.from(unsigned(key))).update(Buffer.from(unsigned(value))).digest());
        }
        return signed(crypto.createHmac('sha256', String(key)).update(Buffer.from(String(value), charset || 'utf8')).digest());
      },
      newBlob(value) {
        newBlobCalls++;
        const bytes = Buffer.from(String(value), 'utf8');
        return {getBytes: () => signed(bytes)};
      },
      getUuid: () => '01234567-89ab-4cde-8fab-0123456789ab',
    },
  };
  vm.createContext(sandbox); vm.runInContext(source, sandbox, {filename: 'AuthService.js'});
  return {api: sandbox, byteHmacCalls: () => byteHmacCalls, newBlobCalls: () => newBlobCalls};
}

test('PBKDF2-HMAC-SHA-256 output matches standard vectors and caches key bytes', () => {
  const {api, byteHmacCalls, newBlobCalls} = load(), salt = '0a'.repeat(32), password = 'Correct Horse Battery Staple';
  assert.equal(api.authPbkdf2Hex_(password, salt, 120000), crypto.pbkdf2Sync(password, Buffer.from(salt, 'hex'), 120000, 32, 'sha256').toString('hex'));
  assert.equal(byteHmacCalls(), 120000, 'each PBKDF2 round should use the native byte-array HMAC overload');
  assert.equal(newBlobCalls(), 1, 'password bytes should be materialized once per derivation');
  const longPassword = 'p'.repeat(80);
  assert.equal(api.authPbkdf2Hex_(longPassword, salt, 100000), crypto.pbkdf2Sync(longPassword, Buffer.from(salt, 'hex'), 100000, 32, 'sha256').toString('hex'));
  assert.equal(newBlobCalls(), 2, 'each derivation should materialize password bytes once');
  assert.equal(api.authPbkdf2Hex_(password, salt, 99999), '');
});
test('signed internal envelopes reject reuse and altered payloads', () => {
  const {api} = load(), timestamp = Date.now(), nonce = 'a'.repeat(64), payloadJson = JSON.stringify({token: 'b'.repeat(64)}), signature = api.authHmacHex_('s'.repeat(32), `introspect\n${timestamp}\n${nonce}\n${payloadJson}`), envelope = {action: 'introspect', timestamp, nonce, payloadJson, signature};
  assert.equal(api.authVerifyEnvelope_(envelope).success, true);
  assert.equal(api.authVerifyEnvelope_(envelope).kode, 'AUTH_REQUEST_REPLAY');
  assert.equal(api.authVerifyEnvelope_({...envelope, nonce: 'c'.repeat(64), payloadJson: '{}'}).kode, 'AUTH_REQUEST_INVALID');
});
test('authentication project exposes no public credential reset action', () => {
  assert.match(source, /PBKDF2_ITERATIONS: 120000/); assert.match(source, /authPbkdf2Hex_/); assert.match(source, /authVersion/); assert.doesNotMatch(source, /action === 'resetCredential'/);
});
test('logout derives device revocation from its authenticated session only', () => {
  assert.match(source, /var session = authReadSession_\(token\)/);
  assert.match(source, /authDeleteDevice_\(session\.deviceToken\)/);
  assert.doesNotMatch(source, /if \(deviceToken\) authDeleteDevice_\(deviceToken\)/);
});
