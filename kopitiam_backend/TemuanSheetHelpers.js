function temuanSheetHeaders_() {
  return [
    "No", "Kode WO", "Kode Temuan", "Kode UIW", "Kode UP3", "Kode ULP", "ULP",
    "Hari", "Tanggal", "Penyulang", "Section Awal", "Section Akhir", "Section",
    "Segmen", "Nomor Gardu", "Jenis Object", "Tier", "Temuan",
    "Jarak Terhadap Jaringan", "Jenis Pohon", "Tinggi Pohon", "Prioritas",
    "Koordinat Temuan", "Lat Temuan", "Long Temuan", "Foto Temuan", "Link Foto",
    "Foto Lingkungan Sekitaran Tiang", "Link Foto Sekitaran Tiang",
    "Pekerjaan (Padam / Tanpa Padam)", "Jenis WO", "Waktu Input", "User Input", "Folder Path"
  ];
}

function temuanSheet_() {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.TEMUAN_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(CONFIG.TEMUAN_SHEET || "Inp_Temuan");
  if (!sheet) {
    sheet = spreadsheet.insertSheet(CONFIG.TEMUAN_SHEET || "Inp_Temuan");
    var headers = temuanSheetHeaders_();
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    try { sheet.setFrozenRows(1); } catch (_) {}
  }
  return sheet;
}

function validateTemuanHeaders_(headers) {
  var index = headerIndex_(headers);
  var required = ["kode wo", "kode temuan", "temuan", "tier"];
  for (var i = 0; i < required.length; i++) {
    if (index[required[i]] === undefined) {
      return fail_("SHEET_HEADERS_INVALID", "Header sheet Inp_Temuan belum valid. Kolom wajib tidak ditemukan: " + required[i] + ".");
    }
  }
  return { success: true };
}

function buildFindingPath_(kodeUlp, object, kodeWo, kodeTemuan, now) {
  var month = Utilities.formatDate(now, Session.getScriptTimeZone(), "MM");
  var year = Utilities.formatDate(now, Session.getScriptTimeZone(), "yyyy");
  var day = Utilities.formatDate(now, Session.getScriptTimeZone(), "dd");
  var monthName = Utilities.formatDate(now, Session.getScriptTimeZone(), "MM. MMMM");
  return "Kopitiam/Rekap Temuan Inspeksi/" + safePath_(kodeUlp) + "/" + safePath_(object) + "/" + year + "/" + monthName + "/" + day + "/" + safePath_(kodeWo) + "/" + safePath_(kodeTemuan) + "/";
}

var EVIDENCE_ROOT_FOLDER_ID_ = "1HAh-FAonWDyXvOEKroQbvu9vi6tlT1iL";
var EVIDENCE_MONTHS_ = {
  januari: "01", februari: "02", maret: "03", april: "04", mei: "05", juni: "06",
  juli: "07", agustus: "08", september: "09", oktober: "10", november: "11", desember: "12"
};

function evidenceFail_(code, message) {
  var error = new Error(message);
  error.evidenceCode = code;
  throw error;
}

function evidenceRelativePath_(pathValue) {
  var path = String(pathValue || "").trim().replace(/\\/g, "/").replace(/^\/+|\/+$/g, "");
  var prefixes = ["Eviden/", "Kopitiam/Rekap Temuan Inspeksi/", "Kopitiam/"];
  for (var i = 0; i < prefixes.length; i++) {
    if (normalize_(path.substring(0, prefixes[i].length)) === normalize_(prefixes[i])) {
      path = path.substring(prefixes[i].length);
      break;
    }
  }
  if (!path) evidenceFail_("FOLDER_PATH_INVALID", "Folder Path eviden kosong.");
  return path;
}

function folderPath_(pathValue) {
  var root;
  try {
    root = DriveApp.getFolderById(EVIDENCE_ROOT_FOLDER_ID_);
    if (root.isTrashed && root.isTrashed()) evidenceFail_("EVIDENCE_ROOT_INVALID", "Root Eviden berada di sampah.");
  } catch (error) {
    if (error && error.evidenceCode) throw error;
    evidenceFail_("EVIDENCE_ROOT_UNAVAILABLE", "Root Eviden tidak dapat diakses oleh akun deployment.");
  }
  var parts = evidenceRelativePath_(pathValue).split("/").filter(function (part) {
    return String(part).trim() !== "";
  });
  var current = root;
  for (var i = 0; i < parts.length; i++) {
    var name = safePath_(parts[i]);
    var folders = current.getFoldersByName(name);
    var next = folders.hasNext() ? folders.next() : current.createFolder(name);
    if (folders.hasNext()) evidenceFail_("FOLDER_PATH_AMBIGUOUS", "Ditemukan folder ganda pada segmen: " + name + ".");
    current = next;
  }
  return current;
}

