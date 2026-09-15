/* Final commit guard: acknowledge a WO only after Sheet and Drive read-back. */
var WO_COMMIT_TRANSPORT_KEYS_ = {
  'foto sesudah base64': true,
  'fotosesudahbase64': true,
  'schemaversion': true,
  'jobs': true,
  'materials': true
};

function woCommitFail_(code, message) {
  var error = new Error(message);
  error.woCommitCode = code;
  throw error;
}

function woCommitCanonical_(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') return isFinite(value) ? String(value) : '__invalid_number__';
  var text = String(value).trim().replace(/\s+/g, ' ');
  if (!text) return '';
  var numeric = Number(text.replace(',', '.'));
  if (/^-?\d+(?:[.,]\d+)?$/.test(text) && isFinite(numeric)) return String(numeric);
  return text.toLowerCase();
}

function woCommitEqual_(left, right) {
  return woCommitCanonical_(left) === woCommitCanonical_(right);
}

function woCommitDigest_(object) {
  var keys = Object.keys(object).sort();
  return sha256_(keys.map(function (key) {
    return key + '=' + woCommitCanonical_(object[key]);
  }).join('\n'));
}

function woCommitExpected_(headers, normalized) {
  var expected = {};
  var index = headerIndex_(headers);
  Object.keys(normalized).forEach(function (key) {
    if (WO_COMMIT_TRANSPORT_KEYS_[key]) return;
    if (index[key] === undefined) {
      woCommitFail_('WO_FIELD_UNMAPPED', 'Field tidak memiliki kolom tujuan: ' + key + '.');
    }
    expected[key] = normalized[key];
  });
  return expected;
}

function woCommitVerifyRow_(sheet, rowNumber, headers, expected) {
  var actual = sheet.getRange(rowNumber, 1, 1, headers.length).getDisplayValues()[0];
  var index = headerIndex_(headers);
  Object.keys(expected).forEach(function (key) {
    if (!woCommitEqual_(actual[index[key]], expected[key])) {
      woCommitFail_('WO_SHEET_VERIFY_FAILED', 'Nilai Sheet tidak cocok setelah ditulis: ' + headers[index[key]] + '.');
    }
  });
  return actual;
}

function woCommitVerifyPhoto_(uploaded, prepared) {
  if (!uploaded || !uploaded.file || !prepared) woCommitFail_('WO_PHOTO_REQUIRED', 'Foto Sesudah belum tersimpan.');
  var file = uploaded.file;
  var blob = file.getBlob();
  var bytes = blob.getBytes();
  if (blob.getContentType() !== 'image/jpeg') woCommitFail_('WO_PHOTO_MIME_INVALID', 'MIME foto Drive tidak valid.');
  if (bytes.length !== prepared.bytes.length) woCommitFail_('WO_PHOTO_SIZE_MISMATCH', 'Ukuran foto Drive tidak cocok.');
  if (digestBytes_(bytes) !== prepared.digest) woCommitFail_('WO_PHOTO_DIGEST_MISMATCH', 'Digest foto Drive tidak cocok.');
  return { fileId: file.getId(), name: file.getName(), url: file.getUrl(), digest: prepared.digest, bytes: bytes.length };
}

function woCommitPreparePhoto_(normalized, folderPathValue, code) {
  var encoded = normalized['foto sesudah base64'] || normalized.fotosesudahbase64;
  if (!encoded) return null;
  var prepared = preparePhoto_(encoded, 'Foto Sesudah');
  var uploaded = putPhotoIdempotent_(folderPath_(folderPathValue), code, prepared);
  return { prepared: prepared, uploaded: uploaded, receipt: woCommitVerifyPhoto_(uploaded, prepared) };
}

function woCommitReceipt_(item, expected, photo) {
  var suppliedDigest = String(item.normalized.clientpayloaddigest || '').trim().toLowerCase();
  var verifiedDigest = receiptPayloadDigest_(item.normalized);
  if (!/^[a-f0-9]{64}$/.test(suppliedDigest) || suppliedDigest !== verifiedDigest) {
    woCommitFail_('SYNC_RECEIPT_MISMATCH', 'Digest receipt tidak cocok dengan data yang sudah diverifikasi.');
  }
  return {
    kodeWo: item.code,
    ulp: String(woVerifiedValue_(item.normalized, ['ULP']) || '').trim(),
    tanggal: String(woVerifiedValue_(item.normalized, ['Tanggal Pekerjaan', 'Tanggal']) || '').trim(),
    payloadDigest: verifiedDigest,
    photo: photo ? photo.receipt : null,
    committed: true
  };
}

