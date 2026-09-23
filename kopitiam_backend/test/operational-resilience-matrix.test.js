'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const matrix = fs.readFileSync(path.join(__dirname, '../../docs/OPERATIONAL_RESILIENCE_MATRIX_2026-09-23.md'), 'utf8');
const faultInjection = fs.readFileSync(path.join(__dirname, 'operation-journal-fault-injection.test.js'), 'utf8');

test('operational resilience matrix is staging-only and excludes production', () => {
  assert.match(matrix, /staging-only plan and harness coverage/);
  assert.match(matrix, /No production spreadsheet, Drive folder, account, secret, or deployment/);
  assert.match(matrix, /Stop immediately if a staging identifier resolves to production/);
  assert.match(matrix, /S01/);
  assert.match(matrix, /S14/);
});

test('existing fault injection covers journal, Drive, Sheet, crash, and replay failures', () => {
  for (const marker of ['drive-upload', 'drive-read-back', 'sheet-write', 'sheet-flush', 'sheet-read-back', 'executor crash', 'committed replay']) {
    assert.match(faultInjection, new RegExp(marker.replace(/[.*+?^${}()|[\\]\\]/g, '\\\\$&'), 'i'));
  }
});
