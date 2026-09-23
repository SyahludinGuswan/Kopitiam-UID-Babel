"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const wo = fs.readFileSync(path.join(root, "WorkOrderCore.js"), "utf8");
const guard = fs.readFileSync(path.join(root, "ZZZZZZZZZZZZZZZZZZZZZZZZ_P2PhotoPipelineGuard.js"), "utf8");

test("P2 photo pipeline does not silently continue after WO upload failure", () => {
  assert.match(wo, /if \(!uploaded\) throw new Error\('PHOTO_UPLOAD_FAILED'\)/);
  assert.match(guard, /PHOTO_UPLOAD_FAILED/);
});

test("P2 preserves the Insdu voltage measurement contract", () => {
  assert.match(guard, /tegangan r-t \(v\) wbp/);
  assert.doesNotMatch(guard, /tegangan t-r \(v\) wbp/);
});
