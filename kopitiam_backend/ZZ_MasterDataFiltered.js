/* Final runtime master handlers. */
function masterObjectCategory_(value) {
  var normalized = normalize_(value);
  if (normalized.indexOf('gardu') >= 0 || normalized.indexOf('trafo') >= 0 || normalized.indexOf('insdu') >= 0) return 'gardu';
  if (normalized.indexOf('jaringan') >= 0 || normalized.indexOf('insjar') >= 0 || normalized.indexOf('jtm') >= 0 || normalized.indexOf('jtr') >= 0 || normalized.indexOf('saluran') >= 0 || normalized.indexOf('line') >= 0) return 'jaringan';
  return normalized;
}

function masterObjectForSession_(session) {
  var identity = normalize_((session.subTim || session.tim || '') + ' ' + (session.username || ''));
  if (identity.indexOf('inspeksi jaringan') >= 0 || identity.indexOf('insjar') >= 0) return 'jaringan';
  if (identity.indexOf('inspeksi gardu') >= 0 || identity.indexOf('insdu') >= 0) return 'gardu';
  return '';
}

function masterTemuanObject_(headers, row) {
  var index = headerIndex_(headers);
  var column = index['objek inspeksi'];
  if (column === undefined) column = index['object inspeksi'];
  if (column === undefined) column = index['jenis object'];
  if (column === undefined) column = index['jenis objek'];
  return column === undefined ? '' : masterObjectCategory_(row[column]);
}

function masterScopeValue_(session, field) {
  if (field === 'kode ulp') return normalizeCode_(session.kodeUlp);
  if (field === 'ulp') return normalize_(session.ulp);
  if (field === 'kode up3') return normalizeCode_(session.kodeUp3);
  if (field === 'up3') return normalize_(session.up3);
  if (field === 'kode uiw') return normalizeCode_(session.kodeUiw);
  if (field === 'uiw') return normalize_(session.uiw);
  return '';
}

function masterScopeFields_(headers) {
  var index = headerIndex_(headers), fields = [];
  [['kode ulp', 'kode ulp'], ['ulp', 'ulp'], ['kode up3', 'kode up3'], ['up3', 'up3'], ['kode uiw', 'kode uiw'], ['uiw', 'uiw']].forEach(function (pair) {
    if (index[pair[0]] !== undefined) fields.push({ key: pair[0], column: index[pair[0]] });
  });
  return fields;
}

function masterRowMatchesSession_(headers, row, session) {
  var fields = masterScopeFields_(headers);
  if (!fields.length) return true;
  var hasScopedValue = false;
  for (var i = 0; i < fields.length; i++) {
    var rowValue = normalize_(row[fields[i].column]);
    if (!rowValue) continue;
    hasScopedValue = true;
    var expected = masterScopeValue_(session, fields[i].key);
    if (!expected) return false;
    var comparableRow = fields[i].key.indexOf('kode ') === 0 ? normalizeCode_(row[fields[i].column]) : rowValue;
    if (comparableRow !== expected) return false;
  }
  return hasScopedValue;
}

function masterRows_(sheet, name, session, targetObject) {
  var values = sheet.getDataRange().getDisplayValues();
  var headers = values.length ? values[0].map(function (value) {
    return String(value).trim();
  }) : [];
  var rows = [];
  var username = normalize_(session.username);
  for (var row = 1; row < values.length; row++) {
    if (name === CONFIG.USERS_SHEET && normalize_(values[row][USER_COL.username]) !== username) continue;
    if (name !== CONFIG.USERS_SHEET && !masterRowMatchesSession_(headers, values[row], session)) continue;
    if (name === 'Master_Temuan' && targetObject) {
      var rowObject = masterTemuanObject_(headers, values[row]);
      if (!rowObject || rowObject !== targetObject) continue;
    }
    var item = {};
    var hasValue = false;
    for (var column = 0; column < headers.length; column++) {
      var key = headers[column] || 'kolom_' + (column + 1);
      if (name === CONFIG.USERS_SHEET && normalize_(key) === 'password') continue;
      item[key] = values[row][column];
      if (values[row][column] !== '') hasValue = true;
    }
    if (hasValue) rows.push(item);
  }
  return rows;
}

function getMasterData_(token) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var targetObject = masterObjectForSession_(auth.sesi);
  var spreadsheet = getSpreadsheet_();
  var datasets = {};
  var total = 0;
  for (var i = 0; i < CONFIG.MASTER_SHEETS.length; i++) {
    var name = CONFIG.MASTER_SHEETS[i];
    if (name === 'Master_Gardu') {
      datasets[name] = [];
      continue;
    }
    var sheet = spreadsheet.getSheetByName(name);
    if (!sheet) return fail_('MASTER_SHEET_MISSING', 'Data master belum tersedia: ' + name);
    var rows = masterRows_(sheet, name, auth.sesi, targetObject);
    datasets[name] = rows;
    total += rows.length;
  }
  return {
    success: true,
    part: 'general',
    generatedAt: new Date().toISOString(),
    masterTemuanObject: targetObject,
    total: total,
    datasets: datasets,
  };
}

function getMasterGardu_(token) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var spreadsheet = getSpreadsheet_();
  var sheet = spreadsheet.getSheetByName('Master_Gardu');
  if (!sheet) return fail_('MASTER_SHEET_MISSING', 'Master_Gardu tidak tersedia.');
  var rows = masterRows_(sheet, 'Master_Gardu', auth.sesi, '');
  return {
    success: true,
    part: 'gardu',
    generatedAt: new Date().toISOString(),
    total: rows.length,
    rows: rows,
  };
}