function syncWoCoreCommitted_(token, mode, sheetName, rows) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woCoreAccess_(auth.sesi, mode);
  if (!access.success) return access;
  if (!Array.isArray(rows) || rows.length > 100) return fail_('BATCH_INVALID', 'Maksimal 100 WO per sinkronisasi.');

  var source = woCoreSheet_(sheetName);
  var sheet = source.sheet;
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);
  var created = [];
  try {
    var values = sheet.getDataRange().getDisplayValues();
    if (values.length < 2) return fail_('WO_NOT_FOUND', 'Data WO kosong.');
    var headers = values[0].map(function (value) { return String(value).trim(); });
    var targets = woVerifiedPrepareTargets_(auth.sesi, values, headers, rows);
    var receipts = [];

    for (var i = 0; i < targets.prepared.length; i++) {
      var item = targets.prepared[i];
      var normalized = item.normalized;
      var index = targets.index;
      var targetRow = item.rowIndex + 1;
      var expected = woCommitExpected_(headers, normalized);
      var existingFolder = index['folder path'] !== undefined ? values[item.rowIndex][index['folder path']] : '';
      var folderPathValue = normalized['folder path'] || existingFolder || ('Kopitiam/WO/' + safePath_(access.kodeUlp) + '/' + safePath_(item.code) + '/');
      normalized['folder path'] = folderPathValue;
      if (index['folder path'] !== undefined) expected['folder path'] = folderPathValue;

      var finished = woCommitCanonical_(normalized['status wo']) === 'selesai';
      var photo = woCommitPreparePhoto_(normalized, folderPathValue, item.code);
      if (finished && !photo) woCommitFail_('WO_PHOTO_REQUIRED', item.code + ': Foto Sesudah wajib sebelum status Selesai.');
      if (photo) {
        created.push(photo.uploaded);
        var cleanPath = String(folderPathValue).replace(/[\/\\]+$/, '');
        normalized['foto sesudah'] = cleanPath + '\\' + photo.receipt.name;
        normalized['link foto sesudah'] = photo.receipt.url;
        if (index['foto sesudah'] === undefined || index['link foto sesudah'] === undefined) woCommitFail_('WO_PHOTO_COLUMNS_MISSING', 'Kolom foto/link Drive tidak tersedia.');
        expected['foto sesudah'] = normalized['foto sesudah'];
        expected['link foto sesudah'] = normalized['link foto sesudah'];
      }

      var statusValue = expected['status wo'];
      delete expected['status wo'];
      Object.keys(expected).forEach(function (key) {
        if (WO_CORE_MUTABLE[mode].indexOf(key) >= 0) {
          sheet.getRange(targetRow, index[key] + 1).setValue(safeCell_(expected[key]));
        }
      });
      SpreadsheetApp.flush();
      woCommitVerifyRow_(sheet, targetRow, headers, expected);
      if (statusValue !== undefined) {
        if (WO_CORE_MUTABLE[mode].indexOf('status wo') < 0) woCommitFail_('WO_STATUS_NOT_WRITABLE', 'Status WO tidak dapat ditulis.');
        sheet.getRange(targetRow, index['status wo'] + 1).setValue(safeCell_(statusValue));
        SpreadsheetApp.flush();
        expected['status wo'] = statusValue;
        woCommitVerifyRow_(sheet, targetRow, headers, expected);
      }
      if (photo) woCommitVerifyPhoto_(photo.uploaded, photo.prepared);
      receipts.push(woCommitReceipt_(item, expected, photo));
    }
    return { success: true, accepted: receipts.map(function (r) { return r.kodeWo; }), receipts: receipts, diproses: receipts.length, diperbarui: receipts.length, ditambahkan: 0 };
  } catch (error) {
    console.error('WO commit guard:', error && error.stack ? error.stack : error);
    rollbackCreatedPhotos_(created);
    return fail_(error.woCommitCode || error.woCode || 'WO_COMMIT_FAILED', error.message || 'Verifikasi commit WO gagal.');
  } finally {
    lock.releaseLock();
  }
}

function syncHarCommitted_(token, mode, rows) {
  if (!Array.isArray(rows) || !rows.length) return fail_('BATCH_INVALID', 'Data WO wajib diisi.');
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  if (!harAllowed_(auth.sesi, mode)) return fail_('HAR_ACCESS_DENIED', 'Akses WO Har ditolak.');
  var sheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(mode === 'jar' ? CONFIG.WO_HAR_JAR_SHEET : CONFIG.WO_HAR_DU_SHEET);
  if (!sheet) return fail_('SHEET_NOT_FOUND', 'Sheet WO Har tidak ditemukan.');
  var before = sheet.getDataRange().getDisplayValues();
  var headers = (before[0] || []).map(function (value) { return String(value).trim(); });
  var created = [];
  try {
    var targets = woVerifiedPrepareTargets_(auth.sesi, before, headers, rows);
    var photos = {};
    targets.prepared.forEach(function (item) {
      var index = targets.index;
      var folderValue = item.normalized['folder path'] || before[item.rowIndex][index['folder path']] || '';
      var photo = woCommitPreparePhoto_(item.normalized, folderValue, item.code);
      if (woCommitCanonical_(item.normalized['status wo']) === 'selesai' && !photo) woCommitFail_('WO_PHOTO_REQUIRED', item.code + ': Foto Sesudah wajib sebelum status Selesai.');
      if (photo) { created.push(photo.uploaded); photos[item.code] = photo; }
    });

    var result = rows[0] && rows[0].schemaVersion === 2 ? syncHarVerified_(token, mode, rows) : syncHarLegacySecure_(token, mode, rows);
    if (!result || result.success !== true) return result;

    var receipts = [];
    var latest = sheet.getDataRange().getDisplayValues();
    targets.prepared.forEach(function (item) {
      var expected = woCommitExpected_(headers, item.normalized);
      var photo = photos[item.code] || null;
      if (photo) {
        var clean = String(item.normalized['folder path'] || latest[item.rowIndex][targets.index['folder path']] || '').replace(/[\/\\]+$/, '');
        expected['foto sesudah'] = clean + '\\' + photo.receipt.name;
        expected['link foto sesudah'] = photo.receipt.url;
      }
      woCommitVerifyRow_(sheet, item.rowIndex + 1, headers, expected);
      if (photo) woCommitVerifyPhoto_(photo.uploaded, photo.prepared);
      receipts.push(woCommitReceipt_(item, expected, photo));
    });
    result.accepted = receipts.map(function (r) { return r.kodeWo; });
    result.receipts = receipts;
    result.diproses = receipts.length;
    return result;
  } catch (error) {
    console.error('Har commit guard:', error && error.stack ? error.stack : error);
    rollbackCreatedPhotos_(created);
    return fail_(error.woCommitCode || error.woCode || 'HAR_COMMIT_FAILED', error.message || 'Verifikasi commit Har gagal.');
  }
}
