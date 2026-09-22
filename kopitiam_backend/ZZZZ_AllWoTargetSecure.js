/* Final write-target verification for every WO module.
 * Kode WO + ULP + Tanggal Pekerjaan/Tanggal must match on the same row.
 */
function woVerifiedFail_(code, message) {
  var error = new Error(message);
  error.woCode = code;
  throw error;
}

function woVerifiedText_(value) {
  return normalize_(String(value == null ? '' : value).replace(/\s+/g, ' '));
}

function woVerifiedPayload_(row) {
  var normalized = {};
  for (var key in row) {
    if (Object.prototype.hasOwnProperty.call(row, key)) normalized[normalize_(key)] = row[key];
  }
  return normalized;
}

function woVerifiedValue_(normalized, names) {
  for (var i = 0; i < names.length; i++) {
    var key = normalize_(names[i]);
    if (normalized[key] !== undefined && String(normalized[key]).trim() !== '') return normalized[key];
  }
  return '';
}

function woVerifiedColumn_(index, names) {
  for (var i = 0; i < names.length; i++) {
    var column = index[normalize_(names[i])];
    if (column !== undefined) return column;
  }
  return -1;
}

var WO_POLICY_MUTABLE_ = {
  insjar: ['koordinat awal', 'koordinat akhir', 'realisasi kms', 'waktu mulai', 'waktu selesai', 'durasi pekerjaan', 'status wo'],
  row: ['status wo', 'tindak lanjut', 'ukuran diamter batan (cm)', 'ukuran diameter batang (cm)', 'jenis tebangan', 'jenis pekerjaan', 'foto sesudah', 'link foto sesudah', 'waktu realisasi', 'user input', 'waktu input', 'folder path'],
  insdu: ['beban utama r (a) wbp', 'beban utama s (a) wbp', 'beban utama t (a) wbp', 'beban jurusan n (a) wbp', 'tegangan r-s (v) wbp', 'tegangan s-t (v) wbp', 'tegangan r-t (v) wbp', 'tegangan r-n (v) wbp', 'tegangan s-n (v) wbp', 'tegangan t-n (v) wbp', 'beban utama r (a) lwbp', 'beban utama s (a) lwbp', 'beban utama t (a) lwbp', 'beban jurusan n (a) lwbp', 'tegangan r-s (v) lwbp', 'tegangan s-t (v) lwbp', 'tegangan r-t (v) lwbp', 'tegangan r-n (v) lwbp', 'tegangan s-n (v) lwbp', 'tegangan t-n (v) lwbp', 'cover fco atas', 'cover fco bawah', 'cover bushing tm', 'cover bushing tr', 'cover arrester', 'jumperan atas', 'jumperan bawah', 'waktu mulai', 'waktu selesai', 'durasi pekerjaan', 'status wo', 'kapasitas', 'jurusan terpasang', 'jurusan terpakai', 'koordinat penginputan wbp', 'waktu penginputan wbp', 'jarak antar gardu ke petugas (wbp)', 'koordinat penginputan lwbp', 'waktu penginputan lwbp', 'jarak antar gardu ke petugas (lwbp)'],
  har: ['koordinat', 'lat', 'long', 'foto sesudah', 'link foto sesudah', 'catatan petugas', 'status wo', 'waktu mulai', 'waktu selesai', 'durasi', 'user input', 'waktu input', 'folder path']
};

var WO_POLICY_TRANSPORT_ = {
  'clientpayloaddigest': true, 'clientphotodigest': true, 'foto sesudah base64': true,
  'fotosesudahbase64': true, 'schemaversion': true, 'jobs': true, 'materials': true,
  'module': true
};

function woPolicyMode_(headers, existing, normalized, index) {
  var type = woVerifiedText_(normalized['jenis wo'] || (index['jenis wo'] === undefined ? '' : existing[index['jenis wo']]));
  if (type.indexOf('har ') >= 0 || index['catatan petugas'] !== undefined) return 'har';
  if (index['tindak lanjut'] !== undefined || index['jenis tebangan'] !== undefined) return 'row';
  if (index.kapasitas !== undefined || index['beban utama r (a) wbp'] !== undefined || type.indexOf('gardu') >= 0) return 'insdu';
  return 'insjar';
}

function woPolicyStatus_(value) {
  var status = woVerifiedText_(value);
  if (!status || ['menunggu', 'belum dikerjakan', 'to do', 'todo', 'open'].indexOf(status) >= 0) return 'open';
  if (['progress pekerjaan', 'progress', 'in progress'].indexOf(status) >= 0) return 'progress';
  if (['selesai', 'done', 'complete', 'completed'].indexOf(status) >= 0) return 'done';
  return 'invalid';
}

