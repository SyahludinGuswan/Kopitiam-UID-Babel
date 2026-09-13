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

function syncWoInsduContract_(token, rows) {
  if (!Array.isArray(rows) || rows.length > 100) return fail_('BATCH_INVALID', 'Maksimal 100 WO per sinkronisasi.');
  try {
    for (var i = 0; i < rows.length; i++) {
      validateInsduJurusan_(rows[i] || {});
      validateInsduCoordinates_(rows[i] || {});
    }
    [
      'jurusan terpasang', 'jurusan terpakai',
      'koordinat penginputan wbp', 'waktu penginputan wbp', 'jarak antar gardu ke petugas (wbp)',
      'koordinat penginputan lwbp', 'waktu penginputan lwbp', 'jarak antar gardu ke petugas (lwbp)'
    ].forEach(function (header) {
      if (WO_CORE_MUTABLE.insdu.indexOf(header) < 0) WO_CORE_MUTABLE.insdu.push(header);
    });
    return syncWoCoreCommitted_(token, 'insdu', CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du', rows);
  } catch (error) {
    return fail_(error.insduCode || 'INSDU_CONTRACT_INVALID', error.message || 'Kontrak Insdu tidak valid.');
  }
}
