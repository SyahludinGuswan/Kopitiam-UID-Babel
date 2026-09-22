var ACTION_LIMITS_ = {
  loginPerangkat: { limit: 70, seconds: 300 },
  login: { limit: 70, seconds: 300 },
  logoutPerangkat: { limit: 20, seconds: 60 },
  cekPerangkat: { limit: 20, seconds: 60 },
  cekSesi: { limit: 30, seconds: 60 },
  logout: { limit: 20, seconds: 60 },
  getRoleProfile: { limit: 30, seconds: 60 },
  getProfilPeran: { limit: 30, seconds: 60 },
  getMasterData: { limit: 10, seconds: 60 },
  getMasterGardu: { limit: 10, seconds: 60 },
  getWoInsjar: { limit: 20, seconds: 60 },
  getWoInsdu: { limit: 20, seconds: 60 },
  getWoRow: { limit: 20, seconds: 60 },
  getWoHarJar: { limit: 20, seconds: 60 },
  getWoHarDu: { limit: 20, seconds: 60 },
  getTemuanInspeksi: { limit: 30, seconds: 60 },
  syncWoInsjar: { limit: 10, seconds: 60 },
  syncWoInsdu: { limit: 10, seconds: 60 },
  syncWoRow: { limit: 10, seconds: 60 },
  syncWoHarJar: { limit: 10, seconds: 60 },
  syncWoHarDu: { limit: 10, seconds: 60 },
  syncTemuanInspeksi: { limit: 6, seconds: 60 },
};

function validateDeviceRecord_(record, now) {
  now = Number(now || Date.now());
  if (!record || typeof record !== "object") return "DEVICE_CORRUPT";
  var createdAt = Number(record.createdAt || 0);
  var lastUsedAt = Number(record.lastUsedAt || createdAt || 0);
  if (!createdAt || !lastUsedAt || createdAt > now || lastUsedAt > now) return "DEVICE_TIME_INVALID";
  if (now - createdAt >= 7 * 24 * 60 * 60 * 1000) return "DEVICE_MAX_AGE";
  if (now - lastUsedAt >= 1 * 24 * 60 * 60 * 1000) return "DEVICE_IDLE_EXPIRED";
  return "";
}

function consumeActionQuota_(action, identity) {
  var policy = ACTION_LIMITS_[String(action || "")];
  if (!policy) return { success: true };
  var subject = sha256_(String(identity || "anonymous")).substring(0, 24);
  var key = "quota_" + action + "_" + subject;
  var cache = CacheService.getScriptCache();
  var count = Number(cache.get(key) || 0) + 1;
  cache.put(key, String(count), policy.seconds);
  return count > policy.limit
    ? fail_("ACTION_RATE_LIMIT", "Terlalu banyak permintaan. Coba lagi sebentar.")
    : { success: true };
}

function accountStatus_(username) {
  var sheet = getSpreadsheet_().getSheetByName(CONFIG.USERS_SHEET);
  if (!sheet) throw new Error("User sheet missing");
  var values = sheet.getDataRange().getDisplayValues();
  if (!values.length) return { exists: false, active: false };
  var index = headerIndex_(values[0]);
  var usernameIndex = index.username;
  var statusIndex = index.status;
  for (var row = 1; row < values.length; row++) {
    if (normalize_(values[row][usernameIndex]) !== normalize_(username)) continue;
    if (statusIndex === undefined) return { exists: true, active: true };
    var status = normalize_(values[row][statusIndex]);
    return { exists: true, active: ["aktif", "active", "1", "true"].indexOf(status) >= 0 };
  }
  return { exists: false, active: false };
}

