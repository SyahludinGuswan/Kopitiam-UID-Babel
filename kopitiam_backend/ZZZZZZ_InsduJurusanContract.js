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

function insduCapture_(incoming, suffix) {
  var coordinateKey = 'Koordinat Penginputan ' + suffix;
  var timeKey = 'Waktu Penginputan ' + suffix;
  var coordinate = insduCoordinate_(incoming[coordinateKey], coordinateKey);
  var capturedAt = String(incoming[timeKey] == null ? '' : incoming[timeKey]).trim();
  if (!capturedAt || capturedAt.length > 80) {
    insduContractError_('INSDU_CAPTURE_TIME_INVALID', timeKey + ' wajib diisi.');
  }
  return { coordinate: coordinate, capturedAt: capturedAt };
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
