function temuanSheetHeaders_() {
  return [
    "No", "Kode WO", "Kode Temuan", "Kode UIW", "Kode UP3", "Kode ULP", "ULP",
    "Hari", "Tanggal", "Penyulang", "Section Awal", "Section Akhir", "Section",
    "Segmen", "Nomor Gardu", "Jenis Object", "Tier", "Temuan",
    "Jarak Terhadap Jaringan", "Jenis Pohon", "Tinggi Pohon", "Prioritas",
    "Koordinat Temuan", "Lat Temuan", "Long Temuan", "Foto Temuan", "Link Foto",
    "Foto Lingkungan Sekitaran Tiang", "Link Foto Sekitaran Tiang",
    "Pekerjaan (Padam / Tanpa Padam)", "Jenis WO", "Waktu Input", "User Input", "Folder Path"
  ];
}

function temuanSheet_() {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.TEMUAN_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(CONFIG.TEMUAN_SHEET || "Inp_Temuan");
  if (!sheet) {
    sheet = spreadsheet.insertSheet(CONFIG.TEMUAN_SHEET || "Inp_Temuan");
    sheet.appendRow(temuanSheetHeaders_());
    try { sheet.setFrozenRows(1); } catch (_) {}
  }
  return sheet;
}

function validateTemuanHeaders_(headers) {
  var index = headerIndex_(headers);
  var required = ["kode wo", "kode temuan", "temuan", "jenis object", "tier", "prioritas", "koordinat temuan"];
  for (var i = 0; i < required.length; i++) {
    if (index[required[i]] === undefined) return fail_("SHEET_HEADERS_INVALID", "Header sheet Inp_Temuan belum valid. Kolom wajib tidak ditemukan: " + required[i] + ".");
  }
  return { success: true };
}

function preparePhoto_(base64Value, role) {
  if (!base64Value) throw new Error(role + " required");
  var encoded = String(base64Value);
  if (encoded.length > Math.ceil((CONFIG.MAX_IMAGE_BYTES * 4) / 3) + 16) throw new Error(role + " too large");
  var bytes;
  try { bytes = Utilities.base64Decode(encoded); } catch (_) { throw new Error(role + " invalid base64"); }
  if (bytes.length > CONFIG.MAX_IMAGE_BYTES) throw new Error(role + " too large");
  validateJpegBytes_(bytes);
  return { role: role, bytes: bytes, digest: digestBytes_(bytes) };
}

function digestBytes_(bytes) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, bytes).map(function (value) {
    var byte = value < 0 ? value + 256 : value;
    return ("0" + byte.toString(16)).slice(-2);
  }).join("");
}

function putPhotoIdempotent_(folder, code, prepared) {
  var filename = safePath_(code + "." + prepared.role + "." + prepared.digest.substring(0, 24) + ".jpg");
  var matches = folder.getFilesByName(filename);
  if (matches.hasNext()) {
    var existing = matches.next();
    return { file: existing, name: existing.getName(), url: existing.getUrl(), digest: prepared.digest, created: false };
  }
  var created = folder.createFile(Utilities.newBlob(prepared.bytes, "image/jpeg", filename));
  return { file: created, name: created.getName(), url: created.getUrl(), digest: prepared.digest, created: true };
}

function rollbackCreatedPhotos_(photos) {
  (photos || []).forEach(function (photo) {
    if (!photo || !photo.created || !photo.file) return;
    try { photo.file.setTrashed(true); } catch (_) {}
  });
}

function removeStalePhotos_(folder, code, keepNames) {
  var prefix = code + ".", files = folder.getFiles();
  while (files.hasNext()) {
    var file = files.next(), name = file.getName();
    if (name.indexOf(prefix) !== 0 || keepNames.indexOf(name) >= 0) continue;
    if (name.indexOf(".Foto Temuan.") < 0 && name.indexOf(".Foto Lingkungan.") < 0) continue;
    try { file.setTrashed(true); } catch (_) {}
  }
}

function photoIdempotencyKey_(code, primary, environment) {
  return sha256_(code + "|" + primary.digest + "|" + environment.digest).substring(0, 40);
}