var C4A_ALLOWED_ROLES_ = ["super user", "superuser", "admin", "pegawai pln"];
function normalizeRole_(value) { return String(value == null ? "" : value).trim().toLowerCase().replace(/\s+/g, " "); }
function canonicalRole_(value) { var role=normalizeRole_(value);if(role==="superuser"||role==="super user")return "Super User";if(role==="admin")return "Admin";if(role==="pegawai pln")return "Pegawai PLN";return String(value==null?"":value).trim(); }
function isC4aRoleAllowed_(value) { return C4A_ALLOWED_ROLES_.indexOf(normalizeRole_(value)) >= 0; }
function activeRoleProfile_(session) { if(!session||typeof session!=="object")return fail_("SESSION_INVALID","Sesi tidak valid.");var username=String(session.username||"").trim();if(!username)return fail_("ACCOUNT_INACTIVE","Akun tidak ditemukan.");var row=findUser_(username),status=accountStatus_(username);if(!row||!status.exists||!status.active)return fail_("ACCOUNT_INACTIVE","Akun tidak aktif atau tidak ditemukan.");var profile=userFromRow_(row);profile.role=canonicalRole_(profile.role);profile.canAccessC4a=isC4aRoleAllowed_(row[USER_COL.role]);return{success:true,profile:profile,role:profile.role,canAccessC4a:profile.canAccessC4a}; }
function requireC4aAccess_(session) { var profile=activeRoleProfile_(session);if(!profile.success)return profile;if(!profile.canAccessC4a)return fail_("C4A_ACCESS_DENIED","Role akun tidak memiliki akses C4A.");return profile; }
var VEGETASI_TEMUAN_ = ["Rabas / Pangkas", "Tebang Sedang", "Tebang Besar"];
function isVegetasiFinding_(finding) { var text=String(finding||"").trim().toLowerCase();return VEGETASI_TEMUAN_.some(function(value){return String(value).trim().toLowerCase()===text;}); }

function findingMasterColumn_(index, names) {
  for (var i = 0; i < names.length; i++) {
    var column = index[normalize_(names[i])];
    if (column !== undefined) return column;
  }
  return -1;
}

function findingPriority_(finding, expected, incoming) {
  if (!isVegetasiFinding_(finding)) return String(expected || '').trim();
  var distance = Number(String(incoming['Jarak Terhadap Jaringan'] == null ? '' : incoming['Jarak Terhadap Jaringan']).replace(',', '.'));
  var height = Number(String(incoming['Tinggi Pohon'] == null ? '' : incoming['Tinggi Pohon']).replace(',', '.'));
  if (!isFinite(distance) || !isFinite(height) || distance < 0 || height <= 0) return '';
  if (height >= distance * Math.sqrt(2)) return 'Mayor';
  if (height < 9) return distance > 5 ? 'Minor' : 'Mayor';
  if (distance < 3) return 'Mayor';
  if (distance < 6) return 'Sedang';
  return 'Minor';
}

function resolveFindingMaster_(object, finding, incoming) {
  var sheet = getSpreadsheet_().getSheetByName('Master_Temuan');
  if (!sheet) return fail_('MASTER_SHEET_MISSING', 'Master_Temuan tidak tersedia.');
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return fail_('MASTER_EMPTY', 'Master temuan kosong.');
  var index = headerIndex_(values[0]);
  var findingColumn = findingMasterColumn_(index, ['Temuan', 'Nama Temuan']);
  var objectColumn = findingMasterColumn_(index, ['Objek Inspeksi', 'Object Inspeksi', 'Jenis Object', 'Jenis Objek']);
  var tierColumn = findingMasterColumn_(index, ['Tier']);
  var priorityColumn = findingMasterColumn_(index, ['Prioritas']);
  if (findingColumn < 0 || objectColumn < 0 || tierColumn < 0 || priorityColumn < 0) {
    return fail_('MASTER_HEADERS_INVALID', 'Header Object, Tier, Temuan, atau Prioritas belum lengkap.');
  }
  var matches = [];
  for (var row = 1; row < values.length; row++) {
    if (normalize_(values[row][findingColumn]) !== normalize_(finding)) continue;
    if (normalize_(values[row][objectColumn]) !== normalize_(object)) continue;
    matches.push(values[row]);
  }
  if (matches.length !== 1) return fail_('FINDING_MASTER_AMBIGUOUS', 'Temuan pusat tidak ditemukan secara unik untuk Jenis Object tersebut.');
  var source = matches[0];
  var tier = String(source[tierColumn] || '').trim();
  var priority = findingPriority_(finding, source[priorityColumn], incoming || {});
  if (!tier || !priority) return fail_('FINDING_MASTER_INVALID', 'Tier atau Prioritas pusat tidak dapat diturunkan.');
  return {
    success: true,
    object: String(source[objectColumn] || '').trim(),
    tier: tier,
    finding: String(source[findingColumn] || '').trim(),
    priority: priority
  };
}

function findingUnitMatch_(row, index, context) {
  var codeColumn = findingMasterColumn_(index, ['Kode ULP']);
  var nameColumn = findingMasterColumn_(index, ['ULP']);
  if (codeColumn >= 0 && String(row[codeColumn] || '').trim()) {
    return normalizeCode_(row[codeColumn]) === normalizeCode_(context.kodeUlp);
  }
  return nameColumn >= 0 && normalize_(row[nameColumn]) === normalize_(context.values.ULP);
}

