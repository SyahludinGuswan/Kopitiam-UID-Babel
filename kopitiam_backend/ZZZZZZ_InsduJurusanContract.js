/* Insdu contract for Jurusan and WBP/LWBP capture coordinates. */
function insduContractError_(code, message) {
  var error = new Error(message);
  error.insduCode = code;
  throw error;
}

function insduJurusanInteger_(value, label) {
  var text = String(value == null ? '' : value).trim();
  if (!/^[1-4]$/.test(text)) {
    insduContractError_('INSDU_JURUSAN_RANGE_INVALID', label + ' wajib berupa bilangan bulat 1 sampai 4.');
  }
  return Number(text);
}

function validateInsduJurusan_(incoming) {
  var installed = insduJurusanInteger_(incoming['Jurusan Terpasang'], 'Jurusan Terpasang');
  var used = insduJurusanInteger_(incoming['Jurusan Terpakai'], 'Jurusan Terpakai');
  if (used > installed) {
    insduContractError_('INSDU_JURUSAN_RELATION_INVALID', 'Jurusan Terpakai harus sama dengan atau lebih kecil dari Jurusan Terpasang.');
  }
  return { installed: installed, used: used };
}

function insduCoordinate_(value, label) {
  var text = String(value == null ? '' : value).trim();
  var parts = text.split(',');
  if (parts.length !== 2) insduContractError_('INSDU_COORDINATE_INVALID', label + ' wajib berisi latitude,longitude.');
  var latitude = Number(parts[0].trim());
  var longitude = Number(parts[1].trim());
  if (!isFinite(latitude) || !isFinite(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 || (latitude === 0 && longitude === 0)) {
    insduContractError_('INSDU_COORDINATE_INVALID', label + ' tidak valid.');
  }
  return { latitude: latitude, longitude: longitude };
}

function insduCaptureTime_(value, label) {
  var text = String(value == null ? '' : value).trim();
  var match = /^(\d{2})\s+(Januari|Februari|Maret|April|Mei|Juni|Juli|Agustus|September|Oktober|November|Desember)\s+(\d{4}),\s+(\d{2}):(\d{2}):(\d{2})$/.exec(text);
  if (!match) {
    insduContractError_('INSDU_CAPTURE_TIME_INVALID', label + ' wajib memakai format dd MMMM yyyy, HH:mm:ss.');
  }
  var months = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
  var day = Number(match[1]), month = months.indexOf(match[2]), year = Number(match[3]);
  var hour = Number(match[4]), minute = Number(match[5]), second = Number(match[6]);
  var parsed = new Date(Date.UTC(year, month, day, hour, minute, second));
  if (month < 0 || year < 2000 || year > 2100 || hour > 23 || minute > 59 || second > 59 ||
      parsed.getUTCFullYear() !== year || parsed.getUTCMonth() !== month || parsed.getUTCDate() !== day ||
      parsed.getUTCHours() !== hour || parsed.getUTCMinutes() !== minute || parsed.getUTCSeconds() !== second) {
    insduContractError_('INSDU_CAPTURE_TIME_INVALID', label + ' bukan tanggal dan waktu yang valid.');
  }
  return text;
}

function insduCapture_(incoming, suffix) {
  var coordinateKey = 'Koordinat Penginputan ' + suffix;
  var timeKey = 'Waktu Penginputan ' + suffix;
  return {
    coordinate: insduCoordinate_(incoming[coordinateKey], coordinateKey),
    capturedAt: insduCaptureTime_(incoming[timeKey], timeKey)
  };
}

function validateInsduCoordinates_(incoming) {
  return { wbp: insduCapture_(incoming, 'WBP'), lwbp: insduCapture_(incoming, 'LWBP') };
}

function insduDistanceMeters_(from, to) {
  var radians = Math.PI / 180;
  var dLatitude = (to.latitude - from.latitude) * radians;
  var dLongitude = (to.longitude - from.longitude) * radians;
  var latitude1 = from.latitude * radians;
  var latitude2 = to.latitude * radians;
  var a = Math.sin(dLatitude / 2) * Math.sin(dLatitude / 2) +
    Math.cos(latitude1) * Math.cos(latitude2) * Math.sin(dLongitude / 2) * Math.sin(dLongitude / 2);
  return Math.round(6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 10) / 10;
}

function insduCentralCoordinate_(row) {
  var combined = String(row['Koordinat Gardu'] == null ? '' : row['Koordinat Gardu']).trim();
  if (combined) {
    try { return insduCoordinate_(combined, 'Koordinat Gardu'); } catch (_) {}
  }
  var latitude = Number(String(row.Lat == null ? '' : row.Lat).trim().replace(',', '.'));
  var longitude = Number(String(row.Long == null ? '' : row.Long).trim().replace(',', '.'));
  if (isFinite(latitude) && isFinite(longitude) && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180 && (latitude !== 0 || longitude !== 0)) {
    return { latitude: latitude, longitude: longitude };
  }
  return null;
}

function insduApplyServerDistances_(session, sheet, rows) {
  var values = sheet.getDataRange().getDisplayValues();
  var headers = (values[0] || []).map(function (value) { return String(value).trim(); });
  var targets = woVerifiedPrepareTargets_(session, values, headers, rows);
  return targets.prepared.map(function (target) {
    var incoming = {};
    Object.keys(target.incoming).forEach(function (key) { incoming[key] = target.incoming[key]; });
    var server = {};
    headers.forEach(function (header, column) { server[header] = values[target.rowIndex][column]; });
    var gardu = insduCentralCoordinate_(server);
    var captures = validateInsduCoordinates_(incoming);
    incoming['Jarak Antar Gardu ke Petugas (WBP)'] = gardu ? insduDistanceMeters_(gardu, captures.wbp.coordinate) : '';
    incoming['Jarak Antar Gardu ke Petugas (LWBP)'] = gardu ? insduDistanceMeters_(gardu, captures.lwbp.coordinate) : '';
    return incoming;
  });
}

function syncWoInsduContract_(token, rows) {
  if (!Array.isArray(rows) || rows.length > 100) return fail_('BATCH_INVALID', 'Maksimal 100 WO per sinkronisasi.');
  try {
    for (var i = 0; i < rows.length; i++) {
      validateInsduJurusan_(rows[i] || {});
      validateInsduCoordinates_(rows[i] || {});
    }
    var auth = cekSesi_(token);
    if (!auth.success) return auth;
    var access = woCoreAccess_(auth.sesi, 'insdu');
    if (!access.success) return access;
    var source = woCoreSheet_(CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du');
    var normalizedRows = insduApplyServerDistances_(auth.sesi, source.sheet, rows);
    [
      'jurusan terpasang', 'jurusan terpakai',
      'koordinat penginputan wbp', 'waktu penginputan wbp', 'jarak antar gardu ke petugas (wbp)',
      'koordinat penginputan lwbp', 'waktu penginputan lwbp', 'jarak antar gardu ke petugas (lwbp)'
    ].forEach(function (header) {
      if (WO_CORE_MUTABLE.insdu.indexOf(header) < 0) WO_CORE_MUTABLE.insdu.push(header);
    });
    return syncWoCoreCommitted_(token, 'insdu', CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du', normalizedRows);
  } catch (error) {
    return fail_(error.insduCode || error.woCode || 'INSDU_CONTRACT_INVALID', error.message || 'Kontrak Insdu tidak valid.');
  }
}
