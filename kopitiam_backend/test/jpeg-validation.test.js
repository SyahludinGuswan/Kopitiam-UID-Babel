"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "..", "SecurityValidation.js"), "utf8");
const sandbox = {};
vm.createContext(sandbox);
vm.runInContext(source, sandbox, { filename: "SecurityValidation.js" });

function jpeg(extra = []) {
  const bytes = [0xff, 0xd8, 0xff, 0xc0, 0x00, 0x08, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0xff, 0xda, 0x00, 0x02, ...Array(1020).fill(0x11), 0xff, 0xd9];
  return Uint8Array.from(bytes.concat(extra));
}

test("accepts a structurally complete JPEG", () => {
  assert.equal(sandbox.validateJpegBytes_(jpeg()), true);
});

test("rejects valid signatures without a frame or scan", () => {
  assert.throws(() => sandbox.validateJpegBytes_(Uint8Array.from([0xff, 0xd8, ...Array(1020).fill(0x11), 0xff, 0xd9])), /Incomplete JPEG structure/);
});

test("rejects truncated segments and trailing bytes", () => {
  assert.throws(() => sandbox.validateJpegBytes_(jpeg().slice(0, -2)), /Truncated|Incomplete/);
  assert.throws(() => sandbox.validateJpegBytes_(jpeg([0x00])), /Trailing bytes/);
});

test("rejects embedded markers with invalid segment lengths", () => {
  const bad = jpeg();
  bad[4] = 0xff;
  bad[5] = 0xff;
  assert.throws(() => sandbox.validateJpegBytes_(bad), /Invalid JPEG segment length|Invalid JPEG frame header/);
});
