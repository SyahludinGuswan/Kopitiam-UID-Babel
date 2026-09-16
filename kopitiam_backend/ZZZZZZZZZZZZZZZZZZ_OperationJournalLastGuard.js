/* REL-07 last guard: compare the Temuan snapshot and preserve terminal replay. */
var OPJ_FINDING_TRANSPORT_KEYS_ = {
  'fototemuanbase64': true,
  'fotolingkunganbase64': true,
  'clientpayloaddigest': true,
  'clientphotodigest': true,
  'folder path': true,
  'foto temuan': true,
  'link foto': true,
  'foto lingkungan sekitaran tiang': true,
  'link foto sekitaran tiang': true,
  'user input': true
};

function opjFindingProjection_(source, index) {
  var projection = {};
  Object.keys(source || {}).forEach(function (key) {
    var normalized = normalize_(key);
    if (OPJ_FINDING_TRANSPORT_KEYS_[normalized]) return;
    if (index && index[normalized] === undefined) return;
    projection[normalized] = receiptCanonical_(source[key]);
  });
  return projection;
}

function opjFindingActualProjection_(headers, row, expectedProjection) {
  var index = headerIndex_(headers), projection = {};
  Object.keys(expectedProjection).forEach(function (key) {
    if (index[key] === undefined) return;
    projection[key] = receiptCanonical_(row[index[key]]);
  });
  return projection;
}

function opjProjectionDigest_(projection) {
  return sha256_(Object.keys(projection).sort().map(function (key) {
    return key + '=' + projection[key];
  }).join('\n'));
}

function opjFindingCommitReadBack_(result, identity) {
  if (!result || result.success !== true || !result.folderPath || !result.photoReceipts) return false;
  var journalSource = operationJournalSheet_();
  var found = operationJournalFind_(journalSource, identity.operationId);
  if (!found) return false;
  var journal = operationJournalObject_(journalSource, found);
  if (!journal['Payload File ID']) return false;
  var payload = opjLoadPayload_(journal['Payload File ID']);
  var expected = payload && payload.row;
  if (!expected || typeof expected !== 'object') return false;
  var code = String(expected['Kode Temuan'] || '').trim();
  if (!code || code !== identity.objectId) return false;

  var sheet = temuanSheet_();
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return false;
  var headers = values[0].map(function (value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  var required = ['kode temuan', 'kode ulp', 'jenis object', 'folder path', 'link foto', 'link foto sekitaran tiang'];
  for (var i = 0; i < required.length; i++) if (index[required[i]] === undefined) return false;
  var matches = [];
  for (var row = 1; row < values.length; row++) {
    if (normalize_(values[row][index['kode temuan']]) === normalize_(code)) matches.push(values[row]);
  }
  if (matches.length !== 1) return false;
  var actual = matches[0];
  if (normalizeCode_(actual[index['kode ulp']]) !== normalizeCode_(expected['Kode ULP'])) return false;
  if (normalize_(actual[index['jenis object']]) !== normalize_(expected['Jenis Object'])) return false;
  if (String(actual[index['folder path']] || '').trim() !== String(result.folderPath || '').trim()) return false;

  var primary = result.photoReceipts.fotoTemuan;
  var environment = result.photoReceipts.fotoLingkungan;
  if (!primary || !environment || !primary.fileId || !environment.fileId || !primary.parentFolderId || !environment.parentFolderId) return false;
  if (String(actual[index['link foto']] || '').indexOf(primary.fileId) < 0) return false;
  if (String(actual[index['link foto sekitaran tiang']] || '').indexOf(environment.fileId) < 0) return false;

  var expectedProjection = opjFindingProjection_(expected, index);
  var actualProjection = opjFindingActualProjection_(headers, actual, expectedProjection);
  var expectedKeys = Object.keys(expectedProjection).sort();
  var actualKeys = Object.keys(actualProjection).sort();
  if (expectedKeys.length === 0 || expectedKeys.join('|') !== actualKeys.join('|')) return false;
  result.expectedSheetDigest = opjProjectionDigest_(expectedProjection);
  result.sheetDigest = opjProjectionDigest_(actualProjection);
  result.payloadDigest = identity.payloadDigest;
  return result.sheetDigest === result.expectedSheetDigest &&
    /^[a-f0-9]{64}$/.test(result.sheetDigest) &&
    result.payloadDigest === identity.payloadDigest;
}

function operationJournalPrepare_(identity, body) {
  var source, found, existing;
  var lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    source = operationJournalSheet_();
    found = operationJournalFind_(source, identity.operationId);
    existing = operationJournalObject_(source, found);
    if (existing) {
      if (normalize_(existing['Username']) !== identity.username || String(existing['Payload Digest']).toLowerCase() !== identity.payloadDigest) throw new Error('Operation ID tidak cocok dengan principal atau digest.');
      var state = normalize_(existing['State']);
      if (['committed', 'archived', 'purged'].indexOf(state) >= 0 && existing['Receipt JSON']) return existing;
      if (!existing['Payload File ID']) throw new Error('Snapshot durable operasi tidak tersedia.');
      return existing;
    }
  } finally { lock.releaseLock(); }

  var stored = opjStorePayloadOutsideLock_(identity, body);
  lock = LockService.getScriptLock(); lock.waitLock(20000);
  try {
    source = operationJournalSheet_();
    found = operationJournalFind_(source, identity.operationId);
    existing = operationJournalObject_(source, found);
    if (existing) {
      if (String(existing['Payload File ID']) !== stored.fileId && stored.created) {
        try { DriveApp.getFileById(stored.fileId).setTrashed(true); } catch (_) {}
      }
      return existing;
    }
    var now = operationJournalNow_();
    var row = {
      'Operation ID': identity.operationId, 'Action': identity.action, 'Object ID': identity.objectId,
      'Username': identity.username, 'Payload Digest': identity.payloadDigest, 'State': 'prepared',
      'Attempt Count': 0, 'First Prepared At': operationJournalIso_(now), 'Last Attempt At': '',
      'Committed At': '', 'Resolved At': '', 'Receipt JSON': '', 'Error Code': '', 'Error Message': '',
      'Next Reconciliation At': operationJournalIso_(now),
      'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_)),
      'Payload File ID': stored.fileId, 'Lease Until': '', 'Lease Token': '', 'Archived At': ''
    };
    source.sheet.appendRow(source.headers.map(function (header) { return row[header] === undefined ? '' : safeCell_(row[header]); }));
    SpreadsheetApp.flush();
    return operationJournalObject_(source, operationJournalFind_(source, identity.operationId));
  } finally { lock.releaseLock(); }
}
