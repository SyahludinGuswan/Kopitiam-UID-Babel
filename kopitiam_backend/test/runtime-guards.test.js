"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "RuntimeGuards.js"), "utf8");

function load() {
  const cache = new Map();
  const sandbox = {
    Date, Number, String, Math, isFinite,
    sha256_: (value) => `hash-${value}`.padEnd(64, "0"),
    fail_: (kode, message) => ({ success: false, kode, message }),
    CacheService: { getScriptCache: () => ({ get: (key) => cache.get(key) || null, put: (key, value) => cache.set(key, value) }) },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, { filename: "RuntimeGuards.js" });
  return sandbox;
}

test("device token rejects absolute age, idle age, corruption, and future time", () => {
  const api = load();
  const day = 24 * 60 * 60 * 1000;
  const now = Date.UTC(2026, 7, 28);
  assert.equal(api.validateDeviceRecord_({ createdAt: now - day, lastUsedAt: now - 1 }, now), "");
  assert.equal(api.validateDeviceRecord_({ createdAt: now - 7 * day, lastUsedAt: now - 1 }, now), "DEVICE_MAX_AGE");
  assert.equal(api.validateDeviceRecord_({ createdAt: now - 2 * day, lastUsedAt: now - day }, now), "DEVICE_IDLE_EXPIRED");
  assert.equal(api.validateDeviceRecord_(null, now), "DEVICE_CORRUPT");
  assert.equal(api.validateDeviceRecord_({ createdAt: now + 1, lastUsedAt: now + 1 }, now), "DEVICE_TIME_INVALID");
});

test("sensitive action quota fails closed after its limit", () => {
  const api = load();
  for (let i = 0; i < 6; i++) assert.equal(api.consumeActionQuota_("syncTemuanInspeksi", "device-a").success, true);
  const blocked = api.consumeActionQuota_("syncTemuanInspeksi", "device-a");
  assert.equal(blocked.success, false);
  assert.equal(blocked.kode, "ACTION_RATE_LIMIT");
  assert.equal(api.consumeActionQuota_("syncTemuanInspeksi", "device-b").success, true);
});

test("unknown actions do not consume a quota bucket", () => assert.equal(load().consumeActionQuota_("health", "x").success, true));

test("vegetation priority is derived server-side from finding identity", () => {
  const api = load();
  assert.equal(api.isVegetasiFinding_("Rabas / Pangkas"), true);
  assert.equal(api.isVegetasiFinding_("Tebang Sedang"), true);
  assert.equal(api.isVegetasiFinding_("Tebang Besar"), true);
  assert.equal(api.isVegetasiFinding_("Kabel Geser"), false);
  assert.equal(api.findingPriority_("Tebang Besar", "Minor", {
    "Jarak Terhadap Jaringan": 4,
    "Tinggi Pohon": 10,
  }), "Mayor");
  assert.match(source, /function findingPriority_\(/);
});
