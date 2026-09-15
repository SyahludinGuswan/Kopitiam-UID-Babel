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
function validateFindingMaster_(object,tier,finding,priority){var sheet=getSpreadsheet_().getSheetByName("Master_Temuan");if(!sheet)return fail_("MASTER_SHEET_MISSING","Master_Temuan tidak tersedia.");var values=sheet.getDataRange().getDisplayValues();if(values.length<2)return fail_("MASTER_EMPTY","Master temuan kosong.");var index=headerIndex_(values[0]),findingIndex=index.temuan!==undefined?index.temuan:index["nama temuan"],objectIndex=index["objek inspeksi"]!==undefined?index["objek inspeksi"]:index["jenis object"],tierIndex=index.tier,priorityIndex=index.prioritas;if(findingIndex===undefined||tierIndex===undefined)return fail_("MASTER_HEADERS_INVALID","Header Master_Temuan belum valid.");for(var row=1;row<values.length;row++){var rowFinding=String(values[row][findingIndex]||"").trim(),rowTier=String(values[row][tierIndex]||"").trim(),rowObject=objectIndex===undefined?"":String(values[row][objectIndex]||"").trim();if(normalize_(rowFinding)!==normalize_(finding)||normalize_(rowTier)!==normalize_(tier)||(rowObject&&normalize_(rowObject).indexOf(normalize_(object))<0))continue;var expected=priorityIndex===undefined?"":String(values[row][priorityIndex]||"").trim();if(expected&&!isVegetasiFinding_(finding)&&normalize_(expected)!==normalize_(priority))return fail_("PRIORITY_MISMATCH","Prioritas tidak sesuai master.");return{success:true};}return fail_("FINDING_MASTER_INVALID","Kombinasi Object, Tier, dan Temuan tidak terdaftar.");}
