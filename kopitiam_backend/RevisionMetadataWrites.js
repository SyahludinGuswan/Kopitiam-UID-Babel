function revisionWriteChangedCells_(sheet, rowNumber, headers, currentRow, nextRow, mutableHeaders) {
  var allowed = {};
  (mutableHeaders || []).forEach(function (header) { allowed[normalize_(header)] = true; });
  var start = -1;
  var pending = [];
  function flush() {
    if (start < 0 || !pending.length) return;
    sheet.getRange(rowNumber, start + 1, 1, pending.length).setValues([pending]);
    start = -1;
    pending = [];
  }
  for (var column = 0; column < headers.length; column++) {
    var changed = allowed[normalize_(headers[column])] && String(currentRow[column] == null ? "" : currentRow[column]) !== String(nextRow[column] == null ? "" : nextRow[column]);
    if (!changed) { flush(); continue; }
    if (start < 0) start = column;
    pending.push(nextRow[column]);
  }
  flush();
}
