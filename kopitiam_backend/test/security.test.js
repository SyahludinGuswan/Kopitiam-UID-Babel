"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const code = read("Code.js");
const core = read("WorkOrderCore.js");
const upload = read("IdempotentUpload.js");
const production = [code, core, upload].join("\n");
const manifest = JSON.parse(read("appsscript.json"));

function loadBackend() {
  const properties = new Map();
  const propertyStore = { getProperty: (key) => properties.get(key) || null, setProperty: (key, value) => properties.set(key, String(value)), deleteProperty: (key) => properties.delete(key) };
  const sandbox = { console, PropertiesService: { getScriptProperties: () => propertyStore }, LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) }, Utilities: { Charset: { UTF_8: "utf8" }, DigestAlgorithm: { SHA_256: "sha256" }, getUuid: (() => { let value = 0; return () => `00000000-0000-4000-8000-${String(++value).padStart(12, "0")}`; })(), computeDigest(_algorithm, value) { return [...crypto.createHash("sha256").update(String(value)).digest()].map((byte) => (byte > 127 ? byte - 256 : byte)); } } };
  vm.createContext(sandbox); vm.runInContext(code, sandbox, { filename: "Code.js" });
  return { backend: sandbox, properties };
}

test("Apps Script source parses and exposes only health over GET", () => { assert.match(code, /function doGet\(e\)/); assert.match(code, /POST_REQUIRED/); assert.doesNotMatch(code, /e\.parameter\.(?:token|password|username)/); });
test("anonymous deployment executes as owner and routes protected work through POST", () => { assert.equal(manifest.webapp.executeAs, "USER_DEPLOYING"); assert.equal(manifest.webapp.access, "ANYONE_ANONYMOUS"); for (const action of ["getMasterData", "getWoInsjar", "syncWoInsjar", "getTemuanInspeksi", "syncTemuanInspeksi"]) assert.match(code, new RegExp('a === "' + action + '"')); });
test("authorization and ownership guards remain present", () => { assert.match(production, /WO_(?:ACCESS|OWNERSHIP)_DENIED/); assert.match(production, /WO_HEADERS_INVALID|WO_NOT_FOUND/); assert.match(production, /OBJECT_MISMATCH/); assert.match(code, /cekSesi_\(t\)/); });
test("operational backend has no password column, pepper, or password signature", () => { assert.doesNotMatch(code, /USER_COL\.password|PASSWORD_PEPPER|passwordSignature_|passwordPepper_/); assert.doesNotMatch(code, /passwordHash|passwordSalt/); });
test("operational profile schema excludes a password field", () => {
  const start = code.indexOf("function userFromRow_");
  const end = code.indexOf("\nfunction ", start + 1);
  assert.doesNotMatch(code.slice(start, end), /\bpassword\s*:/i);
});
test("payload and image limits remain enforced", () => { assert.match(code, /MAX_IMAGE_BYTES: 5 \* 1024 \* 1024/); assert.match(production, /rows\.length > 100/); assert.match(code, /e\.postData\.contents\.length > 15 \* 1024 \* 1024/); assert.match(production, /bytes\.length > CONFIG\.MAX_IMAGE_BYTES/); });
test("pure validators reject traversal, negative numbers, and oversized bodies", () => { const { backend } = loadBackend(); assert.throws(() => backend.safePath_(".."), /Invalid path/); assert.throws(() => backend.safePath_("."), /Invalid path/); assert.throws(() => backend.numericOrBlank_("-1"), /Invalid numeric value/); assert.equal(backend.numericOrBlank_("1,25"), 1.25); assert.throws(() => backend.parseBody_({ postData: { contents: "x".repeat(15 * 1024 * 1024 + 1) } }), /Payload too large/); });
test("constant-time comparison and code normalization behave predictably", () => { const { backend } = loadBackend(); assert.equal(backend.constantTimeEqual_("secret", "secret"), true); assert.equal(backend.constantTimeEqual_("secret", "Secret"), false); assert.equal(backend.constantTimeEqual_("short", "longer"), false); assert.equal(backend.normalizeCode_(" 001-abc "), "1ABC"); });
