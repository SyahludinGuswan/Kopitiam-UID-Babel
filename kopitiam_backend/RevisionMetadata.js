var REVISION_METADATA_CONFIG_ = {
  spreadsheetProperty: "REVISION_METADATA_SPREADSHEET_ID",
  indexSheet: "REVISION_INDEX",
  auditSheet: "REVISION_AUDIT",
  configSheet: "METADATA_CONFIG",
  indexHeaders: ["SourceSpreadsheetId", "SourceSheet", "StableKey", "Revision", "Fingerprint", "UpdatedAt", "UpdatedBy", "Status"],
  auditHeaders: ["SourceSpreadsheetId", "SourceSheet", "StableKey", "Revision", "Fingerprint", "ChangedAt", "ChangedBy", "Action", "Status"],
  configHeaders: ["Key", "Value", "UpdatedAt", "Status"],
  maxHistory: 10,
  maxAgeMs: 90 * 24 * 60 * 60 * 1000
};

function revisionMetadataSpreadsheetId_() {
  var id = PropertiesService.getScriptProperties().getProperty(REVISION_METADATA_CONFIG_.spreadsheetProperty);
  id = String(id || "").trim();
  if (!id) throw new Error("REVISION_METADATA_SPREADSHEET_ID belum dikonfigurasi.");
  return id;
}

function revisionMetadataSpreadsheet_() {
  return SpreadsheetApp.openById(revisionMetadataSpreadsheetId_());
}

function ensureRevisionMetadataSheets_() {
  var spreadsheet = revisionMetadataSpreadsheet_();
  ensureSheet_(spreadsheet, REVISION_METADATA_CONFIG_.indexSheet, REVISION_METADATA_CONFIG_.indexHeaders);
  ensureSheet_(spreadsheet, REVISION_METADATA_CONFIG_.auditSheet, REVISION_METADATA_CONFIG_.auditHeaders);
  ensureSheet_(spreadsheet, REVISION_METADATA_CONFIG_.configSheet, REVISION_METADATA_CONFIG_.configHeaders);
  return spreadsheet;
}

function revisionStableKey_(parts) {
  return (parts || []).map(function (part) {
    return String(part == null ? "" : part).trim().toUpperCase().replace(/[|\\r\\n]/g, " ");
  }).join("|");
}

function revisionFingerprint_(row) {
  var canonical = JSON.stringify((row || []).map(function (value) {
    if (value instanceof Date) return value.toISOString();
    return value == null ? "" : String(value);
  }));
  return sha256_(canonical);
}

function revisionRead_(sourceSpreadsheetId, sourceSheet, stableKey) {
  var spreadsheet = ensureRevisionMetadataSheets_();
  var sheet = spreadsheet.getSheetByName(REVISION_METADATA_CONFIG_.indexSheet);
  var values = sheet.getDataRange().getValues();
  for (var row = 1; row < values.length; row++) {
    if (String(values[row][0]) === String(sourceSpreadsheetId) &&
        String(values[row][1]) === String(sourceSheet) &&
        String(values[row][2]) === String(stableKey) &&
        String(values[row][7] || "ACTIVE").toUpperCase() === "ACTIVE") {
      return { revision: Number(values[row][3] || 0), fingerprint: String(values[row][4] || ""), updatedAt: values[row][5] || "", updatedBy: String(values[row][6] || "") };
    }
  }
  return { revision: 0, fingerprint: "", updatedAt: "", updatedBy: "" };
}

function revisionExpected_(payload) {
  payload = payload || {};
  var revision = payload._revision;
  if (revision === undefined) revision = payload.Revision;
  if (revision === undefined) revision = payload.revision;
  var fingerprint = payload._fingerprint;
  if (fingerprint === undefined) fingerprint = payload.Fingerprint;
  if (fingerprint === undefined) fingerprint = payload.fingerprint;
  return { supplied: revision !== undefined || fingerprint !== undefined, revision: revision === undefined || revision === "" ? null : Number(revision), fingerprint: fingerprint === undefined || fingerprint === "" ? null : String(fingerprint) };
}