function woPolicyValidate_(session, headers, index, existing, normalized) {
  var mode = woPolicyMode_(headers, existing, normalized, index);
  var mutable = WO_POLICY_MUTABLE_[mode];
  var teamColumn = index['tim eksekusi'];
  var assignment = teamColumn === undefined ? '' : woVerifiedText_(existing[teamColumn]);
  if (mode === 'row' && assignment && assignment !== woVerifiedText_(session.subTim || session.tim)) {
    woVerifiedFail_('WO_ASSIGNMENT_DENIED', 'WO ROW bukan penugasan tim akun ini.');
  }
  if (mode === 'har' && assignment && assignment !== woVerifiedText_(session.username)) {
    woVerifiedFail_('WO_ASSIGNMENT_DENIED', 'WO Har bukan penugasan username ini.');
  }

  if (normalized['status wo'] !== undefined) {
    var statusColumn = index['status wo'];
    if (statusColumn === undefined) woVerifiedFail_('WO_STATUS_COLUMN_MISSING', 'Kolom Status WO tidak tersedia.');
    var current = woPolicyStatus_(existing[statusColumn]);
    var requested = woPolicyStatus_(normalized['status wo']);
    if (requested === 'invalid' || requested === 'open' ||
        (current === 'done' && requested !== 'done') ||
        (current === 'progress' && requested === 'open')) {
      woVerifiedFail_('WO_STATUS_TRANSITION_DENIED', 'Transisi Status WO tidak diizinkan.');
    }
  }

  Object.keys(normalized).forEach(function (key) {
    if (WO_POLICY_TRANSPORT_[key] || mutable.indexOf(key) >= 0) return;
    var column = index[key];
    if (column === undefined) return;
    if (woVerifiedText_(existing[column]) !== woVerifiedText_(normalized[key])) {
      woVerifiedFail_('WO_IMMUTABLE_FIELD', 'Field WO tidak boleh berubah: ' + headers[column] + '.');
    }
  });
  return mode;
}

function woVerifiedPrepareTargets_(session, values, headers, rows) {
  var index = headerIndex_(headers);
  var codeColumn = woVerifiedColumn_(index, ['Kode WO']);
  var ulpColumn = woVerifiedColumn_(index, ['ULP']);
  var dateColumn = woVerifiedColumn_(index, ['Tanggal Pekerjaan', 'Tanggal']);
  if (codeColumn < 0 || ulpColumn < 0 || dateColumn < 0) {
    woVerifiedFail_('WO_HEADERS_INVALID', 'Kolom Kode WO, ULP, dan Tanggal Pekerjaan wajib tersedia.');
  }
  var sessionUlp = woVerifiedText_(session.ulp || '');
  if (!sessionUlp) woVerifiedFail_('ULP_MISSING', 'ULP akun belum terisi.');

  var selected = {};
  var prepared = [];
  for (var i = 0; i < rows.length; i++) {
    var incoming = rows[i] || {};
    var normalized = woVerifiedPayload_(incoming);
    var code = String(woVerifiedValue_(normalized, ['Kode WO']) || '').trim();
    var ulp = String(woVerifiedValue_(normalized, ['ULP']) || '').trim();
    var workDate = woVerifiedValue_(normalized, ['Tanggal Pekerjaan', 'Tanggal']);
    if (!code || !ulp || !String(workDate || '').trim()) {
      woVerifiedFail_('WO_TARGET_INCOMPLETE', 'Kode WO, ULP, dan Tanggal Pekerjaan wajib diisi.');
    }
    if (woVerifiedText_(ulp) !== sessionUlp) {
      woVerifiedFail_('WO_ULP_DENIED', 'ULP WO tidak cocok dengan ULP akun.');
    }

    var matches = [];
    for (var row = 1; row < values.length; row++) {
      if (woVerifiedText_(values[row][codeColumn]) === woVerifiedText_(code) &&
          woVerifiedText_(values[row][ulpColumn]) === woVerifiedText_(ulp) &&
          woVerifiedText_(values[row][dateColumn]) === woVerifiedText_(workDate)) {
        matches.push(row);
      }
    }
    if (!matches.length) woVerifiedFail_('WO_NOT_FOUND', 'WO tidak ditemukan untuk Kode WO, ULP, dan Tanggal Pekerjaan tersebut.');
    if (matches.length > 1) woVerifiedFail_('WO_TARGET_AMBIGUOUS', 'Ditemukan lebih dari satu baris dengan Kode WO, ULP, dan Tanggal Pekerjaan yang sama.');
    if (selected[matches[0]]) woVerifiedFail_('WO_TARGET_DUPLICATE', 'Satu baris WO tidak boleh dikirim dua kali dalam satu batch.');
    woPolicyValidate_(session, headers, index, values[matches[0]], normalized);
    selected[matches[0]] = true;
    prepared.push({ incoming: incoming, normalized: normalized, code: code, rowIndex: matches[0] });
  }
  return { index: index, prepared: prepared };
}

