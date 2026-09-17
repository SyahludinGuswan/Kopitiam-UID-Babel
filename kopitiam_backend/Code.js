var CONFIG = {
  SPREADSHEET_ID: "1PuHONGQ8ZOBQRutk9RR5-ZjFcrqW3hWfBYllQu4RUMo",
  WO_SPREADSHEET_ID: "1NYLuEIxOz8Hk4INvv8q6wq_W5CCOgfQUn7ffDgyDGy8",
  TEMUAN_SPREADSHEET_ID: "1D_WOPB75A4IJUAESrTsk5MShGmRAWlGWROqoNE-y9mw",
  USERS_SHEET: "User_App_Mobile",
  WO_INSJAR_SHEET: "WO_Ins_Jar",
  WO_INSDU_SHEET: "WO_Ins_Du",
  WO_ROW_SHEET: "WO_ROW",
  WO_HAR_JAR_SHEET: "WO_Har_Jar",
  WO_HAR_DU_SHEET: "WO_Har_Du",
  MATERIAL_HAR_JAR_SHEET: "Realisasi_Material_HarJar",
  TEMUAN_SHEET: "Inp_Temuan",
  MAX_IMAGE_BYTES: 5 * 1024 * 1024,
  DRIVE_ROOT_FOLDER: "Kopitiam",
  MASTER_SHEETS: [
    "User_App_Mobile",
    "Master_Penyulang",
    "Master_Keypoint",
    "Master_Temuan",
    "Jenis Pohon",
    "Master_Material",
    "Master_Pekerjaan_Har",
    "Master_Gardu",
  ],
};

function runtimeIdentity_(body) {
  body = body || {};
  return body.deviceToken || body.token || body.username || "anonymous";
}

function revokeBoundSession_(sessionToken, deviceToken) {
  if (!sessionToken) return;
  try { authServiceCall_("logout", { token: String(sessionToken).trim(), deviceToken: String(deviceToken || "").trim() }); }
  catch (error) { console.error("Pencabutan token Auth gagal:", error); }
}

function verifySessionDeviceBinding_(sessionToken, session) {
  if (!session || typeof session !== "object" || !sessionToken) return fail_("SESSION_BINDING_INVALID", "Sesi tidak terikat ke perangkat.");
  return { success: true, deviceToken: String(session.deviceToken || "").trim() };
}

var USER_COL = {
  no: 0,
  kodeUiw: 1,
  kodeUp3: 2,
  kodeUlp: 3,
  ulp: 4,
  username: 5,
  role: 6,
  bidang: 7,
  tim: 8,
  subTim: 9,
  aksesMenu: 10,
};

function doGet(e) {
  var a = String((e && e.parameter && e.parameter.action) || "health").trim();
  return a === "health"
    ? json_({ success: true, service: "Kopitiam API", version: "3.0.0" })
    : json_({
        success: false,
        kode: "POST_REQUIRED",
        message: "Gunakan POST untuk operasi API.",
      });
}

function doPost(e) {
  try {
    var b = parseBody_(e),
      a = String(b.action || "").trim();
    var quota = consumeActionQuota_(a, runtimeIdentity_(b));
    if (!quota.success) return json_(quota);
    if (a === "login" || a === "loginPerangkat")
      return json_(loginPerangkat_(b.username, b.password, b.perangkat));
    if (a === "cekPerangkat") return json_(cekPerangkat_(b.deviceToken));
    if (a === "getRoleProfile" || a === "getProfilPeran")
      return json_(getRoleProfile_(b.token));
    if (a === "logoutPerangkat")
      return json_(logoutPerangkat_(b.deviceToken, b.token));
    if (a === "cekSesi") return json_(cekSesi_(b.token));
    if (a === "logout") return json_(logout_(b.token));
    if (a === "getMasterData") return json_(getMasterData_(b.token));
    if (a === "getWoInsjar") return json_(getWoInsjar_(b.token));
    if (a === "syncWoInsjar") return json_(syncWoInsjar_(b.token, b.rows));
    if (a === "getWoInsdu") return json_(getWoInsdu_(b.token));
    if (a === "syncWoInsdu") return json_(syncWoInsdu_(b.token, b.rows));
    if (a === "getWoRow") return json_(getWoRow_(b.token));
    if (a === "syncWoRow") return json_(syncWoRow_(b.token, b.rows));
    if (a === "getWoHarJar") return json_(getWoHarJar_(b.token));
    if (a === "syncWoHarJar") return json_(syncWoHarJar_(b.token, b.rows));
    if (a === "getWoHarDu") return json_(getWoHarDu_(b.token));
    if (a === "syncWoHarDu") return json_(syncWoHarDu_(b.token, b.rows));
    if (a === "getTemuanInspeksi")
      return json_(getTemuanInspeksi_(b.token, b.kodeWo));
    if (a === "syncTemuanInspeksi")
      return json_(syncTemuanInspeksiIdempotent_(b.token, b.row));
    return json_({
      success: false,
      kode: "ACTION_INVALID",
      message: "Action API tidak dikenal.",
    });
  } catch (x) {
    console.error(x && x.stack ? x.stack : x);
    return json_({
      success: false,
      kode: "SERVER_ERROR",
      message: "Permintaan tidak dapat diproses.",
    });
  }
}

