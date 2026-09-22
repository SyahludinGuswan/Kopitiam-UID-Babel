"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const root = path.resolve(__dirname, "..");
const upload = fs.readFileSync(path.join(root, "IdempotentUpload.js"), "utf8");
const code = fs.readFileSync(path.join(root, "Code.js"), "utf8");

test("C4A no-WO idempotent contract is wired to Inp_Temuan", () => {
  for (const contract of [
    'TEMUAN_SHEET: "Inp_Temuan"',
    'syncTemuanInspeksiIdempotent_',
  ]) assert.ok((code + upload).includes(contract), contract);
  for (const contract of [
    'var isC4a = kodeWo === ""',
    'incoming["Kode WO"] = ""',
    'incoming["Jenis WO"] = ""',
    'function c4aContext_',
    'resolveFindingMaster_',
    'resolveFindingAsset_',
    'validateCoordinate_',
    'putPhotoIdempotent_',
    'photoIdempotencyKey_',
    'function buildC4aFindingPath_',
  ]) assert.ok(upload.includes(contract), contract);
});
