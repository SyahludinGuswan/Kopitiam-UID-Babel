/* Insdu contract for Jurusan Terpasang and Jurusan Terpakai. */
function insduJurusanInteger_(value, label) {
  var text = String(value == null ? '' : value).trim();
  if (!/^[1-4]$/.test(text)) {
    var error = new Error(label + ' wajib berupa bilangan bulat 1 sampai 4.');
    error.insduCode = 'INSDU_JURUSAN_RANGE_INVALID';
    throw error;
  }
  return Number(text);
}

function validateInsduJurusan_(incoming) {
  var installed = insduJurusanInteger_(incoming['Jurusan Terpasang'], 'Jurusan Terpasang');
  var used = insduJurusanInteger_(incoming['Jurusan Terpakai'], 'Jurusan Terpakai');
  if (used > installed) {
    var error = new Error('Jurusan Terpakai harus sama dengan atau lebih kecil dari Jurusan Terpasang.');
    error.insduCode = 'INSDU_JURUSAN_RELATION_INVALID';
    throw error;
  }
  return { installed: installed, used: used };
}

function syncWoInsduContract_(token, rows) {
  if (!Array.isArray(rows) || rows.length > 100) return fail_('BATCH_INVALID', 'Maksimal 100 WO per sinkronisasi.');
  try {
    for (var i = 0; i < rows.length; i++) validateInsduJurusan_(rows[i] || {});
    if (WO_CORE_MUTABLE.insdu.indexOf('jurusan terpasang') < 0) WO_CORE_MUTABLE.insdu.push('jurusan terpasang');
    if (WO_CORE_MUTABLE.insdu.indexOf('jurusan terpakai') < 0) WO_CORE_MUTABLE.insdu.push('jurusan terpakai');
    return syncWoCoreCommitted_(token, 'insdu', CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du', rows);
  } catch (error) {
    return fail_(error.insduCode || 'INSDU_JURUSAN_INVALID', error.message || 'Kontrak Jurusan Insdu tidak valid.');
  }
}