function evidenceCanonicalPath_(kodeUlp, object, dateValue, kodeTemuan) {
  var match = String(dateValue || "").trim().match(/^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})(?:\b|,)/);
  if (!match) evidenceFail_("FINDING_DATE_INVALID", "Tanggal Temuan tidak valid untuk Folder Path.");
  var dayNumber = Number(match[1]);
  var monthName = normalize_(match[2]);
  var month = EVIDENCE_MONTHS_[monthName];
  var year = Number(match[3]);
  if (!month || dayNumber < 1 || dayNumber > 31 || year < 2000 || year > 2200) {
    evidenceFail_("FINDING_DATE_INVALID", "Tanggal Temuan tidak valid untuk Folder Path.");
  }
  var date = new Date(Date.UTC(year, Number(month) - 1, dayNumber));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== Number(month) - 1 || date.getUTCDate() !== dayNumber) {
    evidenceFail_("FINDING_DATE_INVALID", "Tanggal Temuan tidak valid untuk Folder Path.");
  }
  var day = ("0" + dayNumber).slice(-2);
  var displayMonth = match[2].charAt(0).toUpperCase() + match[2].substring(1).toLowerCase();
  return "Eviden/" + safePath_(kodeUlp) + "/" + safePath_(object) + "/" + year + "/" + month + ". " + safePath_(displayMonth) + "/" + day + "/" + safePath_(kodeTemuan) + "/";
}

function evidenceFinding_(kodeTemuan) {
  var sheet = temuanSheet_();
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) evidenceFail_("FINDING_NOT_FOUND", "Temuan induk tidak ditemukan.");
  var headers = values[0].map(function (value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  ["kode temuan", "kode ulp", "jenis object", "tanggal", "folder path"].forEach(function (key) {
    if (index[key] === undefined) evidenceFail_("FINDING_HEADERS_INVALID", "Kolom Temuan wajib tidak tersedia: " + key + ".");
  });
  var matches = [];
  for (var row = 1; row < values.length; row++) {
    if (normalize_(values[row][index["kode temuan"]]) === normalize_(kodeTemuan)) matches.push(row);
  }
  if (!matches.length) evidenceFail_("FINDING_NOT_FOUND", "Kode Temuan induk tidak ditemukan.");
  if (matches.length > 1) evidenceFail_("FINDING_AMBIGUOUS", "Kode Temuan induk ditemukan lebih dari satu kali.");
  return { sheet: sheet, values: values, headers: headers, index: index, rowIndex: matches[0] };
}

function evidencePrepareWoRows_(token, mode, sheetName, rows) {
  if (!Array.isArray(rows) || !rows.length) return fail_("BATCH_INVALID", "Data WO wajib diisi.");
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woCoreAccess_(auth.sesi, mode === "row" ? "row" : mode === "jar" || mode === "du" ? "insjar" : mode);
  if (mode === "jar" || mode === "du") {
    access = harAllowed_(auth.sesi, mode) ? { success: true, kodeUlp: normalizeCode_(auth.sesi.kodeUlp) } : fail_("HAR_ACCESS_DENIED", "Akses WO Har ditolak.");
  }
  if (!access.success) return access;
  var sheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(sheetName);
  if (!sheet) return fail_("SHEET_NOT_FOUND", "Sheet WO tidak ditemukan.");
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    var values = sheet.getDataRange().getDisplayValues();
    var headers = (values[0] || []).map(function (value) { return String(value).trim(); });
    var targets = woVerifiedPrepareTargets_(auth.sesi, values, headers, rows);
    var findingColumn = woVerifiedColumn_(targets.index, ["Kode Temuan"]);
    var folderColumn = woVerifiedColumn_(targets.index, ["Folder Path"]);
    var codeUlpColumn = woVerifiedColumn_(targets.index, ["Kode ULP"]);
    var objectColumn = woVerifiedColumn_(targets.index, ["Jenis Object"]);
    if (findingColumn < 0 || folderColumn < 0 || codeUlpColumn < 0) {
      evidenceFail_("WO_FOLDER_HEADERS_INVALID", "Kolom Kode Temuan, Kode ULP, dan Folder Path wajib tersedia pada WO.");
    }
    var expectedObject = mode === "du" ? "Gardu" : "Jaringan";
    var preparedRows = [];
    var folderIds = {};
    for (var i = 0; i < targets.prepared.length; i++) {
      var item = targets.prepared[i];
      var woRow = values[item.rowIndex];
      var findingCode = String(woRow[findingColumn] || "").trim();
      if (!findingCode) evidenceFail_("WO_FINDING_MISSING", item.code + ": Kode Temuan pada WO kosong.");
      var finding = evidenceFinding_(findingCode);
      var source = finding.values[finding.rowIndex];
      var findingUlp = source[finding.index["kode ulp"]];
      var findingObject = String(source[finding.index["jenis object"]] || "").trim();
      var woUlp = woRow[codeUlpColumn];
      if (normalizeCode_(findingUlp) !== normalizeCode_(auth.sesi.kodeUlp) || normalizeCode_(woUlp) !== normalizeCode_(findingUlp)) {
        evidenceFail_("FOLDER_PATH_ULP_MISMATCH", item.code + ": Kode ULP WO dan Temuan tidak cocok.");
      }
      if (normalize_(findingObject) !== normalize_(expectedObject)) {
        evidenceFail_("FOLDER_PATH_OBJECT_MISMATCH", item.code + ": Jenis Object Temuan tidak cocok dengan modul WO.");
      }
      if (objectColumn >= 0 && String(woRow[objectColumn] || "").trim() && normalize_(woRow[objectColumn]) !== normalize_(findingObject)) {
        evidenceFail_("FOLDER_PATH_OBJECT_MISMATCH", item.code + ": Jenis Object WO dan Temuan tidak cocok.");
      }
      var canonical = evidenceCanonicalPath_(findingUlp, findingObject, source[finding.index.tanggal], findingCode);
      if (String(source[finding.index["folder path"]] || "").trim() !== canonical) {
        finding.sheet.getRange(finding.rowIndex + 1, finding.index["folder path"] + 1).setValue(safeCell_(canonical));
      }
      if (String(woRow[folderColumn] || "").trim() !== canonical) {
        sheet.getRange(item.rowIndex + 1, folderColumn + 1).setValue(safeCell_(canonical));
      }
      SpreadsheetApp.flush();
      var findingReadBack = finding.sheet.getRange(finding.rowIndex + 1, finding.index["folder path"] + 1).getDisplayValue();
      var woReadBack = sheet.getRange(item.rowIndex + 1, folderColumn + 1).getDisplayValue();
      if (findingReadBack !== canonical || woReadBack !== canonical) {
        evidenceFail_("FOLDER_PATH_WRITE_FAILED", item.code + ": koreksi Folder Path gagal diverifikasi.");
      }
      var folder = folderPath_(canonical);
      var copy = {};
      Object.keys(item.incoming).forEach(function (key) { copy[key] = item.incoming[key]; });
      copy["Folder Path"] = canonical;
      preparedRows.push(copy);
      folderIds[item.code] = folder.getId();
    }
    return { success: true, rows: preparedRows, folderIds: folderIds };
  } catch (error) {
    return fail_(error.evidenceCode || error.woCode || "FOLDER_PATH_VALIDATION_FAILED", error.message);
  } finally {
    lock.releaseLock();
  }
}