function resolveFindingAsset_(object, incoming, context) {
  var spreadsheet = getSpreadsheet_();
  if (object === 'Gardu') {
    var garduSheet = spreadsheet.getSheetByName('Master_Gardu');
    if (!garduSheet) return fail_('MASTER_SHEET_MISSING', 'Master_Gardu tidak tersedia.');
    var garduValues = garduSheet.getDataRange().getDisplayValues();
    var garduIndex = headerIndex_(garduValues[0] || []);
    var garduColumn = findingMasterColumn_(garduIndex, ['GARDU', 'Nomor Gardu']);
    var matches = [];
    for (var row = 1; row < garduValues.length; row++) {
      if (findingUnitMatch_(garduValues[row], garduIndex, context) && normalize_(garduValues[row][garduColumn]) === normalize_(incoming['Nomor Gardu'])) matches.push(garduValues[row]);
    }
    if (garduColumn < 0 || matches.length !== 1) return fail_('ASSET_MASTER_INVALID', 'Gardu pusat tidak ditemukan secara unik untuk ULP akun.');
    var source = matches[0];
    var feederColumn = findingMasterColumn_(garduIndex, ['PENYULANG', 'Nama Penyulang']);
    var sectionColumn = findingMasterColumn_(garduIndex, ['PTS/LBS', 'Section', 'Nama Keypoint']);
    return { success: true, values: {
      'Penyulang': feederColumn < 0 ? '' : source[feederColumn],
      'Section Awal': '', 'Section Akhir': '',
      'Section': sectionColumn < 0 ? '' : source[sectionColumn],
      'Nomor Gardu': source[garduColumn]
    } };
  }

  var feederSheet = spreadsheet.getSheetByName('Master_Penyulang');
  var keypointSheet = spreadsheet.getSheetByName('Master_Keypoint');
  if (!feederSheet || !keypointSheet) return fail_('MASTER_SHEET_MISSING', 'Master_Penyulang atau Master_Keypoint tidak tersedia.');
  var feederValues = feederSheet.getDataRange().getDisplayValues();
  var feederIndex = headerIndex_(feederValues[0] || []);
  var feederColumn = findingMasterColumn_(feederIndex, ['Nama Penyulang', 'Penyulang']);
  var feederMatches = feederValues.slice(1).filter(function (row) {
    return findingUnitMatch_(row, feederIndex, context) && feederColumn >= 0 && normalize_(row[feederColumn]) === normalize_(incoming.Penyulang);
  });
  if (feederMatches.length !== 1) return fail_('ASSET_MASTER_INVALID', 'Penyulang pusat tidak ditemukan secara unik untuk ULP akun.');
  var keypointValues = keypointSheet.getDataRange().getDisplayValues();
  var keypointIndex = headerIndex_(keypointValues[0] || []);
  var keypointFeeder = findingMasterColumn_(keypointIndex, ['Penyulang', 'Nama Penyulang']);
  var keypointName = findingMasterColumn_(keypointIndex, ['Nama Keypoint', 'Keypoint', 'Section']);
  function keypointMatches_(name) {
    return keypointValues.slice(1).filter(function (row) {
      return findingUnitMatch_(row, keypointIndex, context) &&
        keypointFeeder >= 0 && normalize_(row[keypointFeeder]) === normalize_(incoming.Penyulang) &&
        keypointName >= 0 && normalize_(row[keypointName]) === normalize_(name);
    });
  }
  var start = String(incoming['Section Awal'] || '').trim();
  var end = String(incoming['Section Akhir'] || '').trim();
  if (!start || !end || normalize_(start) === normalize_(end) || keypointMatches_(start).length !== 1 || keypointMatches_(end).length !== 1) {
    return fail_('ASSET_MASTER_INVALID', 'Relasi Penyulang dan Section tidak valid pada sumber pusat.');
  }
  return { success: true, values: {
    'Penyulang': feederMatches[0][feederColumn],
    'Section Awal': start, 'Section Akhir': end,
    'Section': start + ' - ' + end, 'Nomor Gardu': ''
  } };
}

function validateFindingMaster_(object,tier,finding,priority,incoming){var resolved=resolveFindingMaster_(object,finding,incoming||{});if(!resolved.success)return resolved;if(normalize_(resolved.tier)!==normalize_(tier))return fail_('TIER_MISMATCH','Tier tidak sesuai sumber pusat.');if(normalize_(resolved.priority)!==normalize_(priority))return fail_('PRIORITY_MISMATCH','Prioritas tidak sesuai sumber pusat.');return resolved;}
