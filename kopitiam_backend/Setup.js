var DEVICE_TOKEN_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
var DEVICE_TOKEN_IDLE_MS = 1 * 24 * 60 * 60 * 1000;
var DEVICE_CLEANUP_HANDLER = "bersihkanTokenPerangkatKedaluwarsa";

/**
 * Menyiapkan dan memvalidasi backend tanpa mengubah data pengguna yang ada.
 * Jalankan sekali dari editor Apps Script setelah deployment baru.
 * PENTING: pemanggil dari editor dipaksa mengotorisasi ulang Drive +
 * Spreadsheets saat oauthScopes manifest berubah; tanpa mencicipi DriveApp
 * di sini, otorisasi ulang tidak pernah terpicu dan upload foto ditolak.
 */
function setupBackend() {
  // Menyentil Drive agar editor memicu ulang otorisasi saat manifest berubah.
  DriveApp.getRootFolder();

  var master = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID);
  var wo = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
  var temuan = SpreadsheetApp.openById(CONFIG.TEMUAN_SPREADSHEET_ID);

  ensureSheet_(master, CONFIG.USERS_SHEET, [
    "No",
    "Kode UIW",
    "Kode UP3",
    "Kode ULP",
    "ULP",
    "Username",
    "Role",
    "Bidang",
    "Tim",
    "Sub-Tim",
    "Akses Menu",
  ]);
  requireSheet_(wo, CONFIG.WO_INSJAR_SHEET, [
    "Kode WO",
    "Kode ULP",
    "Status WO",
  ]);
  requireSheet_(wo, CONFIG.WO_ROW_SHEET, [
    "Kode WO",
    "Kode ULP",
    "Status WO",
    "Tim Eksekusi",
  ]);
  requireSheet_(wo, CONFIG.WO_HAR_JAR_SHEET, [
    "Kode WO",
    "Kode ULP",
    "Status WO",
    "Tim Eksekusi",
  ]);
  configureHarMaterialSheet_();
  requireSheet_(wo, CONFIG.MATERIAL_HAR_JAR_SHEET, HAR_MATERIAL_SETUP_HEADERS_);
  ensureSheet_(temuan, CONFIG.TEMUAN_SHEET, temuanSheetHeaders_());

  // Metadata is configured separately. Keep legacy setup idempotent while the
  // Script Property is not yet present; all revision-protected writes remain
  // fail-closed because their metadata helper still requires this property.
  var revisionMetadata = "not_configured";
  var metadataProperty = typeof REVISION_METADATA_CONFIG_ !== "undefined"
    ? REVISION_METADATA_CONFIG_.spreadsheetProperty
    : "REVISION_METADATA_SPREADSHEET_ID";
  var metadataId = PropertiesService.getScriptProperties().getProperty(metadataProperty);
  if (String(metadataId || "").trim()) {
    ensureRevisionMetadataSheets_();
    revisionMetadata = "configured";
  }

  pasangTriggerPembersihanToken_();
  var cleanup = bersihkanTokenPerangkatKedaluwarsa();
  return {
    success: true,
    service: "SiManDist API",
    version: "2.5.3",
    deviceTokenMaxDays: 7,
    deviceTokenIdleDays: 1,
    revisionMetadata: revisionMetadata,
    expiredTokensRemoved: cleanup.dihapus,
  };
}

/**
 * Menghapus token perangkat yang berumur lebih dari 7 hari, tidak dipakai
 * selama 1 hari, rusak, atau memiliki waktu yang tidak masuk akal.
 * Dipanggil otomatis setiap jam oleh trigger yang dibuat setupBackend().
 */
function bersihkanTokenPerangkatKedaluwarsa() {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var props = PropertiesService.getScriptProperties();
    var all = props.getProperties();
    var now = Date.now();
    var removed = 0;
    var active = 0;

    Object.keys(all).forEach(function (key) {
      if (key.indexOf("device_") !== 0) return;
      var remove = false;
      try {
        var record = JSON.parse(all[key]);
        var createdAt = Number(record.createdAt || 0);
        var lastUsedAt = Number(record.lastUsedAt || createdAt || 0);
        remove =
          !createdAt ||
          !lastUsedAt ||
          createdAt > now ||
          lastUsedAt > now ||
          now - createdAt >= DEVICE_TOKEN_MAX_AGE_MS ||
          now - lastUsedAt >= DEVICE_TOKEN_IDLE_MS;
      } catch (_) {
        remove = true;
      }
      if (remove) {
        props.deleteProperty(key);
        removed++;
      } else {
        active++;
      }
    });

    return { success: true, dihapus: removed, aktif: active };
  } finally {
    lock.releaseLock();
  }
}

function pasangTriggerPembersihanToken_() {
  var exists = ScriptApp.getProjectTriggers().some(function (trigger) {
    return trigger.getHandlerFunction() === DEVICE_CLEANUP_HANDLER;
  });
  if (!exists) {
    ScriptApp.newTrigger(DEVICE_CLEANUP_HANDLER)
      .timeBased()
      .everyHours(1)
      .create();
  }
}

function requireSheet_(spreadsheet, name, requiredHeaders) {
  var sheet = spreadsheet.getSheetByName(name);
  if (!sheet) throw new Error("Sheet wajib tidak ditemukan: " + name);
  validateHeaders_(sheet, requiredHeaders);
  return sheet;
}

function ensureSheet_(spreadsheet, name, headers) {
  var sheet = spreadsheet.getSheetByName(name) || spreadsheet.insertSheet(name);
  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight("bold");
  } else {
    validateHeaders_(sheet, headers);
  }
  return sheet;
}

function validateHeaders_(sheet, requiredHeaders) {
  var lastColumn = sheet.getLastColumn();
  if (lastColumn < 1) {
    throw new Error("Header sheet kosong: " + sheet.getName());
  }
  var current = sheet
    .getRange(1, 1, 1, lastColumn)
    .getDisplayValues()[0]
    .map(function (value) {
      return String(value || "")
        .trim()
        .toLowerCase();
    });
  var missing = requiredHeaders.filter(function (header) {
    return current.indexOf(String(header).trim().toLowerCase()) < 0;
  });
  if (missing.length) {
    throw new Error(
      "Header sheet " +
        sheet.getName() +
        " tidak lengkap: " +
        missing.join(", "),
    );
  }
}