function revisionAssertCurrent_(sourceSpreadsheetId, sourceSheet, stableKey, payload) {
  var current = revisionRead_(sourceSpreadsheetId, sourceSheet, stableKey);
  var expected = revisionExpected_(payload);
  if (!expected.supplied) return { success: true, current: current, expected: expected };
  if (expected.revision !== null && expected.revision !== current.revision) return fail_("REVISION_CONFLICT", "Revision data sudah berubah. Muat ulang data sebelum menyimpan.");
  if (expected.fingerprint !== null && expected.fingerprint !== current.fingerprint) return fail_("REVISION_CONFLICT", "Fingerprint data sudah berubah. Muat ulang data sebelum menyimpan.");
  return { success: true, current: current, expected: expected };
}

function revisionCommit_(sourceSpreadsheetId, sourceSheet, stableKey, row, action, updatedBy) {
  var spreadsheet = ensureRevisionMetadataSheets_();
  var indexSheet = spreadsheet.getSheetByName(REVISION_METADATA_CONFIG_.indexSheet);
  var auditSheet = spreadsheet.getSheetByName(REVISION_METADATA_CONFIG_.auditSheet);
  var now = new Date();
  var fingerprint = revisionFingerprint_(row);
  var current = revisionRead_(sourceSpreadsheetId, sourceSheet, stableKey);
  var nextRevision = current.revision + 1;
  var indexValues = indexSheet.getDataRange().getValues();
  var target = 0;
  for (var i = 1; i < indexValues.length; i++) {
    if (String(indexValues[i][0]) === String(sourceSpreadsheetId) && String(indexValues[i][1]) === String(sourceSheet) && String(indexValues[i][2]) === String(stableKey)) { target = i + 1; break; }
  }
  var record = [sourceSpreadsheetId, sourceSheet, stableKey, nextRevision, fingerprint, now, String(updatedBy || "system"), "ACTIVE"];
  if (target) indexSheet.getRange(target, 1, 1, record.length).setValues([record]); else indexSheet.appendRow(record);
  auditSheet.appendRow([sourceSpreadsheetId, sourceSheet, stableKey, nextRevision, fingerprint, now, String(updatedBy || "system"), String(action || "WRITE"), "ACTIVE"]);
  revisionPruneHistory_(auditSheet, sourceSpreadsheetId, sourceSheet, stableKey);
  return { revision: nextRevision, fingerprint: fingerprint };
}

function revisionPruneHistory_(auditSheet, sourceSpreadsheetId, sourceSheet, stableKey) {
  var values = auditSheet.getDataRange().getValues();
  var matches = [];
  var now = Date.now();
  for (var i = 1; i < values.length; i++) {
    if (String(values[i][0]) !== String(sourceSpreadsheetId) || String(values[i][1]) !== String(sourceSheet) || String(values[i][2]) !== String(stableKey)) continue;
    matches.push({ row: i + 1, time: values[i][5] instanceof Date ? values[i][5].getTime() : 0 });
  }
  matches.sort(function (a, b) { return b.time - a.time; });
  for (var j = REVISION_METADATA_CONFIG_.maxHistory; j < matches.length; j++) auditSheet.deleteRow(matches[j].row - (j - REVISION_METADATA_CONFIG_.maxHistory));
  var refreshed = auditSheet.getDataRange().getValues();
  for (var r = refreshed.length - 1; r >= 1; r--) {
    if (String(refreshed[r][0]) !== String(sourceSpreadsheetId) || String(refreshed[r][1]) !== String(sourceSheet) || String(refreshed[r][2]) !== String(stableKey)) continue;
    var time = refreshed[r][5] instanceof Date ? refreshed[r][5].getTime() : 0;
    if (time && Date.now() - time > REVISION_METADATA_CONFIG_.maxAgeMs) auditSheet.deleteRow(r + 1);
  }
}

function revisionWriteGuard_(args) {
  args = args || {};
  var sourceSpreadsheetId = String(args.sourceSpreadsheetId || "").trim();
  var sourceSheet = String(args.sourceSheet || "").trim();
  var stableKey = String(args.stableKey || "").trim();
  if (!sourceSpreadsheetId || !sourceSheet || !stableKey) throw new Error("Identitas revision metadata tidak lengkap.");
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var check = revisionAssertCurrent_(sourceSpreadsheetId, sourceSheet, stableKey, args.payload || {});
    if (!check.success) return check;
    var result = revisionCommit_(sourceSpreadsheetId, sourceSheet, stableKey, args.row || [], args.action || "WRITE", args.updatedBy || "system");
    return { success: true, revision: result.revision, fingerprint: result.fingerprint };
  } finally { lock.releaseLock(); }
}
