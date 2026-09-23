/* Work-order handlers kept outside Code.js so adding new modules cannot erase stable flows. */
function woCoreSheet_(name) {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(name);
  if (!sheet) throw new Error('Sheet tidak ditemukan: ' + name);
  return { spreadsheet: spreadsheet, sheet: sheet };
}

function woCoreAccess_(session, mode) {
  var sub = normalize_(session.subTim || session.tim || '');
  var username = normalize_(session.username || '');
  var kodeUlp = normalizeCode_(session.kodeUlp || '');
  var ulp = normalize_(session.ulp || '');
  if (!kodeUlp) return fail_('ULP_MISSING', 'Kode ULP akun belum terisi.');
  if (mode === 'insjar' && sub.indexOf('inspeksi jaringan') < 0 && sub.indexOf('insjar') < 0 && username.indexOf('.insjar') < 0)
    return fail_('WO_ACCESS_DENIED', 'WO Inspeksi Jaringan hanya tersedia untuk Tim Inspeksi Jaringan.');
  if (mode === 'row' && sub.indexOf('row') < 0 && username.indexOf('.row') < 0)
    return fail_('ROW_ACCESS_DENIED', 'WO ROW hanya tersedia untuk Tim ROW.');
  if (mode === 'insdu' && sub.indexOf('inspeksi gardu') < 0 && sub.indexOf('insdu') < 0 && username.indexOf('.insdu') < 0)
    return fail_('INSDU_ACCESS_DENIED', 'WO Inspeksi Gardu hanya tersedia untuk Tim Inspeksi Gardu.');
  return { success: true, kodeUlp: kodeUlp, ulp: ulp, subTim: sub };
}

function woCoreReadRowWithRevision_(sourceSpreadsheetId, sourceSheet, kodeUlp, code, headers, values) {
  var item = rowObject_(headers, values);
  var metadata = revisionRead_(sourceSpreadsheetId, sourceSheet, revisionStableKey_([kodeUlp, code]));
  item._revision = metadata.revision;
  item._fingerprint = metadata.fingerprint;
  return item;
}