function syncWoCoreVerified_(token, mode, sheetName, rows) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woCoreAccess_(auth.sesi, mode);
  if (!access.success) return access;
  if (!Array.isArray(rows) || rows.length > 100) return fail_('BATCH_INVALID', 'Maksimal 100 WO per sinkronisasi.');

  var source = woCoreSheet_(sheetName);
  var sheet = source.sheet;
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var values = sheet.getDataRange().getDisplayValues();
    if (values.length < 2) return fail_('WO_NOT_FOUND', 'Data WO kosong.');
    var headers = values[0].map(function (value) { return String(value).trim(); });
    var targets = woVerifiedPrepareTargets_(auth.sesi, values, headers, rows);
    var index = targets.index;
    var done = 0;

    for (var i = 0; i < targets.prepared.length; i++) {
      var item = targets.prepared[i];
      var normalized = item.normalized;
      var target = item.rowIndex;
      var existingFolderPath = index['folder path'] !== undefined ? values[target][index['folder path']] : '';
      var folderPathValue = normalized['folder path'] || existingFolderPath || ('Kopitiam/WO/' + safePath_(access.kodeUlp) + '/' + safePath_(item.code) + '/');
      normalized['folder path'] = folderPathValue;

      var photoBase64 = normalized['foto sesudah base64'] || normalized['fotosesudahbase64'];
      if (photoBase64) {
        try {
          var uploaded = uploadWoPhoto_(folderPathValue, item.code, photoBase64, 'Foto Sesudah');
          if (uploaded) {
            var cleanPath = String(folderPathValue || '').replace(/[\/\\]+$/, '');
            normalized['foto sesudah'] = cleanPath + '\\' + uploaded.name;
            normalized['link foto sesudah'] = uploaded.url;
          }
        } catch (photoError) {
          console.error('Upload foto sesudah gagal:', photoError);
        }
      } else if (normalized['foto sesudah']) {
        var rawName = String(normalized['foto sesudah']).trim();
        if (rawName && rawName.indexOf('\\') < 0 && rawName.indexOf('/') < 0) {
          var cleanFolder = String(folderPathValue || '').replace(/[\/\\]+$/, '');
          normalized['foto sesudah'] = cleanFolder + '\\' + rawName;
        }
      }

      for (var column = 0; column < headers.length; column++) {
        var header = normalize_(headers[column]);
        if (WO_CORE_MUTABLE[mode].indexOf(header) >= 0 && normalized[header] !== undefined) {
          sheet.getRange(target + 1, column + 1).setValue(safeCell_(normalized[header]));
        }
      }
      done++;
    }
    SpreadsheetApp.flush();
    return { success: true, diproses: done, diperbarui: done, ditambahkan: 0 };
  } catch (error) {
    console.error('Verified WO sync:', error.message);
    return fail_(error.woCode || 'WO_SYNC_FAILED', error.message);
  } finally {
    lock.releaseLock();
  }
}

function syncHarVerified_(token, mode, rows) {
  if (!Array.isArray(rows) || !rows.length) return fail_('BATCH_INVALID', 'Data WO wajib diisi.');
  if (rows[0] && rows[0].schemaVersion === 2) {
    var auth = cekSesi_(token);
    if (!auth.success) return auth;
    if (!harAllowed_(auth.sesi, mode)) return fail_('HAR_ACCESS_DENIED', 'Akses WO Har ditolak.');
    var spreadsheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
    var sheet = spreadsheet.getSheetByName(mode === 'jar' ? CONFIG.WO_HAR_JAR_SHEET : CONFIG.WO_HAR_DU_SHEET);
    if (!sheet) return fail_('SHEET_NOT_FOUND', 'Sheet WO Har tidak ditemukan.');
    var values = sheet.getDataRange().getDisplayValues();
    var headers = (values[0] || []).map(function (value) { return String(value).trim(); });
    try {
      var targets = woVerifiedPrepareTargets_(auth.sesi, values, headers, rows);
      var codeColumn = woVerifiedColumn_(targets.index, ['Kode WO']);
      var sameCode = 0;
      for (var r = 1; r < values.length; r++) {
        if (woVerifiedText_(values[r][codeColumn]) === woVerifiedText_(targets.prepared[0].code)) sameCode++;
      }
      if (sameCode > 1) {
        return fail_('WO_TARGET_AMBIGUOUS', 'Kode WO Har tidak unik. Sinkronisasi diblokir agar tidak menulis baris yang salah.');
      }
    } catch (error) {
      return fail_(error.woCode || 'HAR_SYNC_FAILED', error.message);
    }
    return syncHarExecution_(token, mode, rows);
  }
  return syncHarLegacySecure_(token, mode, rows);
}
