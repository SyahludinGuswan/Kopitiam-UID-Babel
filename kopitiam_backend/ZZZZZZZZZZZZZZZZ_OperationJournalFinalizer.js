/* REL-07 finalizer: no credentials at rest, active reconciliation, two-stage retention. */
var OPJ_ARCHIVE_FOLDER_ = '_operation_archive';

function opjSanitizeBody_(body) {
  var clean = {};
  if (body && body.action) clean.action = String(body.action);
  if (body && Array.isArray(body.rows)) clean.rows = body.rows;
  if (body && body.row && typeof body.row === 'object') clean.row = body.row;
  return clean;
}

function opjSerializedPayload_(body) {
  var clean = opjSanitizeBody_(body);
  var json = JSON.stringify(clean);
  if (/"(?:token|deviceToken|password)"\s*:/i.test(json)) {
    throw new Error('Credential tidak boleh disimpan pada durable inbox.');
  }
  if (json.length > 15 * 1024 * 1024) throw new Error('Payload jurnal melampaui batas.');
  return json;
}

function opjStorePayloadOutsideLock_(identity, body) {
  var folder = opjPayloadFolder_();
  var filename = 'operation.' + identity.operationId + '.json';
  var json = opjSerializedPayload_(body);
  var expectedDigest = sha256_(json);
  var matches = folder.getFilesByName(filename), found = [], file;
  while (matches.hasNext()) found.push(matches.next());
  for (var i = 0; i < found.length; i++) {
    var raw = found[i].getBlob().getDataAsString('UTF-8');
    if (sha256_(raw) === expectedDigest && !file) file = found[i];
    else try { found[i].setTrashed(true); } catch (_) {}
  }
  if (!file) file = folder.createFile(Utilities.newBlob(json, 'application/json', filename));
  return { fileId: file.getId(), digest: expectedDigest, created: found.length === 0 };
}

function operationJournalPrepare_(identity, body) {
  var source, found, existing;
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    source = operationJournalSheet_();
    found = operationJournalFind_(source, identity.operationId);
    existing = operationJournalObject_(source, found);
    if (existing) {
      if (normalize_(existing['Username']) !== identity.username || String(existing['Payload Digest']).toLowerCase() !== identity.payloadDigest) throw new Error('Operation ID tidak cocok dengan principal atau digest.');
      if (!existing['Payload File ID']) throw new Error('Snapshot durable operasi tidak tersedia.');
      return existing;
    }
  } finally { lock.releaseLock(); }

  /* Drive I/O intentionally happens without the global ScriptLock. */
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

function opjExecuteStored_(action, body, token) {
  if (action === 'syncWoInsjar') return syncWoNoPhotoReceipt_(token, 'insjar', CONFIG.WO_INSJAR_SHEET, body.rows);
  if (action === 'syncWoInsdu') return syncWoInsduReceipt_(token, body.rows);
  if (action === 'syncWoRow') return syncWoPhotoWithEvidenceGuard_(token, 'row', CONFIG.WO_ROW_SHEET, body.rows);
  if (action === 'syncWoHarJar') return syncHarWithEvidenceGuard_(token, 'jar', body.rows);
  if (action === 'syncWoHarDu') return syncHarWithEvidenceGuard_(token, 'du', body.rows);
  if (action === 'syncTemuanInspeksi') return syncTemuanWithEvidenceGuard_(token, body.row);
  return fail_('OPERATION_ACTION_INVALID', 'Action jurnal tidak didukung.');
}

