"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const code = read("Code.js");
const guards = read("RuntimeGuards.js");
const upload = read("IdempotentUpload.js");
const router = read("ZZ_ApiRouterOverride.js");

function loadCentralRole(role) {
  const row = ["1", "16", "161", "16140", "ULP Koba", "pegawai", role, "", "", "", ""];
  const sandbox = {
    console,
    fail_: (kode, message) => ({ success: false, kode, message }),
  };
  vm.createContext(sandbox);
  vm.runInContext(`${code}\n${guards}`, sandbox, { filename: "role-access.js" });
  sandbox.findUser_ = () => row.slice();
  sandbox.accountStatus_ = () => ({ exists: true, active: true });
  return sandbox;
}

test("role policy accepts only Super User, Admin, and Pegawai PLN", () => {
  const api = loadCentralRole("Admin");
  assert.equal(api.isC4aRoleAllowed_("Super User"), true);
  assert.equal(api.isC4aRoleAllowed_("admin"), true);
  assert.equal(api.isC4aRoleAllowed_("Pegawai PLN"), true);
  assert.equal(api.isC4aRoleAllowed_("Vendor"), false);
  assert.equal(api.isC4aRoleAllowed_("User"), false);
});

test("C4A authorization uses the central role instead of session role", () => {
  const denied = loadCentralRole("User");
  assert.equal(
    denied.requireC4aAccess_({ username: "pegawai", role: "Admin" }).kode,
    "C4A_ACCESS_DENIED",
  );

  const allowed = loadCentralRole("Admin");
  const result = allowed.requireC4aAccess_({
    username: "pegawai",
    role: "Vendor",
  });
  assert.equal(result.success, true);
  assert.equal(result.profile.role, "Admin");
});

test("role endpoint and no-WO C4A transaction are guarded", () => {
  assert.match(code, /getRoleProfile_\(t\)/);
  assert.match(code, /a === "getRoleProfile"/);
  assert.match(router, /action === 'getRoleProfile'/);
  assert.match(upload, /requireC4aAccess_\(auth\.sesi\)/);
  assert.match(upload, /\b(?:var\s+[^;]*,\s*)?isC4a = kodeWo === ""/);
  assert.match(upload, /"Kode UIW": safeText_\(central\.kodeUiw/);
});
