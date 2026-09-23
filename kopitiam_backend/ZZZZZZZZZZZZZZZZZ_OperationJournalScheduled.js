/* REL-07 final safeguards: Temuan read-back, archived replay, scheduled maintenance. */
var OPJ_MAINTENANCE_HANDLER_ = 'operationJournalScheduledMaintenance_';
var OPJ_ARCHIVE_HANDLER_ = 'operationJournalScheduledArchive_';

function opjFindingCommitReadBack_(result, identity) {
  if (!result || result.success !== true || !result.folderPath || !result.photoReceipts) return false;
  var payloadRecord = operationJournalSheet_();
  var found = operationJournalFind_(payloadRecord, identity.operationId);
  if (!found) return false;
  var journal = operationJournalObject_(payloadRecord, found);
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
  var primaryLink = String(actual[index['link foto']] || '');
  var environmentLink = String(actual[index['link foto sekitaran tiang']] || '');
  if (primaryLink.indexOf(primary.fileId) < 0 || environmentLink.indexOf(environment.fileId) < 0) return false;

  var canonical = {};
  headers.forEach(function (header, column) { canonical[normalize_(header)] = actual[column]; });
  result.sheetDigest = sha256_(Object.keys(canonical).sort().map(function (key) {
    return key + '=' + receiptCanonical_(canonical[key]);
  }).join('\n'));
  result.payloadDigest = identity.payloadDigest;
  return /^[a-f0-9]{64}$/.test(result.sheetDigest) && result.payloadDigest === identity.payloadDigest;
}

function opjVerifiedSuccess_(action, result, identity) {
  if (!result || result.success !== true) return false;
  if (action === 'syncTemuanInspeksi') return opjFindingCommitReadBack_(result, identity);
  if (!Array.isArray(result.receipts) || result.receipts.length !== 1) return false;
  var receipt = result.receipts[0];
  return !!(receipt && receipt.committed === true &&
    String(receipt.kodeWo || '').trim() === identity.objectId &&
    String(receipt.payloadDigest || '').toLowerCase() === identity.payloadDigest);
}

function operationJournalReplay_(record) {
  var state = normalize_(record && record['State']);
  if (!record || ['committed', 'archived', 'purged'].indexOf(state) < 0 || !record['Receipt JSON']) return null;
  try {
    var receipt = JSON.parse(record['Receipt JSON']);
    if (!receipt || receipt.success !== true) return null;
    receipt.replayed = true;
    receipt.operationId = record['Operation ID'];
    receipt.journalState = state;
    return receipt;
  } catch (_) { return null; }
}

function operationJournalSweepStaleLeases_() {
  return operationJournalSweepStaleLeasesRel07_();
}

function operationJournalScheduledMaintenance_() {
  var released = operationJournalSweepStaleLeases_();
  /* Safe unattended work is limited to stale-lease recovery. Business replay
   * still requires a live user session so authorization is never bypassed. */
  return { success: true, released: released.released || 0 };
}

function operationJournalScheduledArchive_() {
  return operationJournalArchive_();
}

function setupOperationJournalTriggers_() {
  var handlers = {};
  handlers[OPJ_MAINTENANCE_HANDLER_] = true;
  handlers[OPJ_ARCHIVE_HANDLER_] = true;
  ScriptApp.getProjectTriggers().forEach(function (trigger) {
    var handler = trigger.getHandlerFunction();
    if (handlers[handler]) ScriptApp.deleteTrigger(trigger);
  });
  ScriptApp.newTrigger(OPJ_MAINTENANCE_HANDLER_).timeBased().everyMinutes(15).create();
  ScriptApp.newTrigger(OPJ_ARCHIVE_HANDLER_).timeBased().everyDays(1).atHour(2).create();
  return { success: true, maintenanceMinutes: 15, archiveHour: 2 };
}
