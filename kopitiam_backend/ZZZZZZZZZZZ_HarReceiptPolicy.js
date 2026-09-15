/* Har progress may sync without a photo; completed Har must have one. */
function syncHarReceiptByStatus_(token, mode, rows) {
  receiptConfigureTransport_();
  var validated;
  try {
    validated = receiptValidateRows_(rows);
  } catch (error) {
    return fail_(error.woCommitCode || 'SYNC_RECEIPT_INVALID', error.message);
  }
  var result = syncHarCommitted_(token, mode, validated);
  var photoRequired = validated.some(function (row) {
    return normalize_(row['Status WO']) === 'selesai';
  });
  return receiptFinalize_(result, validated, photoRequired);
}
