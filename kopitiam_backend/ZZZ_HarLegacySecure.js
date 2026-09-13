/* Secure compatibility handler for legacy Har payloads.
 * A writable target must match Kode WO + ULP + Tanggal on the same row.
 */
function harLegacyFail_(code, message) {
  var error = new Error(message);
  error.harCode = code;
  throw error;
}

function harLegacyDateKey_(value) {
  return normalize_(String(value == null ? '' : value).replace(/\s+/g, ' '));
}

function harLegacyPayload_(row) {
  var normalized = {};
  for (var key in row) {
    if (Object.prototype.hasOwnProperty.call(row, key)) {
      normalized[normalize_(key)] = row[key];
    }
  }
  return normalized;
}

function harLegacyHeaderColumn_(index, names) {
  for (var i = 0; i < names.length; i++) {
    var position = index[normalize_(names[i])];
    if (position !== undefined) return position;
  }
  return -1;
}

function harLegacyPayloadValue_(payload, names) {
  for (var i = 0; i < names.length; i++) {
    var key = normalize_(names[i]);
    if (payload[key] !== undefined && String(payload[key]).trim() !== '') {
      return payload[key];
    }
  }
  return '';
}

function syncHarLegacySecure_(token, mode, rows) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woHarAccess_(auth.sesi, mode);
  if (!access.success) return access;
  if (!Array.isArray(rows) || rows.length > 100) {
    return fail_('BATCH_INVALID', 'Maksimal 100 WO.');
  }

  var sessionUlp = normalize_(auth.sesi.ulp || '');
  if (!sessionUlp) {
    return fail_('ULP_MISSING', 'ULP akun belum terisi.');
  }

  var sheetName = mode === 'jar' ? CONFIG.WO_HAR_JAR_SHEET : CONFIG.WO_HAR_DU_SHEET;
  var sheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(sheetName);
  if (!sheet) return fail_('SHEET_NOT_FOUND', 'Sheet ' + sheetName + ' tidak ditemukan.');

  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var values = sheet.getDataRange().getDisplayValues();
    if (values.length < 2) return fail_('DATA_EMPTY', 'Sheet data kosong.');
    var headers = values[0].map(function (value) { return String(value).trim(); });
    var index = headerIndex_(headers);
    var codeColumn = harLegacyHeaderColumn_(index, ['Kode WO']);
    var ulpColumn = harLegacyHeaderColumn_(index, ['ULP']);
    var dateColumn = harLegacyHeaderColumn_(index, ['Tanggal Pekerjaan', 'Tanggal']);
    if (codeColumn < 0 || ulpColumn < 0 || dateColumn < 0) {
      return fail_('HAR_HEADERS_INVALID', 'Kolom Kode WO, ULP, dan Tanggal Pekerjaan wajib tersedia.');
    }

    var prepared = [];
    var selectedRows = {};
    for (var i = 0; i < rows.length; i++) {
      var input = rows[i] || {};
      var payload = harLegacyPayload_(input);
      var code = String(harLegacyPayloadValue_(payload, ['Kode WO']) || '').trim();
      var ulp = String(harLegacyPayloadValue_(payload, ['ULP']) || '').trim();
      var workDate = harLegacyPayloadValue_(payload, ['Tanggal Pekerjaan', 'Tanggal']);
      if (!code || !ulp || !String(workDate || '').trim()) {
        harLegacyFail_('HAR_TARGET_INCOMPLETE', 'Kode WO, ULP, dan Tanggal Pekerjaan wajib diisi.');
      }
      if (normalize_(ulp) !== sessionUlp) {
        harLegacyFail_('HAR_ULP_DENIED', 'ULP WO tidak cocok dengan ULP akun.');
      }

      var matches = [];
      for (var r = 1; r < values.length; r++) {
        var sameCode = normalize_(values[r][codeColumn]) === normalize_(code);
        var sameUlp = normalize_(values[r][ulpColumn]) === normalize_(ulp);
        var sameDate = harLegacyDateKey_(values[r][dateColumn]) === harLegacyDateKey_(workDate);
        if (sameCode && sameUlp && sameDate) matches.push(r);
      }
      if (!matches.length) {
        harLegacyFail_('WO_NOT_FOUND', 'WO tidak ditemukan untuk Kode WO, ULP, dan Tanggal Pekerjaan tersebut.');
      }
      if (matches.length > 1) {
        harLegacyFail_('WO_TARGET_AMBIGUOUS', 'Ditemukan lebih dari satu baris dengan Kode WO, ULP, dan Tanggal Pekerjaan yang sama.');
      }
      if (selectedRows[matches[0]]) {
        harLegacyFail_('WO_TARGET_DUPLICATE', 'Satu baris WO tidak boleh dikirim dua kali dalam satu batch.');
      }
      selectedRows[matches[0]] = true;
      prepared.push({ payload: payload, code: code, rowIndex: matches[0] });
    }

    var done = 0;
    for (var p = 0; p < prepared.length; p++) {
      var item = prepared[p];
      var targetRow = item.rowIndex + 1;
      var normalizedPayload = item.payload;
      var existingFolder = index['folder path'] !== undefined ? values[item.rowIndex][index['folder path']] : '';
      var folderPathValue = normalizedPayload['folder path'] || existingFolder || ('Kopitiam/WO_HAR/' + safePath_(auth.sesi.kodeUlp || '') + '/' + safePath_(item.code) + '/');
      normalizedPayload['folder path'] = folderPathValue;

      var photoBase64 = normalizedPayload['foto sesudah base64'] || normalizedPayload['fotosesudahbase64'];
      if (photoBase64) {
        try {
          var uploaded = uploadWoPhoto_(folderPathValue, item.code, photoBase64, 'Foto Sesudah');
          if (uploaded) {
            var cleanPath = String(folderPathValue || '').replace(/[\/\\]+$/, '');
            normalizedPayload['foto sesudah'] = cleanPath + '\\' + uploaded.name;
            normalizedPayload['link foto sesudah'] = uploaded.url;
          }
        } catch (photoError) {
          console.error('Upload foto har gagal:', photoError);
        }
      } else if (normalizedPayload['foto sesudah']) {
        var rawName = String(normalizedPayload['foto sesudah']).trim();
        if (rawName && rawName.indexOf('\\') < 0 && rawName.indexOf('/') < 0) {
          var cleanFolderPath = String(folderPathValue || '').replace(/[\/\\]+$/, '');
          normalizedPayload['foto sesudah'] = cleanFolderPath + '\\' + rawName;
        }
      }

      for (var c = 0; c < headers.length; c++) {
        var header = normalize_(headers[c]);
        if (WO_HAR_MUTABLE_HEADERS.indexOf(header) >= 0 && normalizedPayload[header] !== undefined) {
          sheet.getRange(targetRow, c + 1).setValue(safeCell_(normalizedPayload[header]));
        }
      }
      if (index['status wo'] !== undefined) {
        sheet.getRange(targetRow, index['status wo'] + 1).setValue('Selesai');
      }
      done++;
    }
    SpreadsheetApp.flush();
    return { success: true, diproses: done, diperbarui: done };
  } catch (error) {
    console.error('Secure legacy Har sync:', error.message);
    return fail_(error.harCode || 'HAR_SYNC_FAILED', error.message);
  } finally {
    lock.releaseLock();
  }
}
