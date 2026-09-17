'use strict';

const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const tracked = execFileSync('git', ['ls-files'], {cwd: root, encoding: 'utf8'})
  .split(/\r?\n/)
  .filter(Boolean);
const signingMaterial = /(^|\/)(key\.properties|[^/]+\.(?:jks|keystore|p12|pfx|pem|der))$/i;
const violations = tracked.filter((file) => {
  const exists = fs.existsSync(path.join(root, file));
  return exists && file.startsWith('kopitiam_mobile/android/') && signingMaterial.test(file);
});
const gradlePath = path.join(root, 'kopitiam_mobile', 'android', 'app', 'build.gradle.kts');
const gradle = fs.readFileSync(gradlePath, 'utf8');

if (/obfuscate|Base64\.getDecoder|xor\s+0x/i.test(gradle)) {
  violations.push('kopitiam_mobile/android/app/build.gradle.kts contains signing-secret obfuscation');
}
for (const required of ['requiredReleaseSigningProperty("storeFile")', 'requiredReleaseSigningProperty("storePassword")', 'requiredReleaseSigningProperty("keyAlias")', 'requiredReleaseSigningProperty("keyPassword")']) {
  if (!gradle.includes(required)) violations.push(`Release signing does not require ${required}`);
}

if (violations.length) {
  console.error('Android signing guard failed:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log('Android signing guard passed: no tracked signing material or Gradle secret obfuscation.');