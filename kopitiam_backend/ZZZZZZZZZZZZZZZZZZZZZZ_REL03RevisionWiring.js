// REL-03 override kept late in the Apps Script file set so legacy HAR handlers use sparse writes.
function syncWoHarJar_(t, rows) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "jar");
  if (!ac.success) return ac;
  return syncGenericWoHarRevision_(a.sesi, CONFIG.WO_HAR_JAR_SHEET, rows);
}

function syncWoHarDu_(t, rows) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "du");
  if (!ac.success) return ac;
  return syncGenericWoHarRevision_(a.sesi, CONFIG.WO_HAR_DU_SHEET, rows);
}

function syncGenericWoHarRevision_(sesi, sheetName, rows) {
  if (!Array.isArray(rows) || rows.length > 100) return fail_("BATCH_INVALID", "Maksimal 100 WO.");
  var source = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
  var sh = source.getSheetByName(sheetName);
  if (!sh) return fail_("SHEET_NOT_FOUND", "Sheet " + sheetName + " tidak ditemukan.");
  var v = sh.getDataRange().getValues();
  if (v.length < 2) return fail_("DATA_EMPTY", "Sheet data kosong.");
  var h = v[0].map(function (x) { return String(x).trim(); });
  var ix = headerIndex_(h), lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var done = 0;
    for (var i = 0; i < rows.length; i++) {
      var d = rows[i] || {}, kodeWo = String(d["Kode WO"] || "").trim(), target = -1;
      for (var r = 1; r < v.length; r++) if (String(v[r][ix["kode wo"]] || "").trim() === kodeWo && normalizeCode_(v[r][ix["kode ulp"]]) === normalizeCode_(sesi.kodeUlp)) { target = r; break; }
      if (target < 0) continue;
      var stableKey = revisionStableKey_([sesi.kodeUlp, kodeWo]);
      var revisionCheck = revisionAssertCurrent_(source.getId(), sh.getName(), stableKey, d);
      if (!revisionCheck.success) return revisionCheck;
      var out = v[target].slice(), normPayload = {};
      for (var key in d) if (Object.prototype.hasOwnProperty.call(d, key)) normPayload[normalize_(key)] = d[key];
      var existingFolder = ix["folder path"] !== undefined ? v[target][ix["folder path"]] : "";
      var folderPathVal = normPayload["folder path"] || existingFolder || ("Kopitiam/WO_HAR/" + safePath_(sesi.kodeUlp || "") + "/" + safePath_(kodeWo) + "/");
      normPayload["folder path"] = folderPathVal;
      var b64Photo = normPayload["foto sesudah base64"] || normPayload["fotosesudahbase64"];
      if (b64Photo) {
        try {
          var uploaded = uploadWoPhoto_(folderPathVal, kodeWo, b64Photo, "Foto Sesudah");
          if (uploaded) {
            var cleanPath = String(folderPathVal || "").replace(/[\/\\]+$/, "");
            normPayload["foto sesudah"] = cleanPath + "\\" + uploaded.name;
            normPayload["link foto sesudah"] = uploaded.url;
          }
        } catch (photoErr) { console.error("Upload foto har gagal:", photoErr); }
      } else if (normPayload["foto sesudah"]) {
        var rawName = String(normPayload["foto sesudah"]).trim();
        if (rawName && rawName.indexOf("\\") < 0 && rawName.indexOf("/") < 0) normPayload["foto sesudah"] = String(folderPathVal || "").replace(/[\/\\]+$/, "") + "\\" + rawName;
      }
      for (var c = 0; c < h.length; c++) {
        var n = normalize_(h[c]);
        if (WO_HAR_MUTABLE_HEADERS.indexOf(n) >= 0 && normPayload[n] !== undefined) out[c] = safeCell_(normPayload[n]);
      }
      if (ix["status wo"] !== undefined) out[ix["status wo"]] = "Selesai";
      revisionWriteChangedCells_(sh, target + 1, h, v[target], out, WO_HAR_MUTABLE_HEADERS);
      SpreadsheetApp.flush();
      var committedRow = sh.getRange(target + 1, 1, 1, h.length).getValues()[0];
      revisionCommit_(source.getId(), sh.getName(), stableKey, committedRow, "UPDATE", sesi.username);
      done++;
    }
    return { success: true, diproses: done, diperbarui: done };
  } finally { lock.releaseLock(); }
}