function evidenceFinalizeReceipts_(result, folderIds) {
  if (!result || result.success !== true || !Array.isArray(result.receipts)) return result;
  try {
    for (var i = 0; i < result.receipts.length; i++) {
      var receipt = result.receipts[i];
      if (!receipt || !receipt.photo) continue;
      var expectedId = folderIds[String(receipt.kodeWo || "").trim()];
      if (!expectedId || !receipt.photo.fileId) evidenceFail_("PHOTO_PARENT_REQUIRED", "Receipt foto belum memuat identitas folder tujuan.");
      var file = DriveApp.getFileById(receipt.photo.fileId);
      var parents = file.getParents();
      var matched = false;
      while (parents.hasNext()) if (parents.next().getId() === expectedId) matched = true;
      if (!matched) evidenceFail_("PHOTO_PARENT_MISMATCH", "File foto tidak berada pada Folder Path terverifikasi.");
      receipt.photo.parentFolderId = expectedId;
    }
    return result;
  } catch (error) {
    return fail_(error.evidenceCode || "PHOTO_PARENT_VERIFY_FAILED", error.message);
  }
}

function syncWoPhotoWithEvidenceGuard_(token, mode, sheetName, rows) {
  var prepared = evidencePrepareWoRows_(token, mode, sheetName, rows);
  if (!prepared.success) return prepared;
  return evidenceFinalizeReceipts_(syncWoPhotoReceipt_(token, mode, sheetName, prepared.rows), prepared.folderIds);
}

function syncHarWithEvidenceGuard_(token, mode, rows) {
  var sheetName = mode === "jar" ? CONFIG.WO_HAR_JAR_SHEET : CONFIG.WO_HAR_DU_SHEET;
  var prepared = evidencePrepareWoRows_(token, mode, sheetName, rows);
  if (!prepared.success) return prepared;
  return evidenceFinalizeReceipts_(syncHarReceiptByStatus_(token, mode, prepared.rows), prepared.folderIds);
}
