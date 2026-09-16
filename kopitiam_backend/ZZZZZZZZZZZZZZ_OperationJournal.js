/* REL-07: durable journal across non-atomic Sheet and Drive operations. */
var OPERATION_JOURNAL_SHEET_ = 'Operation_Journal';
var OPERATION_JOURNAL_HEADERS_ = [
  'Operation ID', 'Action', 'Object ID', 'Username', 'Payload Digest',
  'State', 'Attempt Count', 'First Prepared At', 'Last Attempt At',
  'Committed At', 'Resolved At', 'Receipt JSON', 'Error Code',
  'Error Message', 'Next Reconciliation At', 'Archive After'
];
var OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_ = 90;
var OPERATION_JOURNAL_COMMITTED_DAYS_ = 30;
var OPERATION_JOURNAL_ARCHIVE_DAYS_ = 365;

function operationJournalNow_() { return new Date(); }
function operationJournalIso_(value) { return value ? new Date(value).toISOString() : ''; }
function operationJournalAddDays_(date, days) { return new Date(date.getTime() + days * 86400000); }

function operationJournalSheet_() {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(OPERATION_JOURNAL_SHEET_);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(OPERATION_JOURNAL_SHEET_);
    sheet.getRange(1, 1, 1, OPERATION_JOURNAL_HEADERS_.length).setValues([OPERATION_JOURNAL_HEADERS_]);
    try { sheet.setFrozenRows(1); } catch (_) {}
  }
  var headers = sheet.getRange(1, 1, 1, Math.max(sheet.getLastColumn(), OPERATION_JOURNAL_HEADERS_.length)).getDisplayValues()[0];
  var normalized = headers.map(function (value) { return String(value).trim(); });
  OPERATION_JOURNAL_HEADERS_.forEach(function (required) {
    if (normalized.indexOf(required) < 0) throw new Error('Kolom jurnal hilang: ' + required);
  });
  return { sheet: sheet, headers: normalized, index: headerIndex_(normalized) };
}

function operationJournalIdentity_(action, body, session) {
  var row = body && Array.isArray(body.rows) && body.rows.length === 1 ? body.rows[0] : body && body.row;
  if (!row || typeof row !== 'object') throw new Error('Jurnal hanya menerima satu objek per operasi.');
  var objectId = String(row['Kode WO'] || row['Kode Temuan'] || '').trim();
  if (!objectId) throw new Error('Identitas objek jurnal kosong.');
  var digest = String(row.clientPayloadDigest || '').trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(digest)) {
    var photoA = row.fotoTemuanBase64 ? digestBytes_(Utilities.base64Decode(String(row.fotoTemuanBase64))) : '';
    var photoB = row.fotoLingkunganBase64 ? digestBytes_(Utilities.base64Decode(String(row.fotoLingkunganBase64))) : '';
    var copy = {};
    Object.keys(row).sort().forEach(function (key) {
      if (key === 'fotoTemuanBase64' || key === 'fotoLingkunganBase64' || key === 'fotoSesudahBase64') return;
      copy[key] = row[key];
    });
    digest = sha256_(JSON.stringify(copy) + '|' + photoA + '|' + photoB);
  }
  var username = normalize_(session && session.username);
  if (!username) throw new Error('Username live wajib tersedia untuk jurnal.');
  return {
    action: action,
    objectId: objectId,
    username: username,
    payloadDigest: digest,
    operationId: sha256_([username, action, objectId, digest].join('|'))
  };
}

function operationJournalFind_(source, operationId) {
  var column = source.index['operation id'];
  var values = source.sheet.getDataRange().getDisplayValues();
  var matches = [];
  for (var row = 1; row < values.length; row++) {
    if (String(values[row][column] || '').trim() === operationId) matches.push({ rowNumber: row + 1, values: values[row] });
  }
  if (matches.length > 1) throw new Error('Operation ID jurnal duplikat.');
  return matches.length ? matches[0] : null;
}

function operationJournalObject_(source, found) {
  if (!found) return null;
  var result = {};
  source.headers.forEach(function (header, index) { result[header] = found.values[index]; });
  result.rowNumber = found.rowNumber;
  return result;
}

function operationJournalWrite_(source, rowNumber, values) {
  Object.keys(values).forEach(function (header) {
    var column = source.index[normalize_(header)];
    if (column === undefined) throw new Error('Kolom jurnal tidak tersedia: ' + header);
    source.sheet.getRange(rowNumber, column + 1).setValue(safeCell_(values[header]));
  });
  SpreadsheetApp.flush();
}