function operationJournalReconcileUser_(session, token, limit) {
  var username = normalize_(session && session.username), source = operationJournalSheet_();
  if (!username || !token) return { success: false, processed: 0 };
  var last = source.sheet.getLastRow();
  if (last < 2) return { success: true, processed: 0 };
  var values = source.sheet.getRange(2, 1, last - 1, source.headers.length).getDisplayValues();
  var now = operationJournalNow_(), processed = 0, maximum = Math.max(1, Math.min(Number(limit || 1), 5));
  for (var i = 0; i < values.length && processed < maximum; i++) {
    var record = {}; source.headers.forEach(function (header, index) { record[header] = values[i][index]; });
    var state = normalize_(record['State']), due = Date.parse(record['Next Reconciliation At'] || '');
    if (normalize_(record['Username']) !== username || (state !== 'prepared' && state !== 'needs-reconciliation') || (isFinite(due) && due > now.getTime())) continue;
    var claim = opjClaim_(record['Operation ID']);
    if (!claim || claim.busy || claim.committed || !claim.token) continue;
    var result;
    try {
      var payload = opjLoadPayload_(record['Payload File ID']);
      result = opjExecuteStored_(record['Action'], payload, token);
    } catch (error) {
      result = fail_('RECONCILIATION_FAILED', String(error && error.message || error));
    }
    var identity = { objectId: record['Object ID'], payloadDigest: String(record['Payload Digest']).toLowerCase() };
    var verified = opjVerifiedSuccess_(record['Action'], result, identity);
    if (result && result.success === true && !verified) result = fail_('OPERATION_RECEIPT_INVALID', 'Hasil rekonsiliasi tidak memiliki receipt final yang valid.');
    opjFinish_(record['Operation ID'], claim.token, result, verified);
    processed++;
  }
  return { success: true, processed: processed };
}

function opjArchiveFolder_() {
  var root = evidenceRootFolder_(), matches = root.getFoldersByName(OPJ_ARCHIVE_FOLDER_);
  var folder = matches.hasNext() ? matches.next() : root.createFolder(OPJ_ARCHIVE_FOLDER_);
  if (matches.hasNext()) throw new Error('Folder arsip jurnal duplikat.');
  return folder;
}

function opjMovePayloadToArchive_(fileId) {
  var file = DriveApp.getFileById(String(fileId || '')), archive = opjArchiveFolder_();
  archive.addFile(file);
  var parents = file.getParents();
  while (parents.hasNext()) {
    var parent = parents.next();
    if (parent.getId() !== archive.getId()) try { parent.removeFile(file); } catch (_) {}
  }
}

function operationJournalArchive_() {
  var snapshotSource = operationJournalSheet_(), last = snapshotSource.sheet.getLastRow();
  if (last < 2) return { success: true, archived: 0, purged: 0 };
  var operationColumn = opjColumn_(snapshotSource, 'Operation ID');
  var snapshot = snapshotSource.sheet.getRange(2, 1, last - 1, snapshotSource.headers.length).getDisplayValues();
  var now = operationJournalNow_(), archived = 0, purged = 0;
  for (var i = 0; i < snapshot.length; i++) {
    var operationId = String(snapshot[i][operationColumn] || '').trim();
    if (!operationId) continue;
    var lock = LockService.getScriptLock();
    lock.waitLock(20000);
    try {
      var source = operationJournalSheet_();
      var found = operationJournalFind_(source, operationId);
      if (!found) continue;
      var record = operationJournalObject_(source, found);
      var state = normalize_(record['State']);
      var due = Date.parse(record['Archive After'] || '');
      var fileId = record['Payload File ID'];
      if (!isFinite(due) || due > now.getTime()) continue;
      if (state === 'committed' || state === 'resolved') {
        if (fileId) opjMovePayloadToArchive_(fileId);
        operationJournalWrite_(source, found.rowNumber, {
          'State': 'archived', 'Archived At': operationJournalIso_(now),
          'Archive After': operationJournalIso_(operationJournalAddDays_(now, OPERATION_JOURNAL_ARCHIVE_DAYS_))
        });
        archived++;
      } else if (state === 'archived') {
        if (fileId) try { DriveApp.getFileById(fileId).setTrashed(true); } catch (_) {}
        operationJournalWrite_(source, found.rowNumber, { 'State': 'purged', 'Payload File ID': '', 'Archive After': '' });
        purged++;
      }
      /* prepared/processing/needs-reconciliation are never auto-deleted. */
    } finally {
      lock.releaseLock();
    }
  }
  return { success: true, archived: archived, purged: purged };
}