function c4aContext_(session, incoming) {
  var access = requireC4aAccess_(session);
  if (!access.success) return access;
  var central = access.profile;
  var kodeUlp = normalizeCode_(central.kodeUlp || "");
  var incomingUlp = normalizeCode_(incoming["Kode ULP"] || "");
  if (!kodeUlp || !incomingUlp || kodeUlp !== incomingUlp) return fail_("ULP_MISMATCH", "Unit temuan tidak sesuai akun login.");
  return {
    success: true,
    kodeUlp: kodeUlp,
    values: {
      "Kode UIW": safeText_(central.kodeUiw, 40),
      "Kode UP3": safeText_(central.kodeUp3, 40),
      "Kode ULP": safeText_(central.kodeUlp, 40),
      "ULP": safeText_(central.ulp, 120),
      "Penyulang": safeText_(incoming.Penyulang, 120),
      "Section Awal": safeText_(incoming["Section Awal"], 120),
      "Section Akhir": safeText_(incoming["Section Akhir"], 120),
      "Section": safeText_(incoming.Section, 200),
      "Nomor Gardu": safeText_(incoming["Nomor Gardu"], 120)
    }
  };
}

function buildC4aFindingPath_(kodeUlp, object, code, now) {
  var month = Utilities.formatDate(now, Session.getScriptTimeZone(), "MM");
  var year = Utilities.formatDate(now, Session.getScriptTimeZone(), "yyyy");
  var day = Utilities.formatDate(now, Session.getScriptTimeZone(), "dd");
  var monthName = Utilities.formatDate(now, Session.getScriptTimeZone(), "MM. MMMM");
  return "Kopitiam/Rekap Temuan Inspeksi/" + safePath_(kodeUlp) + "/" + safePath_(object) + "/" + year + "/" + monthName + "/" + day + "/" + safePath_(code) + "/";
}

function verifyTemuanWriteOwner_(values, index, target, session, row, context, isC4a) {
  if (!target) return;
  var existing = values[target - 1];
  if (normalize_(existing[index["kode temuan"]]) !== normalize_(row["Kode Temuan"])) throw new Error("Identitas Temuan existing tidak cocok.");
  if (normalizeCode_(existing[index["kode ulp"]]) !== normalizeCode_(context.kodeUlp)) throw new Error("Temuan existing bukan milik ULP sesi.");
  if (normalize_(existing[index["kode wo"]]) !== normalize_(row["Kode WO"])) throw new Error("Parent WO Temuan existing tidak cocok.");
  if (isC4a && normalize_(existing[index["user input"]]) !== normalize_(session.username)) throw new Error("Temuan C4A existing bukan milik akun sesi.");
  ["jenis object", "tier", "tanggal", "folder path"].forEach(function (key) {
    var incomingKey = { "jenis object": "Jenis Object", tier: "Tier", tanggal: "Tanggal", "folder path": "Folder Path" }[key];
    if (normalize_(existing[index[key]]) !== normalize_(row[incomingKey])) throw new Error(incomingKey + " Temuan existing tidak boleh berubah.");
  });
}