function operationJournalPrepare_(identity) {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var source = operationJournalSheet_();
    var found = operationJournalFind_(source, identity.operationId);
    var existing = operationJournalObject_(source, found);
    if (existing) {
      if (normalize_(existing['Username']) !== identity.username || String(existing['Payload Digest']).toLowerCase() !== identity.payloadDigest) {
        throw new Error('Operation ID tidak cocok dengan principal atau digest.');
      }
      return existing;
    }
    var now = operationJournalNow_();
    var row = {
      'Operation ID': identity.operationId, 'Action': identity.action,
      'Object ID': identity.objectId, 'Username': identity.username,
      'Payload Digest': identity.payloadDigest, 'State': 'prepared',
      'Attempt Count': 0, 'First Prepared At': operationJournalIso_(now),
      'Last Attempt At': '', 'Committed At': '', 'Resolved At': '',
      'Receipt JSON': '', 'Error Code': '', 'Error Message': '',
      'Next Reconciliation At': operationJournalIso_(now),
      'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_))
    };
    var output = source.headers.map(function (header) { return row[header] === undefined ? '' : safeCell_(row[header]); });
    source.sheet.appendRow(output);
    SpreadsheetApp.flush();
    return operationJournalObject_(source, operationJournalFind_(source, identity.operationId));
  } finally { lock.releaseLock(); }
}

function operationJournalMarkAttempt_(operationId) {
  var lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    var source = operationJournalSheet_(), found = operationJournalFind_(source, operationId);
    if (!found) throw new Error('Jurnal operasi tidak ditemukan.');
    var record = operationJournalObject_(source, found);
    operationJournalWrite_(source, found.rowNumber, {
      'Attempt Count': Number(record['Attempt Count'] || 0) + 1,
      'Last Attempt At': operationJournalIso_(operationJournalNow_()),
      'State': normalize_(record['State']) === 'committed' ? 'committed' : 'prepared'
    });
  } finally { lock.releaseLock(); }
}

function operationJournalMarkResult_(operationId, result) {
  var lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    var source = operationJournalSheet_(), found = operationJournalFind_(source, operationId);
    if (!found) throw new Error('Jurnal operasi tidak ditemukan.');
    var now = operationJournalNow_();
    if (result && result.success === true) {
      var receipt = JSON.stringify(result);
      if (receipt.length > 45000) throw new Error('Receipt terlalu besar untuk jurnal.');
      operationJournalWrite_(source, found.rowNumber, {
        'State': 'committed', 'Committed At': operationJournalIso_(now),
        'Resolved At': operationJournalIso_(now), 'Receipt JSON': receipt,
        'Error Code': '', 'Error Message': '', 'Next Reconciliation At': '',
        'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_COMMITTED_DAYS_))
      });
    } else {
      operationJournalWrite_(source, found.rowNumber, {
        'State': 'needs-reconciliation',
        'Error Code': String(result && result.kode || 'OPERATION_FAILED').substring(0, 120),
        'Error Message': String(result && result.message || 'Operasi gagal tanpa receipt committed.').substring(0, 1000),
        'Next Reconciliation At': operationJournalIso_(new Date(now.getTime() + 15 * 60000)),
        'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_))
      });
    }
  } finally { lock.releaseLock(); }
}

function operationJournalReplay_(record) {
  if (!record || normalize_(record['State']) !== 'committed' || !record['Receipt JSON']) return null;
  try {
    var receipt = JSON.parse(record['Receipt JSON']);
    receipt.replayed = true;
    receipt.operationId = record['Operation ID'];
    return receipt;
  } catch (_) { return null; }
}

function operationJournalRun_(action, body, session, executor) {
  var identity;
  try { identity = operationJournalIdentity_(action, body, session); }
  catch (error) { return fail_('OPERATION_JOURNAL_INVALID', error.message); }
  var record;
  try { record = operationJournalPrepare_(identity); }
  catch (error) { return fail_('OPERATION_JOURNAL_UNAVAILABLE', error.message); }
  var replay = operationJournalReplay_(record);
  if (replay) return replay;
  try {
    operationJournalMarkAttempt_(identity.operationId);
    var result = executor();
    operationJournalMarkResult_(identity.operationId, result);
    if (result && typeof result === 'object') result.operationId = identity.operationId;
    return result;
  } catch (error) {
    var failure = fail_('OPERATION_INTERRUPTED', String(error && error.message || error || 'Operasi terputus.'));
    try { operationJournalMarkResult_(identity.operationId, failure); } catch (_) {}
    return failure;
  }
}

function operationJournalPending_() {
  var source = operationJournalSheet_(), values = source.sheet.getDataRange().getDisplayValues(), rows = [];
  for (var i = 1; i < values.length; i++) {
    var state = normalize_(values[i][source.index.state]);
    if (state !== 'prepared' && state !== 'needs-reconciliation') continue;
    var item = {};
    source.headers.forEach(function (header, index) { item[header] = values[i][index]; });
    rows.push(item);
  }
  return rows;
}
