'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const guard = fs.readFileSync(path.join(__dirname, 'check-android-signing.cjs'), 'utf8');
const workflow = fs.readFileSync(
  path.join(root, '.github', 'workflows', 'android-signing-guard.yml'),
  'utf8',
);
const gradle = fs.readFileSync(
  path.join(root, 'kopitiam_mobile', 'android', 'app', 'build.gradle.kts'),
  'utf8',
);

test('signing guard fails closed on tracked material and obfuscation', () => {
  assert.match(guard, /git\\s*['\"]ls-files['\"]/);
  assert.match(guard, /process\\.exit\\(1\\)/);
  assert.match(guard, /key\\\\?\\.properties/);
  assert.match(guard, /\\.jks/);
  assert.match(guard, /obfuscate/);
  assert.match(guard, /Base64/);
  assert.match(guard, /requiredReleaseSigningProperty/);
});

test('release workflow executes the guard with read-only permissions', () => {
  assert.match(workflow, /pull_request:/);
  assert.match(workflow, /contents:\s*read/);
  assert.match(workflow, /node ci\\/check-android-signing\\.cjs/);
});

test('release signing remains fail-closed when required properties are missing', () => {
  for (const property of ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']) {
    assert.match(gradle, new RegExp(`requiredReleaseSigningProperty\\([\"']${property}[\"']\\)`));
  }
  assert.match(gradle, /Release signing Kopitiam belum dikonfigurasi/);
  assert.match(gradle, /Keystore release tidak ditemukan/);
});
