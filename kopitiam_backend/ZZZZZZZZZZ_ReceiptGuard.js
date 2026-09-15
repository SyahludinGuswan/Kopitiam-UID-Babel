/* Receipt layer on top of the existing Sheet/Drive commit guard. */
var RECEIPT_EXCLUDED_KEYS_ = {
  'clientpayloaddigest': true,
  'clientphotodigest': true,
  'foto sesudah base64': true,
  'fotosesudahbase64': true,
  'foto sesudah': true,
  'link foto sesudah': true,
  'folder path': true,
  'jarak antar gardu ke petugas (wbp)': true,
  'jarak antar gardu ke petugas (lwbp)': true
};

function receiptConfigureTransport_() {
  WO_COMMIT_TRANSPORT_KEYS_.clientpayloaddigest = true;
  WO_COMMIT_TRANSPORT_KEYS_.clientphotodigest = true;
  WO_COMMIT_TRANSPORT_KEYS_.jobs = true;
  WO_COMMIT_TRANSPORT_KEYS_.materials = true;
}

function receiptCanonical_(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') {
    return isFinite(value) ? String(value) : '__invalid_number__';
  }
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (Array.isArray(value)) {
    return '[' + value.map(receiptCanonical_).join(',') + ']';
  }
  if (typeof value === 'object') {
    var objectKeys = Object.keys(value).map(normalize_).sort();
    return '{' + objectKeys.map(function (key) {
      var original = Object.keys(value).filter(function (candidate) {
        return normalize_(candidate) === key;
      })[0];
      return key + ':' + receiptCanonical_(value[original]);
    }).join(',') + '}';
  }
  var text = String(value).trim().replace(/\s+/g, ' ');
  var number = Number(text.replace(',', '.'));
  if (/^-?\d+(?:[.,]\d+)?$/.test(text) && isFinite(number)) {
    return String(number);
  }
  return text.toLowerCase();
}

function receiptPayloadDigest_(row) {
  var keys = Object.keys(row).map(normalize_).filter(function (key) {
    return !RECEIPT_EXCLUDED_KEYS_[key];
  }).sort();
  return sha256_(keys.map(function (key) {
    var original = Object.keys(row).filter(function (candidate) {
      return normalize_(candidate) === key;
    })[0];
    return key + '=' + receiptCanonical_(row[original]);
  }).join('\n'));
}

function receiptValidateRows_(rows) {
  if (!Array.isArray(rows) || !rows.length) {
    throw new Error('Data WO wajib diisi.');
  }
  return rows.map(function (row) {
    var copy = {};
    Object.keys(row || {}).forEach(function (key) { copy[key] = row[key]; });
    var supplied = String(copy.clientPayloadDigest || '').trim().toLowerCase();
    if (!/^[a-f0-9]{64}$/.test(supplied)) {
      woCommitFail_('SYNC_RECEIPT_REQUIRED', 'Digest snapshot final wajib tersedia.');
    }
    if (receiptPayloadDigest_(copy) !== supplied) {
      woCommitFail_('SYNC_RECEIPT_MISMATCH', 'Digest snapshot final tidak cocok.');
    }
    return copy;
  });
}

function receiptFinalize_(result, rows, photoRequired) {
  if (!result || result.success !== true || !Array.isArray(result.receipts)) {
    return result;
  }
  if (result.receipts.length !== rows.length) {
    return fail_('SYNC_RECEIPT_INCOMPLETE', 'Receipt server tidak lengkap.');
  }
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    var code = String(row['Kode WO'] || '').trim();
    var matches = result.receipts.filter(function (receipt) {
      return receipt && receipt.committed === true &&
        String(receipt.kodeWo || '').trim() === code;
    });
    if (matches.length !== 1) {
      return fail_('SYNC_RECEIPT_INCOMPLETE', 'Receipt WO tidak unik atau tidak ditemukan.');
    }
    var receipt = matches[0];
    receipt.payloadDigest = String(row.clientPayloadDigest).toLowerCase();
    var clientPhoto = String(row.clientPhotoDigest || '').trim().toLowerCase();
    if (photoRequired && !clientPhoto) {
      return fail_('SYNC_PHOTO_RECEIPT_REQUIRED', 'Digest foto wajib tersedia.');
    }
    if (clientPhoto) {
      if (!receipt.photo || !receipt.photo.fileId ||
          String(receipt.photo.digest || '').toLowerCase() !== clientPhoto) {
        return fail_('SYNC_PHOTO_RECEIPT_MISMATCH', 'Receipt foto tidak cocok.');
      }
    }
  }
  return result;
}