function loginPerangkat_(u, p, d) {
  u = String(u || "").trim();
  p = String(p || "");
  if (!u || !p)
    return fail_("LOGIN_REQUIRED", "Username dan kata sandi wajib diisi.");
  var auth = authServiceCall_("login", { username: u, password: p, device: safeText_(d, 120) });
  p = "";
  if (!auth.success) return auth;
  return operationalSession_(auth);
}

function cekPerangkat_(t) {
  t = String(t || "").trim();
  if (!/^[a-f0-9]{64}$/i.test(t)) return fail_("DEVICE_INVALID", "Sesi perangkat tidak valid.");
  var auth = authServiceCall_("refresh", { deviceToken: t });
  if (!auth.success) return auth;
  return operationalSession_(auth);
}

function logoutPerangkat_(d, t) {
  var auth = authServiceCall_("logout", { token: String(t || "").trim(), deviceToken: String(d || "").trim() });
  return auth.success ? { success: true } : auth;
}

function issueSession_(r, d) {
  return fail_("AUTH_SERVICE_REQUIRED", "Penerbitan sesi harus melalui layanan autentikasi.");
}

function cekSesi_(t) {
  t = String(t || "").trim();
  if (!/^[a-f0-9]{64}$/i.test(t)) return fail_("SESSION_INVALID", "Sesi tidak valid atau sudah berakhir.");
  var auth = authServiceCall_("introspect", { token: t });
  if (!auth.success) return auth;
  var session = operationalSession_(auth);
  if (!session.success) {
    revokeBoundSession_(t, auth.deviceToken);
    return session;
  }
  return { success: true, sesi: session };
}

function logout_(t) {
  return logoutPerangkat_("", t);
}

function getRoleProfile_(t) {
  var auth = cekSesi_(t);
  if (!auth.success) return auth;
  var profile = activeRoleProfile_(auth.sesi);
  if (!profile.success) return profile;
  return {
    success: true,
    profile: profile.profile,
    kodeUiw: profile.profile.kodeUiw,
    kodeUp3: profile.profile.kodeUp3,
    kodeUlp: profile.profile.kodeUlp,
    ulp: profile.profile.ulp,
    username: profile.profile.username,
    role: profile.role,
    canAccessC4a: profile.canAccessC4a,
  };
}

function getMasterData_(t) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var u = normalize_(a.sesi.username),
    ss = getSpreadsheet_(),
    sets = {},
    total = 0;
  for (var i = 0; i < CONFIG.MASTER_SHEETS.length; i++) {
    var n = CONFIG.MASTER_SHEETS[i],
      sh = ss.getSheetByName(n);
    if (!sh)
      return fail_("MASTER_SHEET_MISSING", "Data master belum tersedia: " + n);
    var v = sh.getDataRange().getDisplayValues(),
      h = v.length
        ? v[0].map(function (x) {
            return String(x).trim();
          })
        : [],
      rows = [];
    for (var r = 1; r < v.length; r++) {
      if (n === CONFIG.USERS_SHEET && normalize_(v[r][USER_COL.username]) !== u)
        continue;
      var item = {},
        has = false;
      for (var c = 0; c < h.length; c++) {
        var k = h[c] || "kolom_" + (c + 1);
        if (n === CONFIG.USERS_SHEET && normalize_(k) === "password") continue;
        item[k] = v[r][c];
        if (v[r][c] !== "") has = true;
      }
      if (has) rows.push(item);
    }
    sets[n] = rows;
    total += rows.length;
  }
  return {
    success: true,
    generatedAt: new Date().toISOString(),
    total: total,
    datasets: sets,
  };
}

