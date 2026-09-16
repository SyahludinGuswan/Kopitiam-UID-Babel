/* REL-07 integrity guard: checksummed payload and receipt replay. */
function operationJournalSheet_() {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(OPERATION_JOURNAL_SHEET_);
  var required = OPERATION_JOURNAL_HEADERS_.concat([
    'Payload File ID', 'Payload File Digest', 'Lease Until', 'Lease Token',
    'Archived At', 'Receipt Digest'
  ]);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(OPERATION_JOURNAL_SHEET_);
    sheet.getRange(1, 1, 1, required.length).setValues([required]);
    try { sheet.setFrozenRows(1); } catch (_) {}
  }
  var width = Math.max(sheet.getLastColumn(), required.length);
  var headers = sheet.getRange(1, 1, 1, width).getDisplayValues()[0].map(function (value) { return String(value).trim(); });
  required.forEach(function (name) {
    if (headers.indexOf(name) < 0) { sheet.getRange(1, headers.length + 1).setValue(name); headers.push(name); }
  });
  SpreadsheetApp.flush();
  return { sheet: sheet, headers: headers, index: headerIndex_(headers) };
}

function opjLoadPayloadVerified_(record) {
  if (!record || !record['Payload File ID'] || !/^[a-f0-9]{64}$/i.test(String(record['Payload File Digest'] || ''))) throw new Error('Identitas atau checksum payload durable tidak tersedia.');
  var file = DriveApp.getFileById(String(record['Payload File ID'])), blob = file.getBlob();
  if (blob.getContentType() !== 'application/json') throw new Error('MIME payload jurnal tidak valid.');
  var raw = blob.getDataAsString('UTF-8');
  if (sha256_(raw) !== String(record['Payload File Digest']).toLowerCase()) throw new Error('Checksum payload durable tidak cocok.');
  var value = JSON.parse(raw);
  if (!value || typeof value !== 'object') throw new Error('Payload durable tidak valid.');
  return value;
}

function operationJournalPrepare_(identity, body) {
  var source, found, existing, lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    source = operationJournalSheet_(); found = operationJournalFind_(source, identity.operationId); existing = operationJournalObject_(source, found);
    if (existing) {
      if (normalize_(existing['Username']) !== identity.username || String(existing['Payload Digest']).toLowerCase() !== identity.payloadDigest) throw new Error('Operation ID tidak cocok dengan principal atau digest.');
      var state = normalize_(existing['State']);
      if (['committed', 'archived', 'purged'].indexOf(state) >= 0 && existing['Receipt JSON']) return existing;
      opjLoadPayloadVerified_(existing); return existing;
    }
  } finally { lock.releaseLock(); }
  var stored = opjStorePayloadOutsideLock_(identity, body);
  if (!stored || !stored.fileId || !/^[a-f0-9]{64}$/i.test(String(stored.digest || ''))) throw new Error('Snapshot durable gagal diverifikasi sebelum pencatatan jurnal.');
  lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    source = operationJournalSheet_(); found = operationJournalFind_(source, identity.operationId); existing = operationJournalObject_(source, found);
    if (existing) {
      if (stored.created && String(existing['Payload File ID']) !== stored.fileId) try { DriveApp.getFileById(stored.fileId).setTrashed(true); } catch (_) {}
      return existing;
    }
    var now = operationJournalNow_(), row = {
      'Operation ID': identity.operationId, 'Action': identity.action, 'Object ID': identity.objectId, 'Username': identity.username,
      'Payload Digest': identity.payloadDigest, 'State': 'prepared', 'Attempt Count': 0, 'First Prepared At': operationJournalIso_(now),
      'Last Attempt At': '', 'Committed At': '', 'Resolved At': '', 'Receipt JSON': '', 'Receipt Digest': '', 'Error Code': '',
      'Error Message': '', 'Next Reconciliation At': operationJournalIso_(now),
      'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_)),
      'Payload File ID': stored.fileId, 'Payload File Digest': String(stored.digest).toLowerCase(), 'Lease Until': '', 'Lease Token': '', 'Archived At': ''
    };
    source.sheet.appendRow(source.headers.map(function (header) { return row[header] === undefined ? '' : safeCell_(row[header]); }));
    SpreadsheetApp.flush();
    var created = operationJournalObject_(source, operationJournalFind_(source, identity.operationId));
    opjLoadPayloadVerified_(created); return created;
  } finally { lock.releaseLock(); }
}

function opjFinish_(operationId, leaseToken, result, verified) {
  var lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    var source = operationJournalSheet_(), found = operationJournalFind_(source, operationId);
    if (!found) throw new Error('Jurnal operasi tidak ditemukan.');
    var record = operationJournalObject_(source, found);
    if (record['Lease Token'] !== leaseToken || normalize_(record['State']) !== 'processing') throw new Error('Lease jurnal sudah berubah.');
    var now = operationJournalNow_();
    if (verified) {
      var receipt = JSON.stringify(result); if (receipt.length > 45000) throw new Error('Receipt terlalu besar untuk jurnal.');
      operationJournalWrite_(source, found.rowNumber, {
        'State': 'committed', 'Committed At': operationJournalIso_(now), 'Resolved At': operationJournalIso_(now),
        'Receipt JSON': receipt, 'Receipt Digest': sha256_(receipt), 'Error Code': '', 'Error Message': '', 'Next Reconciliation At': '',
        'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_COMMITTED_DAYS_)), 'Lease Until': '', 'Lease Token': ''
      });
    } else {
      operationJournalWrite_(source, found.rowNumber, {
        'State': 'needs-reconciliation', 'Error Code': String(result && result.kode || 'UNVERIFIED_RESULT').substring(0, 120),
        'Error Message': String(result && result.message || 'Hasil belum memiliki receipt final yang valid.').substring(0, 1000),
        'Next Reconciliation At': operationJournalIso_(new Date(now.getTime() + 15 * 60000)),
        'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_)), 'Lease Until': '', 'Lease Token': ''
      });
    }
  } finally { lock.releaseLock(); }
}

