/* REL-07 behavior guard: immutable identity, complete fields, and lease-safe sweep. */
/* Canonical stale-lease entry point is intentionally kept here for runtime selection. */
var OPJ_TEMUAN_REQUIRED_HEADERS_ = [
  'kode wo', 'kode temuan', 'kode uiw', 'kode up3', 'kode ulp', 'ulp',
  'hari', 'tanggal', 'jenis object', 'tier', 'temuan', 'prioritas',
  'koordinat temuan', 'lat temuan', 'long temuan', 'foto temuan',
  'link foto', 'foto lingkungan sekitaran tiang',
  'link foto sekitaran tiang', 'waktu input', 'user input', 'folder path'
];

function validateTemuanHeaders_(headers) {
  var index = headerIndex_(headers), missing = [];
  OPJ_TEMUAN_REQUIRED_HEADERS_.forEach(function (key) {
    if (index[key] === undefined) missing.push(key);
  });
  return missing.length
    ? fail_('SHEET_HEADERS_INVALID', 'Header Inp_Temuan belum lengkap: ' + missing.join(', ') + '.')
    : { success: true };
}

function opjPhotoDigest_(row, base64Key, suppliedKey) {
  var supplied = String(row[suppliedKey] || '').trim().toLowerCase();
  var suppliedValid = /^[a-f0-9]{64}$/.test(supplied);
  var encoded = String(row[base64Key] || '');
  if (!encoded) return suppliedValid ? supplied : '';
  var actual = digestBytes_(Utilities.base64Decode(encoded));
  if (suppliedValid && supplied !== actual) {
    throw new Error('Digest foto kiriman tidak cocok dengan byte foto: ' + base64Key + '.');
  }
  return actual;
}

function operationJournalIdentity_(action, body, session) {
  var row = body && Array.isArray(body.rows) && body.rows.length === 1
    ? body.rows[0]
    : body && body.row;
  if (!row || typeof row !== 'object') throw new Error('Jurnal hanya menerima satu objek per operasi.');
  var objectId = action === 'syncTemuanInspeksi'
    ? String(row['Kode Temuan'] || '').trim()
    : String(row['Kode WO'] || '').trim();
  if (!objectId) throw new Error('Identitas objek jurnal kosong.');

  var clientPayloadDigest = String(row.clientPayloadDigest || '').trim().toLowerCase();
  var photoAfter = opjPhotoDigest_(row, 'fotoSesudahBase64', 'clientPhotoDigest');
  var photoFinding = opjPhotoDigest_(row, 'fotoTemuanBase64', 'clientFotoTemuanDigest');
  var photoEnvironment = opjPhotoDigest_(row, 'fotoLingkunganBase64', 'clientFotoLingkunganDigest');
  var payloadDigest = clientPayloadDigest;
  if (!/^[a-f0-9]{64}$/.test(payloadDigest)) {
    var copy = {};
    Object.keys(row).sort().forEach(function (key) {
      if (['fotoSesudahBase64', 'fotoTemuanBase64', 'fotoLingkunganBase64'].indexOf(key) >= 0) return;
      copy[key] = row[key];
    });
    payloadDigest = sha256_(JSON.stringify(copy));
  }
  var username = normalize_(session && session.username);
  if (!username) throw new Error('Username live wajib tersedia untuk jurnal.');
  var evidenceDigest = sha256_([payloadDigest, photoAfter, photoFinding, photoEnvironment].join('|'));
  return {
    action: action,
    objectId: objectId,
    username: username,
    payloadDigest: payloadDigest,
    evidenceDigest: evidenceDigest,
    operationId: sha256_([username, action, objectId, evidenceDigest].join('|'))
  };
}

function opjFindingProjection_(source, index) {
  var projection = {};
  Object.keys(source || {}).forEach(function (key) {
    var normalized = normalize_(key);
    if (OPJ_FINDING_TRANSPORT_KEYS_[normalized]) return;
    if (!index || index[normalized] === undefined) {
      throw new Error('Field Temuan tidak memiliki kolom tujuan: ' + key + '.');
    }
    projection[normalized] = receiptCanonical_(source[key]);
  });
  return projection;
}

function operationJournalSweepStaleLeases_() {
  var source = operationJournalSheet_(), last = source.sheet.getLastRow();
  if (last < 2) return { success: true, released: 0 };
  var operationColumn = opjColumn_(source, 'Operation ID');
  var snapshot = source.sheet.getRange(2, 1, last - 1, source.headers.length).getDisplayValues();
  var now = operationJournalNow_(), released = 0;
  for (var i = 0; i < snapshot.length; i++) {
    var operationId = String(snapshot[i][operationColumn] || '').trim();
    if (!operationId) continue;
    var lock = LockService.getScriptLock();
    lock.waitLock(20000);
    try {
      var freshSource = operationJournalSheet_();
      var found = operationJournalFind_(freshSource, operationId);
      if (!found) continue;
      var record = operationJournalObject_(freshSource, found);
      var state = normalize_(record['State']);
      var lease = Date.parse(record['Lease Until'] || '');
      if (state !== 'processing' || !isFinite(lease) || lease > now.getTime()) continue;
      operationJournalWrite_(freshSource, found.rowNumber, {
        'State': 'needs-reconciliation',
        'Lease Until': '',
        'Lease Token': '',
        'Error Code': 'STALE_PROCESSING_LEASE',
        'Error Message': 'Lease worker berakhir sebelum receipt committed.',
        'Next Reconciliation At': operationJournalIso_(now)
      });
      released++;
    } finally {
      lock.releaseLock();
    }
  }
  return { success: true, released: released };
}