// ----------------------------------------------------
// WO HAR (JARINGAN & GARDU)
// ----------------------------------------------------
function woHarAccess_(s, mode) {
  var sub = normalize_(s.subTim || s.tim || "");
  var u = normalize_(s.username || "");
  var k = normalizeCode_(s.kodeUlp || "");
  if (!k) return fail_("ULP_MISSING", "Kode ULP akun belum terisi.");

  var isHarGeneral = (sub === "har" || sub === "hartek" || u.indexOf(".har") >= 0 || u.indexOf(".hartek") >= 0);
  var isHarDu = (sub.indexOf("har gardu") >= 0 || sub.indexOf("hardu") >= 0 || u.indexOf(".hardu") >= 0);
  var isHarJar = (sub.indexOf("har jar") >= 0 || sub.indexOf("harjar") >= 0 || u.indexOf(".harjar") >= 0);

  if (mode === "jar") {
    if (isHarGeneral || isHarJar) return { success: true, kodeUlp: k, subTim: sub };
    return fail_("HARJAR_ACCESS_DENIED", "Akses WO Har Jar hanya untuk Tim Har Jar / Hartek.");
  }
  if (mode === "du") {
    if (isHarGeneral || isHarDu) return { success: true, kodeUlp: k, subTim: sub };
    return fail_("HARDU_ACCESS_DENIED", "Akses WO Har Du hanya untuk Tim Har Gardu / Hartek.");
  }
  return fail_("HAR_ACCESS_DENIED", "Akses ditolak.");
}

function getWoHarJar_(t) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "jar");
  if (!ac.success) return ac;
  var sh = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(CONFIG.WO_HAR_JAR_SHEET);
  if (!sh) return { success: true, total: 0, rows: [] };
  var v = sh.getDataRange().getDisplayValues();
  if (v.length < 2) return { success: true, total: 0, totalSheet: 0, rows: [] };
  var h = v[0].map(function (x) { return String(x).trim(); });
  var ix = headerIndex_(h);
  var rows = [];
  var sampleKodeUlp = "";
  var rejectedByUlp = 0;
  for (var r = 1; r < v.length; r++) {
    if (!String(v[r][ix["kode wo"]] || "").trim()) continue;
    var rowKodeUlp = normalizeCode_(v[r][ix["kode ulp"]]);
    if (!sampleKodeUlp) sampleKodeUlp = rowKodeUlp;
    if (rowKodeUlp !== ac.kodeUlp) {
      rejectedByUlp++;
      continue;
    }
    rows.push(rowObject_(h, v[r]));
  }
  return {
    success: true,
    total: rows.length,
    totalSheet: v.length - 1,
    kodeUlpFilter: ac.kodeUlp,
    sampleKodeUlp: sampleKodeUlp,
    rejectedByUlp: rejectedByUlp,
    rows: rows,
  };
}

function getWoHarDu_(t) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "du");
  if (!ac.success) return ac;
  var sh = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(CONFIG.WO_HAR_DU_SHEET);
  if (!sh) return { success: true, total: 0, rows: [] };
  var v = sh.getDataRange().getDisplayValues();
  if (v.length < 2) return { success: true, total: 0, totalSheet: 0, rows: [] };
  var h = v[0].map(function (x) { return String(x).trim(); });
  var ix = headerIndex_(h);
  var rows = [];
  var sampleKodeUlp = "";
  var rejectedByUlp = 0;
  for (var r = 1; r < v.length; r++) {
    if (!String(v[r][ix["kode wo"]] || "").trim()) continue;
    var rowKodeUlp = normalizeCode_(v[r][ix["kode ulp"]]);
    if (!sampleKodeUlp) sampleKodeUlp = rowKodeUlp;
    if (rowKodeUlp !== ac.kodeUlp) {
      rejectedByUlp++;
      continue;
    }
    rows.push(rowObject_(h, v[r]));
  }
  return {
    success: true,
    total: rows.length,
    totalSheet: v.length - 1,
    kodeUlpFilter: ac.kodeUlp,
    sampleKodeUlp: sampleKodeUlp,
    rejectedByUlp: rejectedByUlp,
    rows: rows,
  };
}

