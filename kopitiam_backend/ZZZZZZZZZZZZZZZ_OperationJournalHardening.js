/* REL-07 hardening: durable payload, exclusive lease, verified commit, indexed lookup. */
var OPJ_PROCESSING_LEASE_MS_ = 10 * 60 * 1000;
var OPJ_PAYLOAD_FOLDER_ = '_operation_inbox';

function opjColumn_(source, name) {
  var index = source.index[normalize_(name)];
  if (index === undefined) throw new Error('Kolom jurnal tidak tersedia: ' + name);
  return index;
}

function operationJournalSheet_() {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(OPERATION_JOURNAL_SHEET_);
  var required = OPERATION_JOURNAL_HEADERS_.concat([
    'Payload File ID', 'Lease Until', 'Lease Token', 'Archived At'
  ]);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(OPERATION_JOURNAL_SHEET_);
    sheet.getRange(1, 1, 1, required.length).setValues([required]);
    try { sheet.setFrozenRows(1); } catch (_) {}
  }
  var width = Math.max(sheet.getLastColumn(), required.length);
  var headers = sheet.getRange(1, 1, 1, width).getDisplayValues()[0].map(function (value) { return String(value).trim(); });
  required.forEach(function (name) {
    if (headers.indexOf(name) < 0) {
      sheet.getRange(1, headers.length + 1).setValue(name);
      headers.push(name);
    }
  });
  SpreadsheetApp.flush();
  return { sheet: sheet, headers: headers, index: headerIndex_(headers) };
}

function operationJournalFind_(source, operationId) {
  var last = source.sheet.getLastRow();
  if (last < 2) return null;
  var column = opjColumn_(source, 'Operation ID') + 1;
  var matches = source.sheet.getRange(2, column, last - 1, 1)
    .createTextFinder(operationId).matchEntireCell(true).findAll();
  if (matches.length > 1) throw new Error('Operation ID jurnal duplikat.');
  if (!matches.length) return null;
  var rowNumber = matches[0].getRow();
  return { rowNumber: rowNumber, values: source.sheet.getRange(rowNumber, 1, 1, source.headers.length).getDisplayValues()[0] };
}

function opjPayloadFolder_() {
  var root = evidenceRootFolder_();
  var matches = root.getFoldersByName(OPJ_PAYLOAD_FOLDER_);
  var folder = matches.hasNext() ? matches.next() : root.createFolder(OPJ_PAYLOAD_FOLDER_);
  if (matches.hasNext()) throw new Error('Folder durable inbox duplikat.');
  return folder;
}

function opjStorePayload_(identity, body) {
  var folder = opjPayloadFolder_();
  var filename = 'operation.' + identity.operationId + '.json';
  var matches = folder.getFilesByName(filename);
  if (matches.hasNext()) {
    var existing = matches.next();
    var raw = existing.getBlob().getDataAsString('UTF-8');
    if (sha256_(raw) !== sha256_(JSON.stringify(body))) throw new Error('Payload durable tidak cocok untuk operation ID yang sama.');
    return existing.getId();
  }
  var json = JSON.stringify(body);
  if (json.length > 15 * 1024 * 1024) throw new Error('Payload jurnal melampaui batas.');
  return folder.createFile(Utilities.newBlob(json, 'application/json', filename)).getId();
}

function opjLoadPayload_(fileId) {
  var file = DriveApp.getFileById(String(fileId || ''));
  var blob = file.getBlob();
  if (blob.getContentType() !== 'application/json') throw new Error('MIME payload jurnal tidak valid.');
  return JSON.parse(blob.getDataAsString('UTF-8'));
}

function operationJournalPrepare_(identity, body) {
  var lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    var source = operationJournalSheet_();
    var found = operationJournalFind_(source, identity.operationId);
    var existing = operationJournalObject_(source, found);
    if (existing) {
      if (normalize_(existing['Username']) !== identity.username || String(existing['Payload Digest']).toLowerCase() !== identity.payloadDigest) throw new Error('Operation ID tidak cocok dengan principal atau digest.');
      if (!existing['Payload File ID']) throw new Error('Snapshot durable operasi tidak tersedia.');
      return existing;
    }
    var now = operationJournalNow_();
    var payloadFileId = opjStorePayload_(identity, body);
    var row = {
      'Operation ID': identity.operationId, 'Action': identity.action, 'Object ID': identity.objectId,
      'Username': identity.username, 'Payload Digest': identity.payloadDigest, 'State': 'prepared',
      'Attempt Count': 0, 'First Prepared At': operationJournalIso_(now), 'Last Attempt At': '',
      'Committed At': '', 'Resolved At': '', 'Receipt JSON': '', 'Error Code': '',
      'Error Message': '', 'Next Reconciliation At': operationJournalIso_(now),
      'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_)),
      'Payload File ID': payloadFileId, 'Lease Until': '', 'Lease Token': '', 'Archived At': ''
    };
    source.sheet.appendRow(source.headers.map(function (header) { return row[header] === undefined ? '' : safeCell_(row[header]); }));
    SpreadsheetApp.flush();
    return operationJournalObject_(source, operationJournalFind_(source, identity.operationId));
  } finally { lock.releaseLock(); }
}

