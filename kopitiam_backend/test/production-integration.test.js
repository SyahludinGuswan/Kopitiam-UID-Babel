"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const code = fs.readFileSync(path.join(root, "Code.js"), "utf8");
const authBridge = fs.readFileSync(path.join(root, "AuthServiceBridge.js"), "utf8");
const idempotent = fs.readFileSync(path.join(root, "IdempotentUpload.js"), "utf8");

test("production POST router consumes action quota before dispatch", () => {
  assert.match(code, /function doPost\(e\)/);
  assert.match(code, /consumeActionQuota_\(a, runtimeIdentity_\(b\)\)/);
  assert.match(code, /runtimeIdentity_\(body\)/);
});

test("device handler delegates refresh to the separate authentication service", () => {
  assert.match(code, /function cekPerangkat_\(t\)/);
  assert.match(code, /authServiceCall_\("refresh"/);
  assert.match(code, /operationalSession_\(auth\)/);
});

test("every protected request uses live Auth token introspection", () => {
  assert.match(code, /function cekSesi_\(t\)/);
  assert.match(code, /authServiceCall_\("introspect"/);
  assert.match(code, /SESSION_INVALID/);
});

test("backend revokes through Auth rather than retaining local session or password state", () => {
  assert.match(code, /authServiceCall_\("logout"/);
  assert.doesNotMatch(code, /passwordSignature_|PASSWORD_PEPPER|session_/);
});

test("operational account status is checked after Auth introspection", () => {
  assert.match(authBridge, /accountStatus_\(username\)/);
  assert.match(authBridge, /ACCOUNT_INACTIVE/);
  assert.match(authBridge, /operationalSession_\(auth\)/);
});

test("central master derivation runs before idempotent Temuan context", () => {
  assert.match(idempotent, /function syncTemuanInspeksiIdempotent_/);
  const fnStart = idempotent.indexOf("function syncTemuanInspeksiIdempotent_");
  const next = idempotent.indexOf("\nfunction ", fnStart + 1);
  const fnBody = idempotent.slice(fnStart, next < 0 ? undefined : next);
  assert.match(fnBody, /resolveFindingMaster_/);
  assert.match(fnBody, /resolveFindingAsset_/);
  assert.match(fnBody, /incoming\["Jenis Object"\]/);
  const masterIdx = fnBody.indexOf("resolveFindingMaster_");
  const syncIdx = fnBody.indexOf("woContext_");
  assert.ok(masterIdx < syncIdx, "central master derivation must run before woContext_");
});