function syncWoNoPhotoReceipt_(token, mode, sheetName, rows) {
  receiptConfigureTransport_();
  var validated;
  try {
    validated = receiptValidateRows_(rows);
  } catch (error) {
    return fail_(error.woCommitCode || 'SYNC_RECEIPT_INVALID', error.message);
  }
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woCoreAccess_(auth.sesi, mode);
  if (!access.success) return access;
  var source = woCoreSheet_(sheetName);
  var sheet = source.sheet;
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    var values = sheet.getDataRange().getDisplayValues();
    var headers = values[0].map(function (value) { return String(value).trim(); });
    var targets = woVerifiedPrepareTargets_(auth.sesi, values, headers, validated);
    var receipts = [];
    for (var i = 0; i < targets.prepared.length; i++) {
      var item = targets.prepared[i];
      var expected = woCommitExpected_(headers, item.normalized);
      var status = expected['status wo'];
      delete expected['status wo'];
      Object.keys(expected).forEach(function (key) {
        if (WO_CORE_MUTABLE[mode].indexOf(key) >= 0) {
          sheet.getRange(item.rowIndex + 1, targets.index[key] + 1)
            .setValue(safeCell_(expected[key]));
        }
      });
      SpreadsheetApp.flush();
      woCommitVerifyRow_(sheet, item.rowIndex + 1, headers, expected);
      if (status !== undefined) {
        sheet.getRange(item.rowIndex + 1, targets.index['status wo'] + 1)
          .setValue(safeCell_(status));
        SpreadsheetApp.flush();
        expected['status wo'] = status;
        woCommitVerifyRow_(sheet, item.rowIndex + 1, headers, expected);
      }
      receipts.push({
        kodeWo: item.code,
        ulp: String(woVerifiedValue_(item.normalized, ['ULP']) || '').trim(),
        tanggal: String(woVerifiedValue_(item.normalized, ['Tanggal Pekerjaan', 'Tanggal']) || '').trim(),
        payloadDigest: String(item.incoming.clientPayloadDigest).toLowerCase(),
        photo: null,
        committed: true
      });
    }
    return {success: true, accepted: receipts.map(function (r) { return r.kodeWo; }), receipts: receipts, diproses: receipts.length};
  } catch (error) {
    return fail_(error.woCommitCode || error.woCode || 'WO_COMMIT_FAILED', error.message);
  } finally {
    lock.releaseLock();
  }
}

function syncWoInsduReceipt_(token, rows) {
  try {
    var validated = receiptValidateRows_(rows);
    for (var i = 0; i < validated.length; i++) {
      validateInsduJurusan_(validated[i]);
      validateInsduCoordinates_(validated[i]);
      validateInsduCapacity_(validated[i]);
      validateInsduMeasurements_(validated[i]);
    }
    var auth = cekSesi_(token);
    if (!auth.success) return auth;
    var source = woCoreSheet_(CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du');
    var calculated = insduApplyServerDistances_(auth.sesi, source.sheet, validated);
    ['kapasitas','jurusan terpasang','jurusan terpakai','koordinat penginputan wbp','waktu penginputan wbp','jarak antar gardu ke petugas (wbp)','koordinat penginputan lwbp','waktu penginputan lwbp','jarak antar gardu ke petugas (lwbp)'].forEach(function (header) {
      if (WO_CORE_MUTABLE.insdu.indexOf(header) < 0) WO_CORE_MUTABLE.insdu.push(header);
    });
    return syncWoNoPhotoReceipt_(token, 'insdu', CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du', calculated);
  } catch (error) {
    return fail_(error.insduCode || error.woCommitCode || error.woCode || 'INSDU_CONTRACT_INVALID', error.message);
  }
}

function syncWoPhotoReceipt_(token, mode, sheetName, rows) {
  receiptConfigureTransport_();
  var validated;
  try { validated = receiptValidateRows_(rows); }
  catch (error) { return fail_(error.woCommitCode || 'SYNC_RECEIPT_INVALID', error.message); }
  var result = syncWoCoreCommitted_(token, mode, sheetName, validated);
  return receiptFinalize_(result, validated, true);
}

function syncHarReceipt_(token, mode, rows) {
  receiptConfigureTransport_();
  var validated;
  try { validated = receiptValidateRows_(rows); }
  catch (error) { return fail_(error.woCommitCode || 'SYNC_RECEIPT_INVALID', error.message); }
  var result = syncHarCommitted_(token, mode, validated);
  return receiptFinalize_(result, validated, true);
}