function opjClaim_(operationId) {
  var lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    var source = operationJournalSheet_(), found = operationJournalFind_(source, operationId);
    if (!found) throw new Error('Jurnal operasi tidak ditemukan.');
    var record = operationJournalObject_(source, found), now = operationJournalNow_();
    if (normalize_(record['State']) === 'committed') return { committed: true, record: record };
    var lease = Date.parse(record['Lease Until'] || '');
    if (normalize_(record['State']) === 'processing' && isFinite(lease) && lease > now.getTime()) return { busy: true };
    var token = Utilities.getUuid();
    operationJournalWrite_(source, found.rowNumber, {
      'State': 'processing', 'Lease Token': token,
      'Lease Until': operationJournalIso_(new Date(now.getTime() + OPJ_PROCESSING_LEASE_MS_)),
      'Attempt Count': Number(record['Attempt Count'] || 0) + 1,
      'Last Attempt At': operationJournalIso_(now)
    });
    return { token: token, record: operationJournalObject_(source, operationJournalFind_(source, operationId)) };
  } finally { lock.releaseLock(); }
}

function opjVerifiedSuccess_(action, result, identity) {
  if (!result || result.success !== true) return false;
  if (action === 'syncTemuanInspeksi') {
    var photos = result.photoReceipts;
    return !!(result.folderPath && photos && photos.fotoTemuan && photos.fotoTemuan.fileId && photos.fotoTemuan.parentFolderId && photos.fotoLingkungan && photos.fotoLingkungan.fileId && photos.fotoLingkungan.parentFolderId);
  }
  if (!Array.isArray(result.receipts) || result.receipts.length !== 1) return false;
  var receipt = result.receipts[0];
  return !!(receipt && receipt.committed === true && String(receipt.kodeWo || '').trim() === identity.objectId && String(receipt.payloadDigest || '').toLowerCase() === identity.payloadDigest);
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
      var receipt = JSON.stringify(result);
      if (receipt.length > 45000) throw new Error('Receipt terlalu besar untuk jurnal.');
      operationJournalWrite_(source, found.rowNumber, {
        'State': 'committed', 'Committed At': operationJournalIso_(now), 'Resolved At': operationJournalIso_(now),
        'Receipt JSON': receipt, 'Error Code': '', 'Error Message': '', 'Next Reconciliation At': '',
        'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_COMMITTED_DAYS_)),
        'Lease Until': '', 'Lease Token': ''
      });
    } else {
      operationJournalWrite_(source, found.rowNumber, {
        'State': 'needs-reconciliation', 'Error Code': String(result && result.kode || 'UNVERIFIED_RESULT').substring(0, 120),
        'Error Message': String(result && result.message || 'Hasil belum memiliki receipt final yang valid.').substring(0, 1000),
        'Next Reconciliation At': operationJournalIso_(new Date(now.getTime() + 15 * 60000)),
        'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_)),
        'Lease Until': '', 'Lease Token': ''
      });
    }
  } finally { lock.releaseLock(); }
}

function operationJournalRun_(action, body, session, executor) {
  var identity;
  try { identity = operationJournalIdentity_(action, body, session); }
  catch (error) { return fail_('OPERATION_JOURNAL_INVALID', error.message); }
  var record;
  try { record = operationJournalPrepare_(identity, body); }
  catch (error) { return fail_('OPERATION_JOURNAL_UNAVAILABLE', error.message); }
  var replay = operationJournalReplay_(record); if (replay) return replay;
  var claim;
  try { claim = opjClaim_(identity.operationId); }
  catch (error) { return fail_('OPERATION_JOURNAL_UNAVAILABLE', error.message); }
  if (claim.busy) return fail_('OPERATION_IN_PROGRESS', 'Operasi yang sama sedang diproses.');
  if (claim.committed) return operationJournalReplay_(claim.record) || fail_('OPERATION_RECEIPT_INVALID', 'Receipt committed tidak dapat dibaca.');
  var result;
  try { result = executor(); }
  catch (error) { result = fail_('OPERATION_INTERRUPTED', String(error && error.message || error || 'Operasi terputus.')); }
  var verified = opjVerifiedSuccess_(action, result, identity);
  if (result && result.success === true && !verified) result = fail_('OPERATION_RECEIPT_INVALID', 'Respons sukses tidak memiliki receipt final yang valid.');
  try { opjFinish_(identity.operationId, claim.token, result, verified); }
  catch (error) { return fail_('OPERATION_JOURNAL_UNAVAILABLE', error.message); }
  if (result && typeof result === 'object') result.operationId = identity.operationId;
  return result;
}

function operationJournalArchive_() {
  var source = operationJournalSheet_(), last = source.sheet.getLastRow();
  if (last < 2) return { success: true, archived: 0 };
  var values = source.sheet.getRange(2, 1, last - 1, source.headers.length).getDisplayValues();
  var now = operationJournalNow_(), archived = 0;
  for (var i = 0; i < values.length; i++) {
    var state = normalize_(values[i][opjColumn_(source, 'State')]);
    var due = Date.parse(values[i][opjColumn_(source, 'Archive After')] || '');
    if ((state !== 'committed' && state !== 'resolved') || !isFinite(due) || due > now.getTime()) continue;
    operationJournalWrite_(source, i + 2, { 'State': 'archived', 'Archived At': operationJournalIso_(now), 'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ARCHIVE_DAYS_)) });
    archived++;
  }
  return { success: true, archived: archived };
}