function woCoreGet_(token, mode, sheetName) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woCoreAccess_(auth.sesi, mode);
  if (!access.success) return access;
  var source = woCoreSheet_(sheetName);
  var sheet = source.sheet;
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return {
    success: true,
    total: 0,
    totalSheet: 0,
    sourceSpreadsheetId: source.spreadsheet.getId(),
    sourceSheet: sheet.getName(),
    rows: []
  };
  var headers = values[0].map(function (value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  if (index['kode wo'] === undefined || index['kode ulp'] === undefined)
    return fail_('WO_HEADERS_INVALID', 'Header Kode WO atau Kode ULP tidak ditemukan pada ' + sheetName + '.');
  var teamIndex = index['tim eksekusi'];
  var ulpIndex = index['ulp'];
  var rows = [];
  var sampleKodeUlp = '';
  var rejectedByUlp = 0;
  var rejectedByTeam = 0;
  for (var row = 1; row < values.length; row++) {
    if (!String(values[row][index['kode wo']] || '').trim()) continue;
    var rowKodeUlp = normalizeCode_(values[row][index['kode ulp']]);
    if (!sampleKodeUlp) sampleKodeUlp = rowKodeUlp;
    var code = String(values[row][index['kode wo']] || '').trim();
    var codeMatches = rowKodeUlp === access.kodeUlp;
    var nameMatches = ulpIndex !== undefined && access.ulp && normalize_(values[row][ulpIndex]) === access.ulp;
    if (!codeMatches && !nameMatches) {
      rejectedByUlp++;
      continue;
    }
    if (mode === 'row' && teamIndex !== undefined) {
      var rowTeam = normalize_(values[row][teamIndex]);
      if (rowTeam && rowTeam !== access.subTim) {
        rejectedByTeam++;
        continue;
      }
    }
    rows.push(woCoreReadRowWithRevision_(source.spreadsheet.getId(), sheet.getName(), access.kodeUlp, code, headers, values[row]));
  }
  return {
    success: true,
    total: rows.length,
    totalSheet: values.length - 1,
    kodeUlpFilter: access.kodeUlp,
    ulpFilter: access.ulp,
    sourceSpreadsheetId: source.spreadsheet.getId(),
    sourceSheet: sheet.getName(),
    sampleKodeUlp: sampleKodeUlp,
    rejectedByUlp: rejectedByUlp,
    rejectedByTeam: rejectedByTeam,
    rows: rows,
  };
}

function getWoInsjar_(token) {
  return woCoreGet_(token, 'insjar', CONFIG.WO_INSJAR_SHEET);
}
function getWoRow_(token) {
  return woCoreGet_(token, 'row', CONFIG.WO_ROW_SHEET);
}
function getWoInsdu_(token) {
  return woCoreGet_(token, 'insdu', CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du');
}

var WO_CORE_MUTABLE = {
  insjar: ['koordinat awal', 'koordinat akhir', 'realisasi kms', 'waktu mulai', 'waktu selesai', 'durasi pekerjaan', 'status wo'],
  row: ['status wo', 'tindak lanjut', 'ukuran diamter batan (cm)', 'ukuran diameter batang (cm)', 'jenis tebangan', 'jenis pekerjaan', 'foto sesudah', 'link foto sesudah', 'waktu realisasi', 'user input', 'waktu input', 'folder path'],
  insdu: ['beban utama r (a) wbp', 'beban utama s (a) wbp', 'beban utama t (a) wbp', 'beban jurusan n (a) wbp', 'tegangan r-s (v) wbp', 'tegangan s-t (v) wbp', 'tegangan r-t (v) wbp', 'tegangan r-n (v) wbp', 'tegangan s-n (v) wbp', 'tegangan t-n (v) wbp', 'beban utama r (a) lwbp', 'beban utama s (a) lwbp', 'beban utama t (a) lwbp', 'beban jurusan n (a) lwbp', 'tegangan r-s (v) lwbp', 'tegangan s-t (v) lwbp', 'tegangan r-t (v) lwbp', 'tegangan r-n (v) lwbp', 'tegangan s-n (v) lwbp', 'tegangan t-n (v) lwbp', 'cover fco atas', 'cover fco bawah', 'cover bushing tm', 'cover bushing tr', 'cover arrester', 'jumperan atas', 'jumperan bawah', 'waktu mulai', 'waktu selesai', 'durasi pekerjaan', 'status wo']
};

function uploadWoPhoto_(folderPathStr, code, base64Data, role) {
  if (!base64Data) return null;
  var prepared = preparePhoto_(base64Data, role);
  var folder = folderPath_(folderPathStr);
  return putPhotoIdempotent_(folder, code, prepared);
}

function woCoreSync_(token, mode, sheetName, rows) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woCoreAccess_(auth.sesi, mode);
  if (!access.success) return access;
  if (!Array.isArray(rows) || rows.length > 100) return fail_('BATCH_INVALID', 'Maksimal 100 WO per sinkronisasi.');
  var source = woCoreSheet_(sheetName);
  var sheet = source.sheet;
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return fail_('WO_NOT_FOUND', 'Data WO kosong.');
  var headers = values[0].map(function (value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var done = 0;
    for (var i = 0; i < rows.length; i++) {
      var incoming = rows[i] || {};
      var code = String(incoming['Kode WO'] || '').trim();
      var target = -1;
      for (var r = 1; r < values.length; r++) {
        if (String(values[r][index['kode wo']] || '').trim() === code && normalizeCode_(values[r][index['kode ulp']]) === access.kodeUlp) {
          target = r;
          break;
        }
      }
      if (target < 0) return fail_('WO_NOT_FOUND', 'WO tidak ditemukan: ' + code);
      var stableKey = revisionStableKey_([access.kodeUlp, code]);
      var revisionCheck = revisionAssertCurrent_(source.spreadsheet.getId(), sheet.getName(), stableKey, incoming);
      if (!revisionCheck.success) return revisionCheck;
      var normalized = {};
      for (var key in incoming) {
        if (Object.prototype.hasOwnProperty.call(incoming, key)) normalized[normalize_(key)] = incoming[key];
      }
      var existingFolderPath = index['folder path'] !== undefined ? values[target][index['folder path']] : '';
      var folderPathVal = normalized['folder path'] || existingFolderPath || ('Kopitiam/WO/' + safePath_(access.kodeUlp) + '/' + safePath_(code) + '/');
      normalized['folder path'] = folderPathVal;
      var b64Photo = normalized['foto sesudah base64'] || normalized['fotosesudahbase64'];
      if (b64Photo) {
        var uploaded = uploadWoPhoto_(folderPathVal, code, b64Photo, 'Foto Sesudah');
        if (!uploaded) throw new Error('PHOTO_UPLOAD_FAILED');
        var cleanPath = String(folderPathVal || '').replace(/[\/]+$/, '');
        normalized['foto sesudah'] = cleanPath + '\\' + uploaded.name;
        normalized['link foto sesudah'] = uploaded.url;
      } else if (normalized['foto sesudah']) {
        var rawName = String(normalized['foto sesudah']).trim();
        if (rawName && rawName.indexOf('\\') < 0 && rawName.indexOf('/') < 0) {
          var cleanFolderPath = String(folderPathVal || '').replace(/[\/]+$/, '');
          normalized['foto sesudah'] = cleanFolderPath + '\\' + rawName;
        }
      }
      var output = values[target].slice();
      for (var c = 0; c < headers.length; c++) {
        var header = normalize_(headers[c]);
        if (WO_CORE_MUTABLE[mode].indexOf(header) >= 0 && normalized[header] !== undefined) {
          output[c] = safeCell_(normalized[header]);
        }
      }
      revisionWriteChangedCells_(sheet, target + 1, headers, values[target], output, WO_CORE_MUTABLE[mode]);
      var committedRow = sheet.getRange(target + 1, 1, 1, headers.length).getValues()[0];
      revisionCommit_(source.spreadsheet.getId(), sheet.getName(), stableKey, committedRow, 'UPDATE', auth.sesi.username);
      done++;
    }
    SpreadsheetApp.flush();
    return { success: true, diproses: done, diperbarui: done, ditambahkan: 0 };
  } finally {
    lock.releaseLock();
  }
}

function syncWoInsjar_(token, rows) {
  return woCoreSync_(token, 'insjar', CONFIG.WO_INSJAR_SHEET, rows);
}
function syncWoRow_(token, rows) {
  return woCoreSync_(token, 'row', CONFIG.WO_ROW_SHEET, rows);
}
function syncWoInsdu_(token, rows) {
  return woCoreSync_(token, 'insdu', CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du', rows);
}