var WO_HAR_MUTABLE_HEADERS = [
  "koordinat", "lat", "long", "foto sesudah", "link foto sesudah",
  "catatan petugas", "status wo", "waktu selesai", "durasi", "user input", "waktu input", "folder path"
];

function syncWoHarJar_(t, rows) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "jar");
  if (!ac.success) return ac;
  return syncGenericWoHar_(a.sesi, CONFIG.WO_HAR_JAR_SHEET, rows);
}

function syncWoHarDu_(t, rows) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "du");
  if (!ac.success) return ac;
  return syncGenericWoHar_(a.sesi, CONFIG.WO_HAR_DU_SHEET, rows);
}

function syncGenericWoHar_(sesi, sheetName, rows) {
  if (!Array.isArray(rows) || rows.length > 100) return fail_("BATCH_INVALID", "Maksimal 100 WO.");
  var sh = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(sheetName);
  if (!sh) return fail_("SHEET_NOT_FOUND", "Sheet " + sheetName + " tidak ditemukan.");
  var v = sh.getDataRange().getDisplayValues();
  if (v.length < 2) return fail_("DATA_EMPTY", "Sheet data kosong.");
  var h = v[0].map(function (x) { return String(x).trim(); });
  var ix = headerIndex_(h);
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var done = 0;
    for (var i = 0; i < rows.length; i++) {
      var d = rows[i] || {};
      var kodeWo = String(d["Kode WO"] || "").trim();
      var targetRow = 0;
      for (var r = 1; r < v.length; r++) {
        if (String(v[r][ix["kode wo"]] || "").trim() === kodeWo) {
          targetRow = r + 1;
          break;
        }
      }
      if (!targetRow) continue;
      var out = v[targetRow - 1].slice();
      var normPayload = {};
      for (var key in d) if (Object.prototype.hasOwnProperty.call(d, key)) normPayload[normalize_(key)] = d[key];

      var existingFolder = ix["folder path"] !== undefined ? v[targetRow - 1][ix["folder path"]] : "";
      var folderPathVal = normPayload["folder path"] || existingFolder || ("Kopitiam/WO_HAR/" + safePath_(sesi.kodeUlp || "") + "/" + safePath_(kodeWo) + "/");
      normPayload["folder path"] = folderPathVal;

      var b64Photo = normPayload["foto sesudah base64"] || normPayload["fotosesudahbase64"];
      if (b64Photo) {
        try {
          var uploaded = uploadWoPhoto_(folderPathVal, kodeWo, b64Photo, "Foto Sesudah");
          if (uploaded) {
            var cleanPath = String(folderPathVal || "").replace(/[\/\\]+$/, "");
            normPayload["foto sesudah"] = cleanPath + "\\" + uploaded.name;
            normPayload["link foto sesudah"] = uploaded.url;
          }
        } catch (photoErr) {
          console.error("Upload foto har gagal:", photoErr);
        }
      } else if (normPayload["foto sesudah"]) {
        var rawName = String(normPayload["foto sesudah"]).trim();
        if (rawName && rawName.indexOf("\\") < 0 && rawName.indexOf("/") < 0) {
          var cleanFolderPath = String(folderPathVal || "").replace(/[\/\\]+$/, "");
          normPayload["foto sesudah"] = cleanFolderPath + "\\" + rawName;
        }
      }

      for (var c = 0; c < h.length; c++) {
        var n = normalize_(h[c]);
        if (WO_HAR_MUTABLE_HEADERS.indexOf(n) >= 0 && normPayload[n] !== undefined) {
          out[c] = safeCell_(normPayload[n]);
        }
      }
      if (ix["status wo"] !== undefined) out[ix["status wo"]] = "Selesai";
      sh.getRange(targetRow, 1, 1, h.length).setValues([out]);
      done++;
    }
    SpreadsheetApp.flush();
    return { success: true, diproses: done, diperbarui: done };
  } finally {
    lock.releaseLock();
  }
}

