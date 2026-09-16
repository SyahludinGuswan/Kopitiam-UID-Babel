/* Shared WO context used by Temuan download and synchronization. */
function woContextMode_(session) {
  var team = normalize_(session.subTim || session.tim || '');
  var username = normalize_(session.username || '');
  var insjar = team.indexOf('inspeksi jaringan') >= 0 ||
    team.indexOf('insjar') >= 0 || username.indexOf('.insjar') >= 0;
  var insdu = team.indexOf('inspeksi gardu') >= 0 ||
    team.indexOf('insdu') >= 0 || username.indexOf('.insdu') >= 0;
  if (insjar && insdu) return fail_('WO_CONTEXT_AMBIGUOUS', 'Jenis parent WO akun ambigu.');
  if (insjar) return { success: true, mode: 'insjar', object: 'Jaringan', sheetName: CONFIG.WO_INSJAR_SHEET };
  if (insdu) return { success: true, mode: 'insdu', object: 'Gardu', sheetName: CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du' };
  return fail_('WO_CONTEXT_DENIED', 'Akun bukan Tim Inspeksi Jaringan atau Inspeksi Gardu.');
}

function woContext_(session, kodeWo, editable) {
  var resolved = woContextMode_(session);
  if (!resolved.success) return resolved;
  var access = woCoreAccess_(session, resolved.mode);
  if (!access.success) return access;

  kodeWo = safeText_(kodeWo, 100);
  if (!kodeWo) return fail_('WO_REQUIRED', 'Kode WO wajib diisi.');

  var source = woCoreSheet_(resolved.sheetName);
  var sheet = source.sheet;
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return fail_('WO_NOT_FOUND', 'WO parent tidak ditemukan.');

  var headers = values[0].map(function (value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  var codeIndex = index['kode wo'];
  var ulpCodeIndex = index['kode ulp'];
  var statusIndex = index['status wo'];
  if (codeIndex === undefined || ulpCodeIndex === undefined) {
    return fail_('WO_HEADERS_INVALID', 'Header Kode WO atau Kode ULP tidak ditemukan pada ' + resolved.sheetName + '.');
  }

  var matches = [];
  for (var row = 1; row < values.length; row++) {
    if (String(values[row][codeIndex] || '').trim() !== kodeWo) continue;
    if (normalizeCode_(values[row][ulpCodeIndex]) !== access.kodeUlp) continue;
    matches.push(row);
  }
  if (!matches.length) return fail_('WO_NOT_FOUND', 'WO parent tidak ditemukan untuk modul dan Kode ULP akun ini.');
  if (matches.length > 1) return fail_('WO_PARENT_AMBIGUOUS', 'WO parent ditemukan lebih dari satu kali pada modul yang sama.');

  var target = matches[0];
  var status = statusIndex === undefined ? '' : normalize_(values[target][statusIndex]);
  if (editable && status === 'selesai') {
    return fail_('WO_LOCKED', 'WO sudah selesai dan hanya dapat dilihat.');
  }
  return {
    success: true,
    sheet: sheet,
    sheetName: resolved.sheetName,
    mode: resolved.mode,
    object: resolved.object,
    headers: headers,
    index: index,
    row: values[target],
    rowNumber: target + 1,
    status: status,
    kodeUlp: access.kodeUlp,
  };
}

function getTemuanInspeksi_(token, kodeWo) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var context = woContext_(auth.sesi, kodeWo, false);
  if (!context.success) return context;

  var sheet = temuanSheet_();
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return { success: true, total: 0, rows: [] };
  var headers = values[0].map(function (value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  if (index['kode wo'] === undefined || index['kode ulp'] === undefined || index['jenis object'] === undefined) {
    return fail_('SHEET_HEADERS_INVALID', 'Header Kode WO, Kode ULP, atau Jenis Object pada Inp_Temuan belum valid.');
  }

  var rows = [];
  for (var row = 1; row < values.length; row++) {
    if (String(values[row][index['kode wo']] || '').trim() !== String(kodeWo).trim()) continue;
    if (normalizeCode_(values[row][index['kode ulp']]) !== context.kodeUlp) continue;
    if (normalize_(values[row][index['jenis object']]) !== normalize_(context.object)) continue;
    rows.push(rowObject_(headers, values[row]));
  }
  return { success: true, total: rows.length, parentMode: context.mode, rows: rows };
}