function syncTemuanInspeksiIdempotent_(token, incoming) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  if (!incoming || typeof incoming !== "object") return fail_("FINDING_REQUIRED", "Data temuan kosong.");

  var kodeWo = safeText_(incoming["Kode WO"], 100);
  var code = safeText_(incoming["Kode Temuan"], 120);
  var isC4a = kodeWo === "";
  if (isC4a) {
    var c4aAccess = requireC4aAccess_(auth.sesi);
    if (!c4aAccess.success) return c4aAccess;
  }
  if (isC4a) {
    if (!/^PEG-[A-Z0-9]+\.TO-[0-9]{3}$/.test(code)) return fail_("FINDING_CODE_INVALID", "Kode Temuan C4A tidak valid.");
    incoming["Kode WO"] = "";
    incoming["Jenis WO"] = "";
  } else if (code.indexOf(kodeWo + ".TO-") !== 0 || !/^[0-9]{3}$/.test(code.substring((kodeWo + ".TO-").length))) {
    return fail_("FINDING_CODE_INVALID", "Kode Temuan tidak valid.");
  }

  var object = safeText_(incoming["Jenis Object"], 40);
  var finding = safeText_(incoming.Temuan, 200);
  var segment = safeText_(incoming.Segmen, 200);
  if (object !== "Jaringan" && object !== "Gardu") return fail_("OBJECT_INVALID", "Jenis Object harus Jaringan atau Gardu.");
  if (!finding || !segment) return fail_("FINDING_INVALID", "Data wajib temuan belum valid.");

  var master = resolveFindingMaster_(object, finding, incoming);
  if (!master.success) return master;
  object = master.object;
  var tier = master.tier;
  finding = master.finding;
  var priority = master.priority;

  var sub = normalize_(auth.sesi.subTim || auth.sesi.tim);
  if (!isC4a) {
    var expected = object;
    if (sub.indexOf("inspeksi jaringan") >= 0 || sub.indexOf("insjar") >= 0) expected = "Jaringan";
    else if (sub.indexOf("inspeksi gardu") >= 0 || sub.indexOf("insdu") >= 0) expected = "Gardu";
    if (expected !== object) return fail_("OBJECT_MISMATCH", "Jenis Object tidak sesuai Sub-Tim.");
  }

  var point, primaryPrepared, environmentPrepared;
  try {
    point = validateCoordinate_(safeText_(incoming["Koordinat Temuan"], 80));
    primaryPrepared = preparePhoto_(incoming.fotoTemuanBase64, "Foto Temuan");
    environmentPrepared = preparePhoto_(incoming.fotoLingkunganBase64, "Foto Lingkungan");
  } catch (_) { return fail_("INPUT_INVALID", "Koordinat atau file foto tidak valid."); }

  var lock = LockService.getScriptLock(), created = [];
  lock.waitLock(30000);
  try {
    var context = isC4a ? c4aContext_(auth.sesi, incoming) : woContext_(auth.sesi, kodeWo, true);
    if (!context.success) return context;
    var now = new Date(), row = {}, source = context.values || {};
    if (isC4a) {
      var asset = resolveFindingAsset_(object, incoming, context);
      if (!asset.success) return asset;
      Object.keys(asset.values).forEach(function (key) { source[key] = asset.values[key]; });
    } else {
      var index = context.index, server = context.row;
      source = {
        "Kode UIW": server[index["kode uiw"]] || auth.sesi.kodeUiw || "",
        "Kode UP3": server[index["kode up3"]] || auth.sesi.kodeUp3 || "",
        "Kode ULP": context.kodeUlp,
        "ULP": server[index.ulp] || auth.sesi.ulp || "",
        "Penyulang": server[index.penyulang] || "",
        "Section Awal": server[index["section awal"]] || "",
        "Section Akhir": server[index["section akhir"]] || "",
        "Section": server[index.section] || "",
        "Nomor Gardu": server[index["nomor gardu"]] || ""
      };
    }
    row["Kode WO"] = isC4a ? "" : kodeWo;
    row["Kode Temuan"] = code;
    ["Kode UIW","Kode UP3","Kode ULP","ULP","Penyulang","Section Awal","Section Akhir","Section","Nomor Gardu"].forEach(function (key) { row[key] = source[key] || ""; });
    row.Hari = safeText_(incoming.Hari, 20) || ["Minggu","Senin","Selasa","Rabu","Kamis","Jumat","Sabtu"][now.getDay()];
    row.Tanggal = safeText_(incoming.Tanggal, 40) || Utilities.formatDate(now, Session.getScriptTimeZone(), "dd MMMM yyyy");
    row.Segmen = segment;
    row["Koordinat Temuan"] = point.latitude + ", " + point.longitude;
    row["Lat Temuan"] = point.latitude; row["Long Temuan"] = point.longitude;
    row["Jenis Object"] = object; row.Tier = tier; row.Temuan = finding;
    row["Jarak Terhadap Jaringan"] = numericOrBlank_(incoming["Jarak Terhadap Jaringan"]);
    row["Jenis Pohon"] = safeText_(incoming["Jenis Pohon"], 100);
    row["Tinggi Pohon"] = numericOrBlank_(incoming["Tinggi Pohon"]);
    row.Prioritas = priority;
    row["Pekerjaan (Padam / Tanpa Padam)"] = isC4a ? "" : safeText_(incoming["Pekerjaan (Padam / Tanpa Padam)"], 80);
    row["Jenis WO"] = isC4a ? "" : safeText_(incoming["Jenis WO"], 80);
    row["Waktu Input"] = safeText_(incoming["Waktu Input"], 80) || Utilities.formatDate(now, Session.getScriptTimeZone(), "dd MMMM yyyy, HH:mm:ss");
    row["User Input"] = auth.sesi.username;
    row["Folder Path"] = isC4a ? buildC4aFindingPath_(context.kodeUlp, object, code, now) : buildFindingPath_(context.kodeUlp, object, kodeWo, code, now);

    var sheet = temuanSheet_(), values = sheet.getDataRange().getValues();
    var headers = values.length && values[0].length ? values[0] : sheet.getRange(1, 1, 1, sheet.getLastColumn()).getDisplayValues()[0];
    var validation = validateTemuanHeaders_(headers);
    if (!validation.success) return validation;
    var headerIndex = headerIndex_(headers), matches = [];
    for (var r = 1; r < values.length; r++) {
      if (normalize_(values[r][headerIndex["kode temuan"]]) === normalize_(code)) matches.push(r + 1);
    }
    if (matches.length > 1) throw new Error("Kode Temuan existing tidak unik.");
    var target = matches.length ? matches[0] : 0;
    verifyTemuanWriteOwner_(values, headerIndex, target, auth.sesi, row, context, isC4a);

    var folder = folderPath_(row["Folder Path"]);
    var primary = putPhotoIdempotent_(folder, code, primaryPrepared); created.push(primary);
    var environment = putPhotoIdempotent_(folder, code, environmentPrepared); created.push(environment);
    var cleanPath = String(row["Folder Path"]).replace(/[\/\\]+$/, "");
    row["Foto Temuan"] = cleanPath + "\\" + primary.name; row["Link Foto"] = primary.url;
    row["Foto Lingkungan Sekitaran Tiang"] = cleanPath + "\\" + environment.name;
    row["Link Foto Sekitaran Tiang"] = environment.url;
    var normalized = {};
    for (var key in row) if (Object.prototype.hasOwnProperty.call(row, key)) normalized[normalize_(key)] = row[key];
    var output = headers.map(function (header) { var value = normalized[normalize_(header)]; return value == null ? "" : safeCell_(value); });
    var numberColumn = ["no","no.","nomor"].indexOf(normalize_(headers[0] || "")) >= 0;
    if (target) {
      if (numberColumn) output[0] = values[target - 1][0];
      sheet.getRange(target, 1, 1, headers.length).setValues([output]);
    } else {
      if (numberColumn) output[0] = sheet.getLastRow();
      sheet.appendRow(output);
    }
    SpreadsheetApp.flush();
    removeStalePhotos_(folder, code, [primary.name, environment.name]);
    return { success: true, linkFoto: primary.url, linkLingkungan: environment.url, folderPath: row["Folder Path"], idempotencyKey: photoIdempotencyKey_(code, primary, environment), reused: !primary.created && !environment.created, mode: isC4a ? "C4A" : "WO" };
  } catch (err) {
    console.error("syncTemuanInspeksi idempotent gagal:", err && err.stack ? err.stack : err);
    rollbackCreatedPhotos_(created);
    var detail = String((err && err.message) || err || "").replace(/\s+/g, " ").trim().substring(0, 280);
    return fail_("SYNC_TRANSACTION_FAILED", detail ? "Sinkronisasi gagal: " + detail : "Sinkronisasi gagal dan file baru dibatalkan.");
  } finally { lock.releaseLock(); }
}