// ----------------------------------------------------
// UTILS & USER SESSION
// ----------------------------------------------------
function findUser_(u) {
  var s = getSpreadsheet_().getSheetByName(CONFIG.USERS_SHEET);
  if (!s) throw new Error("User sheet missing");
  var r = s.getDataRange().getDisplayValues(), t = normalize_(u);
  for (var i = 1; i < r.length; i++) if (normalize_(r[i][USER_COL.username]) === t) return r[i].slice();
  return null;
}

function userFromRow_(r) {
  return {
    no: String(r[0] || ""),
    kodeUiw: String(r[1] || ""),
    kodeUp3: String(r[2] || ""),
    kodeUlp: String(r[3] || ""),
    ulp: String(r[4] || ""),
    username: String(r[5] || ""),
    role: String(r[6] || ""),
    bidang: String(r[7] || ""),
    tim: String(r[8] || ""),
    subTim: String(r[9] || ""),
    aksesMenu: String(r[10] || ""),
  };
}

function headerIndex_(h) {
  var x = {};
  for (var i = 0; i < h.length; i++) x[normalize_(h[i])] = i;
  return x;
}

function rowObject_(h, r) {
  var x = {};
  for (var i = 0; i < h.length; i++) x[h[i] || "kolom_" + (i + 1)] = r[i];
  return x;
}

function numericOrBlank_(v) {
  if (v === "" || v === null || v === undefined) return "";
  var n = Number(String(v).replace(",", "."));
  if (!isFinite(n) || n < 0) throw new Error("Invalid numeric value");
  return n;
}

function safeText_(v, n) {
  return String(v || "").trim().substring(0, n);
}

function safeCell_(v) {
  var s = String(v == null ? "" : v);
  if (/^[=+\-@\t\r]/.test(s)) return "'" + s;
  return s;
}

function safePath_(v) {
  var s = String(v || "").trim().replace(/[\\/:*?"<>|\x00-\x1F]/g, "_").substring(0, 120);
  if (!s || s === "." || s === "..") throw new Error("Invalid path");
  return s;
}

function constantTimeEqual_(a, b) {
  a = String(a); b = String(b);
  var d = a.length ^ b.length, n = Math.max(a.length, b.length);
  for (var i = 0; i < n; i++) d |= (a.charCodeAt(i % (a.length || 1)) || 0) ^ (b.charCodeAt(i % (b.length || 1)) || 0);
  return d === 0;
}

function fail_(c, m) { return { success: false, kode: c, message: m }; }
function normalize_(v) { return String(v || "").trim().toLowerCase().replace(/\s+/g, " "); }
function normalizeCode_(v) { return String(v || "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "").replace(/^0+/, ""); }
function getSpreadsheet_() { return SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID); }
function parseBody_(e) {
  if (!e || !e.postData || !e.postData.contents) throw new Error("Empty body");
  if (e.postData.contents.length > 15 * 1024 * 1024) throw new Error("Payload too large");
  return JSON.parse(e.postData.contents);
}
function sha256_(v) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(v), Utilities.Charset.UTF_8).map(function (b) { var n = b < 0 ? b + 256 : b; return ("0" + n.toString(16)).slice(-2); }).join("");
}
function json_(p) { return ContentService.createTextOutput(JSON.stringify(p)).setMimeType(ContentService.MimeType.JSON); }
function evictOldestDeviceIfNeeded_(username) {
  var MAX_DEVICE_PER_USER = 3;
  var props = PropertiesService.getScriptProperties();
  var all = props.getProperties();
  var devices = [];
  for (var key in all) {
    if (key.indexOf("device_") !== 0) continue;
    try {
      var rec = JSON.parse(all[key]);
      if (normalize_(rec.username) === username) devices.push({ key: key, lastUsedAt: Number(rec.lastUsedAt || 0) });
    } catch (_) {}
  }
  if (devices.length < MAX_DEVICE_PER_USER) return;
  devices.sort(function (a, b) { return a.lastUsedAt - b.lastUsedAt; });
  for (var i = 0; i <= devices.length - MAX_DEVICE_PER_USER; i++) props.deleteProperty(devices[i].key);
}
