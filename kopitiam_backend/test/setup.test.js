"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.resolve(__dirname, "..", "Setup.js"),
  "utf8",
);

const manifest = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, "..", "appsscript.json"), "utf8"),
);

test(
  "manifest relies on the Apps Script auto-inferred scopes (no oauthScopes)",
  () => {
    // Menyebut scopes secara eksplisit (mis. Drive + Spreadsheets tanpa
    // script.scriptapp) menyebabkan setup dari editor gagal dengan
    // "Specified permissions are not sufficient to call ...".
    const scopes = manifest.oauthScopes;
    assert.ok(
      scopes === undefined || scopes === null,
      "oauthScopes must not be manually declared; let Apps Script infer them",
    );
  },
);

function loadSetup(records = {}, now = Date.now()) {
  const properties = new Map(Object.entries(records));
  let locks = 0;
  let unlocks = 0;
  const sandbox = {
    console,
    Date: class extends Date {
      static now() {
        return now;
      }
    },
    Object,
    PropertiesService: {
      getScriptProperties: () => ({
        getProperties: () => Object.fromEntries(properties),
        getProperty: (key) => properties.get(key) || null,
        setProperty: (key, value) => properties.set(key, String(value)),
        deleteProperty: (key) => properties.delete(key),
      }),
    },
    LockService: {
      getScriptLock: () => ({
        waitLock() {
          locks++;
        },
        releaseLock() {
          unlocks++;
        },
      }),
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, { filename: "Setup.js" });
  return { backend: sandbox, properties, lockCounts: () => [locks, unlocks] };
}

function mockSetupSheet(name, rows = []) {
  const data = rows.map((row) => Array.from(row));
  const mutations = [];
  return {
    data,
    mutations,
    getName: () => name,
    getLastRow: () => data.length,
    getLastColumn: () => Math.max(0, ...data.map((row) => row.length)),
    setFrozenRows(count) {
      mutations.push({ operation: "setFrozenRows", count });
    },
    getRange(row, column, numRows, numColumns) {
      assert.ok(row > 0 && column > 0 && numRows > 0 && numColumns > 0);
      return {
        getDisplayValues() {
          return Array.from({ length: numRows }, (_, r) =>
            Array.from({ length: numColumns }, (_, c) =>
              String(data[row - 1 + r]?.[column - 1 + c] ?? ""),
            ),
          );
        },
        setValues(values) {
          assert.equal(values.length, numRows);
          for (let r = 0; r < numRows; r++) {
            assert.equal(values[r].length, numColumns);
            const target = (data[row - 1 + r] ??= []);
            for (let c = 0; c < numColumns; c++) {
              target[column - 1 + c] = values[r][c];
            }
          }
          mutations.push({ operation: "setValues", row, column, numRows, numColumns });
        },
        setFontWeight(weight) {
          mutations.push({ operation: "setFontWeight", weight });
        },
      };
    },
  };
}

function loadBackendSetup() {
  const loaded = loadSetup({ device_corrupt: "{bad-json" });
  const { backend } = loaded;
  const root = path.resolve(__dirname, "..");
  // Muat source GAS asli, bukan stub setup/validator/header helper.
  for (const file of fs.readdirSync(root).filter((name) => /\.(js|gs)$/.test(name)).sort()) {
    vm.runInContext(fs.readFileSync(path.join(root, file), "utf8"), backend, { filename: file });
  }
  backend.configureHarMaterialSheet_();
  const headers = Array.from(backend.temuanSheetHeaders_());
  const config = backend.CONFIG;
  const sheets = new Map();
  const insertions = [];
  const opened = [];
  const triggers = [];
  let driveCalls = 0;
  for (const id of [config.SPREADSHEET_ID, config.WO_SPREADSHEET_ID, config.TEMUAN_SPREADSHEET_ID]) {
    sheets.set(id, new Map());
  }
  const userHeaders = [
    "No", "Kode UIW", "Kode UP3", "Kode ULP", "ULP", "Username",
    "Role", "Bidang", "Tim", "Sub-Tim", "Akses Menu",
  ];
  sheets.get(config.SPREADSHEET_ID).set(config.USERS_SHEET,
    mockSetupSheet(config.USERS_SHEET, [userHeaders, userHeaders.map((_, i) => `user-${i}`)]));
  const woSheets = sheets.get(config.WO_SPREADSHEET_ID);
  for (const name of [config.WO_INSJAR_SHEET, config.WO_ROW_SHEET, config.WO_HAR_JAR_SHEET]) {
    woSheets.set(name, mockSetupSheet(name, [
      ["Kode WO", "Kode ULP", "Status WO", "Tim Eksekusi"],
      ["WO-TEST", "ULP-TEST", "Open", "Tim-TEST"],
    ]));
  }
  woSheets.set(config.MATERIAL_HAR_JAR_SHEET, mockSetupSheet(config.MATERIAL_HAR_JAR_SHEET, [
    Array.from(backend.HAR_MATERIAL_SETUP_HEADERS_),
    Array.from(backend.HAR_MATERIAL_SETUP_HEADERS_, (_, i) => `material-${i}`),
  ]));
  backend.SpreadsheetApp = {
    openById(id) {
      assert.ok(sheets.has(id), "setup must open a configured spreadsheet");
      opened.push(id);
      const entries = sheets.get(id);
      return {
        getSheetByName: (name) => entries.get(name) || null,
        insertSheet(name) {
          assert.equal(entries.has(name), false);
          const sheet = mockSetupSheet(name);
          entries.set(name, sheet);
          insertions.push({ id, name });
          return sheet;
        },
      };
    },
  };
  backend.DriveApp = { getRootFolder: () => { driveCalls++; return {}; } };
  backend.ScriptApp = {
    getProjectTriggers: () => triggers,
    newTrigger(handler) {
      return {
        timeBased() { return this; },
        everyHours(hours) { assert.equal(hours, 1); return this; },
        create() { triggers.push({ getHandlerFunction: () => handler }); },
      };
    },
  };
  const snapshot = () => JSON.stringify([...sheets].map(([id, entries]) =>
    [id, [...entries].map(([name, sheet]) => [name, sheet.data, sheet.mutations])],
  ));
  return {
    ...loaded, headers, sheets, insertions, opened, triggers, snapshot,
    temuanSheets: sheets.get(config.TEMUAN_SPREADSHEET_ID),
    driveCalls: () => driveCalls,
  };
}

for (const state of ["missing", "empty"]) {
  test(`setupBackend initializes ${state} Inp_Temuan and reruns without rewriting data`, () => {
    const env = loadBackendSetup();
    const { backend, headers, temuanSheets } = env;
    assert.equal(backend.CONFIG.TEMUAN_SHEET, "Inp_Temuan");
    assert.equal(headers.length, 34);
    assert.equal(vm.runInContext("typeof TEMUAN_SHEET_HEADERS", backend), "undefined");
    if (state === "empty") temuanSheets.set("Inp_Temuan", mockSetupSheet("Inp_Temuan"));

    const result = backend.setupBackend();
    assert.equal(result.success, true);
    assert.equal(result.expiredTokensRemoved, 1);
    assert.deepEqual([...temuanSheets.keys()], ["Inp_Temuan"]);
    const sheet = temuanSheets.get("Inp_Temuan");
    assert.deepEqual(sheet.data, [headers]);
    assert.deepEqual(sheet.mutations, [
      { operation: "setValues", row: 1, column: 1, numRows: 1, numColumns: 34 },
      { operation: "setFrozenRows", count: 1 },
      { operation: "setFontWeight", weight: "bold" },
    ]);
    assert.deepEqual(env.insertions, state === "missing"
      ? [{ id: backend.CONFIG.TEMUAN_SPREADSHEET_ID, name: "Inp_Temuan" }] : []);
    for (const [id, entries] of env.sheets) {
      if (id === backend.CONFIG.TEMUAN_SPREADSHEET_ID) continue;
      for (const other of entries.values()) assert.deepEqual(other.mutations, []);
    }

    const beforeRerun = env.snapshot();
    assert.equal(backend.setupBackend().expiredTokensRemoved, 0);
    assert.equal(env.snapshot(), beforeRerun);
    assert.equal(env.triggers.length, 1);
    assert.equal(env.triggers[0].getHandlerFunction(), backend.DEVICE_CLEANUP_HANDLER);
    assert.deepEqual(env.lockCounts(), [2, 2]);
    assert.equal(env.driveCalls(), 2);
    assert.deepEqual(env.opened, [
      backend.CONFIG.SPREADSHEET_ID, backend.CONFIG.WO_SPREADSHEET_ID, backend.CONFIG.TEMUAN_SPREADSHEET_ID,
      backend.CONFIG.SPREADSHEET_ID, backend.CONFIG.WO_SPREADSHEET_ID, backend.CONFIG.TEMUAN_SPREADSHEET_ID,
    ]);
  });
}

test("setupBackend preserves existing rows, formulas, reordered headers and extra columns", () => {
  const env = loadBackendSetup();
  const headers = env.headers.slice().reverse().map((header) => ` ${header.toLowerCase()} `);
  headers.push("Kolom tambahan");
  const rows = [headers, headers.map((_, i) => `existing-${i}`), headers.map(() => "")];
  rows[1][headers.length - 1] = "=SUM(1,2)";
  rows[2][0] = 0;
  env.temuanSheets.set("Inp_Temuan", mockSetupSheet("Inp_Temuan", rows));
  const before = env.snapshot();
  assert.equal(env.backend.setupBackend().success, true);
  assert.equal(env.backend.setupBackend().success, true);
  assert.equal(env.snapshot(), before);
  assert.deepEqual(env.insertions, []);
  assert.equal(env.triggers.length, 1);
});

test("setupBackend rejects incomplete existing headers without overwriting any sheet", () => {
  const env = loadBackendSetup();
  const headers = env.headers.filter((header) => header !== "Kode Temuan");
  env.temuanSheets.set("Inp_Temuan", mockSetupSheet("Inp_Temuan", [
    headers, headers.map(() => "keep-existing"),
  ]));
  const before = env.snapshot();
  assert.throws(() => env.backend.setupBackend(), /Header sheet Inp_Temuan tidak lengkap: Kode Temuan/);
  assert.equal(env.snapshot(), before);
  assert.deepEqual(env.insertions, []);
  assert.equal(env.triggers.length, 0);
  assert.deepEqual(env.lockCounts(), [0, 0]);
});

test("setup matches the password-free operational schema", () => {
  assert.match(source, /CONFIG\.SPREADSHEET_ID/);
  assert.match(source, /CONFIG\.WO_SPREADSHEET_ID/);
  assert.match(source, /CONFIG\.TEMUAN_SPREADSHEET_ID/);
  assert.match(source, /"Kode UIW"[\s\S]*"Akses Menu"/);
  assert.doesNotMatch(source, /"Password"/);
  assert.doesNotMatch(source, /CONFIG\.SESSIONS_SHEET/);
  assert.doesNotMatch(source, /hashPassword_|getSheet_/);
});

test("device policy is 7 days absolute and 1 day idle", () => {
  assert.match(source, /DEVICE_TOKEN_MAX_AGE_MS = 7 \* 24 \* 60 \* 60 \* 1000/);
  assert.match(source, /DEVICE_TOKEN_IDLE_MS = 1 \* 24 \* 60 \* 60 \* 1000/);
  assert.match(source, /everyHours\(1\)/);
});

test("server cleanup removes expired, idle, future, and corrupt device tokens", () => {
  const day = 24 * 60 * 60 * 1000;
  const now = Date.UTC(2026, 7, 28, 3, 0, 0);
  const records = {
    device_active: JSON.stringify({
      createdAt: now - day,
      lastUsedAt: now - 1000,
    }),
    device_expired: JSON.stringify({
      createdAt: now - 7 * day,
      lastUsedAt: now - 1000,
    }),
    device_idle: JSON.stringify({
      createdAt: now - 2 * day,
      lastUsedAt: now - day,
    }),
    device_future: JSON.stringify({
      createdAt: now + day,
      lastUsedAt: now + day,
    }),
    device_corrupt: "{bad-json",
  };
  const { backend, properties, lockCounts } = loadSetup(records, now);
  const result = backend.bersihkanTokenPerangkatKedaluwarsa();
  assert.equal(result.success, true);
  assert.equal(result.dihapus, 4);
  assert.equal(result.aktif, 1);
  assert.ok(properties.has("device_active"));
  assert.equal(properties.has("device_expired"), false);
  assert.equal(properties.has("device_idle"), false);
  assert.equal(properties.has("device_future"), false);
  assert.equal(properties.has("device_corrupt"), false);
  assert.deepEqual(lockCounts(), [1, 1]);
});

test(
  "setup touches DriveApp so the editor re-authorizes Drive after manifest scope changes",
  () => {
    assert.match(source, /DriveApp\.getRootFolder\(\)/);
  },
);

test("cleanup ignores unrelated Script Properties", () => {
  const now = Date.UTC(2026, 7, 28, 3, 0, 0);
  const { backend, properties } = loadSetup({ OTHER_CONFIG: "value" }, now);
  const result = backend.bersihkanTokenPerangkatKedaluwarsa();
  assert.equal(result.dihapus, 0);
  assert.equal(properties.get("OTHER_CONFIG"), "value");
});