function operationJournalReplay_(record) {
  var state = normalize_(record && record['State']);
  if (!record || ['committed', 'archived', 'purged'].indexOf(state) < 0) return null;
  var raw = String(record['Receipt JSON'] || ''), digest = String(record['Receipt Digest'] || '').toLowerCase();
  if (!raw || !/^[a-f0-9]{64}$/.test(digest) || sha256_(raw) !== digest) return null;
  try {
    var receipt = JSON.parse(raw); if (!receipt || receipt.success !== true) return null;
    receipt.replayed = true; receipt.operationId = record['Operation ID']; receipt.journalState = state; return receipt;
  } catch (_) { return null; }
}

function opjFindingCommitReadBack_(result, identity) {
  if (!result || result.success !== true || !result.folderPath || !result.photoReceipts) return false;
  var source = operationJournalSheet_(), found = operationJournalFind_(source, identity.operationId);
  if (!found) return false;
  var journal = operationJournalObject_(source, found), payload = opjLoadPayloadVerified_(journal), expected = payload && payload.row;
  if (!expected || typeof expected !== 'object') return false;
  var code = String(expected['Kode Temuan'] || '').trim(); if (!code || code !== identity.objectId) return false;
  var sheet = temuanSheet_(), values = sheet.getDataRange().getDisplayValues(); if (values.length < 2) return false;
  var headers = values[0].map(function (value) { return String(value).trim(); }), index = headerIndex_(headers), matches = [];
  ['kode temuan', 'kode ulp', 'jenis object', 'folder path', 'link foto', 'link foto sekitaran tiang'].forEach(function (key) { if (index[key] === undefined) throw new Error('Header Temuan belum lengkap: ' + key); });
  for (var row = 1; row < values.length; row++) if (normalize_(values[row][index['kode temuan']]) === normalize_(code)) matches.push(values[row]);
  if (matches.length !== 1) return false;
  var actual = matches[0];
  if (normalizeCode_(actual[index['kode ulp']]) !== normalizeCode_(expected['Kode ULP']) || normalize_(actual[index['jenis object']]) !== normalize_(expected['Jenis Object']) || String(actual[index['folder path']] || '').trim() !== String(result.folderPath || '').trim()) return false;
  var primary = result.photoReceipts.fotoTemuan, environment = result.photoReceipts.fotoLingkungan;
  if (!primary || !environment || !primary.fileId || !environment.fileId || !primary.parentFolderId || !environment.parentFolderId) return false;
  if (String(actual[index['link foto']] || '').indexOf(primary.fileId) < 0 || String(actual[index['link foto sekitaran tiang']] || '').indexOf(environment.fileId) < 0) return false;
  var expectedProjection = opjFindingProjection_(expected, index), actualProjection = opjFindingActualProjection_(headers, actual, expectedProjection);
  result.expectedSheetDigest = opjProjectionDigest_(expectedProjection); result.sheetDigest = opjProjectionDigest_(actualProjection); result.payloadDigest = identity.payloadDigest;
  return Object.keys(expectedProjection).length > 0 && result.sheetDigest === result.expectedSheetDigest && result.payloadDigest === identity.payloadDigest;
}

function operationJournalReconcileUser_(session, token, limit) {
  var username = normalize_(session && session.username), source = operationJournalSheet_();
  if (!username || !token) return { success: false, processed: 0 };
  var last = source.sheet.getLastRow(); if (last < 2) return { success: true, processed: 0 };
  var values = source.sheet.getRange(2, 1, last - 1, source.headers.length).getDisplayValues();
  var now = operationJournalNow_(), processed = 0, maximum = Math.max(1, Math.min(Number(limit || 1), 5));
  for (var i = 0; i < values.length && processed < maximum; i++) {
    var record = {}; source.headers.forEach(function (header, column) { record[header] = values[i][column]; });
    var state = normalize_(record['State']), due = Date.parse(record['Next Reconciliation At'] || '');
    if (normalize_(record['Username']) !== username || (state !== 'prepared' && state !== 'needs-reconciliation') || (isFinite(due) && due > now.getTime())) continue;
    var claim = opjClaim_(record['Operation ID']); if (!claim || claim.busy || claim.committed || !claim.token) continue;
    var result;
    try { result = opjExecuteStored_(record['Action'], opjLoadPayloadVerified_(record), token); }
    catch (error) { result = fail_('RECONCILIATION_FAILED', String(error && error.message || error)); }
    var identity = { operationId: record['Operation ID'], objectId: record['Object ID'], payloadDigest: String(record['Payload Digest']).toLowerCase() };
    var verified = opjVerifiedSuccess_(record['Action'], result, identity);
    if (result && result.success === true && !verified) result = fail_('OPERATION_RECEIPT_INVALID', 'Hasil rekonsiliasi tidak memiliki receipt final yang valid.');
    opjFinish_(record['Operation ID'], claim.token, result, verified); processed++;
  }
  return { success: true, processed: processed };
}
