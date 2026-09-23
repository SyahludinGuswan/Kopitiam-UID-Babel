// Read compatibility: missing metadata must not break read-only endpoints.
// Write paths continue using revisionRead_ and therefore remain fail-closed.
function revisionReadForResponse_(sourceSpreadsheetId, sourceSheet, stableKey) {
  try {
    return revisionRead_(sourceSpreadsheetId, sourceSheet, stableKey);
  } catch (error) {
    var message = String(error && error.message || error || "");
    if (message.indexOf("REVISION_METADATA_SPREADSHEET_ID") >= 0) {
      return { revision: 0, fingerprint: "", updatedAt: "", updatedBy: "", metadataConfigured: false };
    }
    throw error;
  }
}

function woCoreReadRowWithRevision_(sourceSpreadsheetId, sourceSheet, kodeUlp, code, headers, values) {
  var item = rowObject_(headers, values);
  var metadata = revisionReadForResponse_(sourceSpreadsheetId, sourceSheet, revisionStableKey_([kodeUlp, code]));
  item._revision = metadata.revision;
  item._fingerprint = metadata.fingerprint;
  return item;
}
