/* Private credential authority. Only the operational backend may call doPost. */
var AUTH_CONFIG_ = {
  USERS_SHEET: 'Credentials',
  SESSION_TTL_SEC: 900,
  DEVICE_MAX_AGE_MS: 7 * 24 * 60 * 60 * 1000,
  DEVICE_IDLE_MS: 24 * 60 * 60 * 1000,
  PBKDF2_ITERATIONS: 120000,
  MAX_LOGIN_FAILURES: 5,
  MAX_DEVICES_PER_USER: 3,
  MAX_BODY_BYTES: 32 * 1024,
  MAX_CLOCK_SKEW_MS: 5 * 60 * 1000
};

var AUTH_HEADERS_ = ['Username', 'Password Hash', 'Salt', 'Iterations', 'Auth Version', 'Status', 'Migrated At', 'Reset Required'];

function doGet() {
  return authJson_({ success: false, kode: 'POST_REQUIRED', message: 'Gunakan POST untuk layanan autentikasi.' });
}

function doPost(event) {
  try {
    var envelope = authParseBody_(event);
    var verified = authVerifyEnvelope_(envelope);
    if (!verified.success) return authJson_(verified);
    var result = authDispatch_(envelope.action, verified.payload);
    return authJson_(result);
  } catch (error) {
    console.error(error && error.stack ? error.stack : error);
    return authJson_(authFail_('SERVER_ERROR', 'Permintaan autentikasi tidak dapat diproses.'));
  }
}

function authDispatch_(action, payload) {
  if (action === 'login') return authLogin_(payload.username, payload.password, payload.device);
  if (action === 'refresh') return authRefresh_(payload.deviceToken);
  if (action === 'introspect') return authIntrospect_(payload.token);
  if (action === 'logout') return authLogout_(payload.token, payload.deviceToken);
  return authFail_('ACTION_INVALID', 'Action autentikasi tidak dikenal.');
}

function authVerifyEnvelope_(envelope) {
  if (!envelope || typeof envelope !== 'object') return authFail_('AUTH_REQUEST_INVALID', 'Permintaan internal tidak valid.');
  var action = String(envelope.action || '').trim();
  var timestamp = Number(envelope.timestamp || 0);
  var nonce = String(envelope.nonce || '').trim();
  var payloadJson = String(envelope.payloadJson || '');
  var signature = String(envelope.signature || '').trim();
  if (!action || !/^[a-f0-9]{64}$/i.test(nonce) || !timestamp || Math.abs(Date.now() - timestamp) > AUTH_CONFIG_.MAX_CLOCK_SKEW_MS || payloadJson.length > AUTH_CONFIG_.MAX_BODY_BYTES) return authFail_('AUTH_REQUEST_INVALID', 'Permintaan internal tidak valid.');
  var secret = String(PropertiesService.getScriptProperties().getProperty('AUTH_SERVICE_SHARED_SECRET') || '');
  if (secret.length < 32) return authFail_('AUTH_SERVICE_UNAVAILABLE', 'Layanan autentikasi belum dikonfigurasi.');
  var expected = authHmacHex_(secret, action + '\n' + timestamp + '\n' + nonce + '\n' + payloadJson);
  if (!authConstantTimeEqual_(expected, signature)) return authFail_('AUTH_REQUEST_INVALID', 'Tanda tangan internal tidak valid.');
  var cache = CacheService.getScriptCache(), nonceKey = 'auth_nonce_' + nonce;
  if (cache.get(nonceKey)) return authFail_('AUTH_REQUEST_REPLAY', 'Permintaan internal sudah digunakan.');
  cache.put(nonceKey, '1', Math.ceil(AUTH_CONFIG_.MAX_CLOCK_SKEW_MS / 1000));
  try {
    var payload = JSON.parse(payloadJson);
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) throw new Error('Payload invalid');
    return { success: true, payload: payload };
  } catch (_) {
    return authFail_('AUTH_REQUEST_INVALID', 'Permintaan internal tidak valid.');
  }
}

function authLogin_(username, password, device) {
  username = authNormalize_(username);
  password = String(password || '');
  if (!username || !password) return authFail_('LOGIN_REQUIRED', 'Username dan kata sandi wajib diisi.');
  var cache = CacheService.getScriptCache(), failureKey = 'auth_login_fail_' + authSha256_(username).substring(0, 24), failures = Number(cache.get(failureKey) || 0);
  if (failures >= AUTH_CONFIG_.MAX_LOGIN_FAILURES) return authFail_('LOGIN_RATE_LIMIT', 'Terlalu banyak percobaan. Coba lagi 5 menit.');
  var user = authFindUser_(username);
  var valid = !!user && authUserActive_(user) && !authResetRequired_(user) && authConstantTimeEqual_(authPbkdf2Hex_(password, user.salt, user.iterations), user.passwordHash);
  password = '';
  if (!valid) {
    cache.put(failureKey, String(failures + 1), 300);
    return authFail_('LOGIN_FAILED', 'Username atau kata sandi salah.');
  }
  cache.remove(failureKey);
  var deviceToken = authNewOpaqueToken_();
  authStoreDevice_(username, deviceToken, user.authVersion, device);
  return authIssueSession_(username, deviceToken, user.authVersion);
}

function authRefresh_(deviceToken) {
  var device = authReadDevice_(deviceToken);
  if (!device) return authFail_('DEVICE_UNKNOWN', 'Sesi perangkat tidak dikenali. Silakan login ulang.');
  var expiry = authDeviceExpiry_(device, Date.now());
  if (expiry) { authDeleteDevice_(deviceToken); return authFail_(expiry, 'Sesi perangkat sudah berakhir. Silakan login ulang.'); }
  var user = authFindUser_(device.username);
  if (!user || !authUserActive_(user) || authResetRequired_(user) || Number(device.authVersion) !== Number(user.authVersion)) { authDeleteDevice_(deviceToken); return authFail_('DEVICE_REVOKED', 'Kredensial akun berubah. Silakan login ulang.'); }
  device.lastUsedAt = Date.now();
  authWriteDevice_(deviceToken, device);
  return authIssueSession_(device.username, deviceToken, user.authVersion);
}

function authIntrospect_(token) {
  var session = authReadSession_(token);
  if (!session) return authFail_('SESSION_EXPIRED', 'Sesi tidak valid atau sudah berakhir.');
  var device = authReadDevice_(session.deviceToken);
  var user = authFindUser_(session.username);
  if (!device || authDeviceExpiry_(device, Date.now()) || !user || !authUserActive_(user) || authResetRequired_(user) || Number(session.authVersion) !== Number(user.authVersion) || Number(device.authVersion) !== Number(user.authVersion)) {
    authDeleteSession_(token);
    if (device) authDeleteDevice_(session.deviceToken);
    return authFail_('SESSION_REVOKED', 'Sesi sudah dicabut. Silakan login ulang.');
  }
  device.lastUsedAt = Date.now();
  authWriteDevice_(session.deviceToken, device);
  return { success: true, token: token, deviceToken: session.deviceToken, username: session.username, authVersion: user.authVersion };
}

function authLogout_(token, deviceToken) {
  var session = authReadSession_(token);
  if (!session) return { success: true };
  authDeleteSession_(token);
  authDeleteDevice_(session.deviceToken);
  return { success: true };
}

function authIssueSession_(username, deviceToken, authVersion) {
  var token = authNewOpaqueToken_();
  CacheService.getScriptCache().put('auth_session_' + authSha256_(token), JSON.stringify({ username: username, deviceToken: deviceToken, authVersion: authVersion }), AUTH_CONFIG_.SESSION_TTL_SEC);
  return { success: true, token: token, deviceToken: deviceToken, username: username, authVersion: authVersion };
}

function authReadSession_(token) {
  token = String(token || '').trim();
  if (!/^[a-f0-9]{64}$/i.test(token)) return null;
  var raw = CacheService.getScriptCache().get('auth_session_' + authSha256_(token));
  try { return raw ? JSON.parse(raw) : null; } catch (_) { return null; }
}

function authDeleteSession_(token) {
  token = String(token || '').trim();
  if (/^[a-f0-9]{64}$/i.test(token)) CacheService.getScriptCache().remove('auth_session_' + authSha256_(token));
}

function authStoreDevice_(username, deviceToken, authVersion, device) {
  authEvictOldDevices_(username);
  var now = Date.now();
  authWriteDevice_(deviceToken, { username: username, authVersion: authVersion, device: authSafeText_(device, 120), createdAt: now, lastUsedAt: now });
}

function authReadDevice_(deviceToken) {
  deviceToken = String(deviceToken || '').trim();
  if (!/^[a-f0-9]{64}$/i.test(deviceToken)) return null;
  var raw = PropertiesService.getScriptProperties().getProperty('auth_device_' + authSha256_(deviceToken));
  try { return raw ? JSON.parse(raw) : null; } catch (_) { return null; }
}

function authWriteDevice_(deviceToken, record) {
  PropertiesService.getScriptProperties().setProperty('auth_device_' + authSha256_(deviceToken), JSON.stringify(record));
}

function authDeleteDevice_(deviceToken) {
  deviceToken = String(deviceToken || '').trim();
  if (/^[a-f0-9]{64}$/i.test(deviceToken)) PropertiesService.getScriptProperties().deleteProperty('auth_device_' + authSha256_(deviceToken));
}

function authEvictOldDevices_(username) {
  var props = PropertiesService.getScriptProperties(), all = props.getProperties(), devices = [];
  Object.keys(all).forEach(function (key) { if (key.indexOf('auth_device_') !== 0) return; try { var record = JSON.parse(all[key]); if (authNormalize_(record.username) === username) devices.push({ key: key, lastUsedAt: Number(record.lastUsedAt || 0) }); } catch (_) { props.deleteProperty(key); } });
  devices.sort(function (left, right) { return left.lastUsedAt - right.lastUsedAt; });
  while (devices.length >= AUTH_CONFIG_.MAX_DEVICES_PER_USER) props.deleteProperty(devices.shift().key);
}

function authDeviceExpiry_(record, now) {
  var createdAt = Number(record && record.createdAt || 0), lastUsedAt = Number(record && record.lastUsedAt || 0);
  if (!createdAt || !lastUsedAt || createdAt > now || lastUsedAt > now) return 'DEVICE_TIME_INVALID';
  if (now - createdAt >= AUTH_CONFIG_.DEVICE_MAX_AGE_MS) return 'DEVICE_MAX_AGE';
  if (now - lastUsedAt >= AUTH_CONFIG_.DEVICE_IDLE_MS) return 'DEVICE_IDLE_EXPIRED';
  return '';
}

function authFindUser_(username) {
  var values = authSheet_().getDataRange().getDisplayValues(), index = authHeaderIndex_(values[0] || []), wanted = authNormalize_(username);
  for (var row = 1; row < values.length; row++) if (authNormalize_(values[row][index.username]) === wanted) return { username: wanted, passwordHash: String(values[row][index['password hash']] || ''), salt: String(values[row][index.salt] || ''), iterations: Number(values[row][index.iterations] || 0), authVersion: Number(values[row][index['auth version']] || 0), status: String(values[row][index.status] || ''), resetRequired: String(values[row][index['reset required']] || '') };
  return null;
}

function authUserActive_(user) { return ['aktif', 'active', '1', 'true'].indexOf(authNormalize_(user.status)) >= 0; }
function authResetRequired_(user) { return ['ya', 'yes', '1', 'true'].indexOf(authNormalize_(user.resetRequired)) >= 0; }
function authSheet_() { var id = String(PropertiesService.getScriptProperties().getProperty('AUTH_SPREADSHEET_ID') || '').trim(); if (!/^[A-Za-z0-9_-]{20,}$/.test(id)) throw new Error('AUTH_SPREADSHEET_ID belum dikonfigurasi.'); var sheet = SpreadsheetApp.openById(id).getSheetByName(AUTH_CONFIG_.USERS_SHEET); if (!sheet) throw new Error('Sheet Credentials tidak ditemukan.'); return sheet; }
function authHeaderIndex_(headers) { var index = {}; headers.forEach(function (header, position) { index[authNormalize_(header)] = position; }); AUTH_HEADERS_.forEach(function (header) { if (index[authNormalize_(header)] === undefined) throw new Error('Header Credentials tidak lengkap: ' + header); }); return index; }
function authPbkdf2Hex_(password, salt, iterations) {
  iterations = Number(iterations);
  if (!/^[a-f0-9]{64}$/i.test(String(salt)) || iterations < 100000 || iterations > 500000) return '';
  var keyBytes = Utilities.newBlob(String(password)).getBytes();
  try {
    var block = authHmacBytes_(keyBytes, authHexBytes_(salt).concat([0, 0, 0, 1]));
    var output = block.slice();
    for (var round = 1; round < iterations; round++) {
      block = authHmacBytes_(keyBytes, block);
      for (var index = 0; index < output.length; index++) output[index] = output[index] ^ block[index];
    }
    return authBytesHex_(output);
  } finally {
    for (var byteIndex = 0; byteIndex < keyBytes.length; byteIndex++) keyBytes[byteIndex] = 0;
  }
}

// Native byte-array HMAC avoids two Utilities.computeDigest service calls per PBKDF2 round.
function authHmacBytes_(keyBytes, bytes) {
  return Utilities.computeHmacSha256Signature(bytes, keyBytes);
}

function authHmacHex_(secret, message) { return authBytesHex_(Utilities.computeHmacSha256Signature(String(message), String(secret), Utilities.Charset.UTF_8)); }
function authSha256_(value) { return authBytesHex_(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(value), Utilities.Charset.UTF_8)); }
function authBytesHex_(bytes) { return bytes.map(function (byte) { var value = byte < 0 ? byte + 256 : byte; return ('0' + value.toString(16)).slice(-2); }).join(''); }
function authHexBytes_(value) { var bytes = []; for (var index = 0; index < value.length; index += 2) bytes.push(parseInt(value.substring(index, index + 2), 16)); return bytes; }
function authNewOpaqueToken_() { return Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, ''); }
function authConstantTimeEqual_(left, right) { left = String(left); right = String(right); var difference = left.length ^ right.length, length = Math.max(left.length, right.length); for (var index = 0; index < length; index++) difference |= (left.charCodeAt(index % (left.length || 1)) || 0) ^ (right.charCodeAt(index % (right.length || 1)) || 0); return difference === 0; }
function authNormalize_(value) { return String(value || '').trim().toLowerCase().replace(/\s+/g, ' '); }
function authSafeText_(value, maximum) { return String(value || '').trim().substring(0, maximum); }
function authParseBody_(event) { var text = event && event.postData && event.postData.contents; if (!text) throw new Error('Body kosong'); if (text.length > AUTH_CONFIG_.MAX_BODY_BYTES) throw new Error('Payload terlalu besar'); return JSON.parse(text); }
function authFail_(kode, message) { return { success: false, kode: kode, message: message }; }
function authJson_(value) { return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON); }

function setupAuthService() {
  var id = String(PropertiesService.getScriptProperties().getProperty('AUTH_SPREADSHEET_ID') || '').trim();
  if (!/^[A-Za-z0-9_-]{20,}$/.test(id)) throw new Error('AUTH_SPREADSHEET_ID belum dikonfigurasi.');
  var spreadsheet = SpreadsheetApp.openById(id), sheet = spreadsheet.getSheetByName(AUTH_CONFIG_.USERS_SHEET) || spreadsheet.insertSheet(AUTH_CONFIG_.USERS_SHEET);
  if (sheet.getLastRow() === 0) { sheet.getRange(1, 1, 1, AUTH_HEADERS_.length).setValues([AUTH_HEADERS_]); sheet.setFrozenRows(1); }
  authHeaderIndex_(sheet.getRange(1, 1, 1, sheet.getLastColumn()).getDisplayValues()[0]);
  return { success: true, service: 'Kopitiam Auth', iterations: AUTH_CONFIG_.PBKDF2_ITERATIONS };
}

function migrateLegacyPlaintextPasswords_() {
  var props = PropertiesService.getScriptProperties(), legacyId = String(props.getProperty('LEGACY_USERS_SPREADSHEET_ID') || '').trim();
  if (!/^[A-Za-z0-9_-]{20,}$/.test(legacyId)) throw new Error('LEGACY_USERS_SPREADSHEET_ID belum dikonfigurasi.');
  var legacy = SpreadsheetApp.openById(legacyId).getSheetByName(String(props.getProperty('LEGACY_USERS_SHEET') || 'User_App_Mobile'));
  if (!legacy) throw new Error('Sheet pengguna legacy tidak ditemukan.');
  var source = legacy.getDataRange().getDisplayValues(), sourceIndex = authHeaderIndexLoose_(source[0] || []), target = authSheet_(), targetValues = target.getDataRange().getDisplayValues(), targetIndex = authHeaderIndex_(targetValues[0] || []), existing = {};
  for (var row = 1; row < targetValues.length; row++) existing[authNormalize_(targetValues[row][targetIndex.username])] = true;
  if (sourceIndex.username === undefined || sourceIndex.password === undefined || sourceIndex.status === undefined) throw new Error('Header legacy Username, Password, atau Status tidak lengkap.');
  var rows = [];
  for (var sourceRow = 1; sourceRow < source.length; sourceRow++) {
    var username = authNormalize_(source[sourceRow][sourceIndex.username]), password = String(source[sourceRow][sourceIndex.password] || '');
    if (!username || !password || existing[username]) continue;
    var salt = authBytesHex_(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, Utilities.getUuid() + Utilities.getUuid(), Utilities.Charset.UTF_8));
    rows.push([username, authPbkdf2Hex_(password, salt, AUTH_CONFIG_.PBKDF2_ITERATIONS), salt, AUTH_CONFIG_.PBKDF2_ITERATIONS, 1, source[sourceRow][sourceIndex.status], new Date().toISOString(), 'false']);
  }
  if (rows.length) target.getRange(target.getLastRow() + 1, 1, rows.length, AUTH_HEADERS_.length).setValues(rows);
  return { success: true, migrated: rows.length, skippedExisting: Object.keys(existing).length };
}

function authHeaderIndexLoose_(headers) { var index = {}; headers.forEach(function (header, position) { index[authNormalize_(header)] = position; }); return index; }

function resetCredential_(username, newPassword) {
  username = authNormalize_(username); newPassword = String(newPassword || '');
  if (!username || newPassword.length < 12) throw new Error('Username dan kata sandi minimal 12 karakter wajib diisi.');
  var sheet = authSheet_(), values = sheet.getDataRange().getDisplayValues(), index = authHeaderIndex_(values[0] || []), salt = authBytesHex_(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, Utilities.getUuid() + Utilities.getUuid(), Utilities.Charset.UTF_8));
  for (var row = 1; row < values.length; row++) if (authNormalize_(values[row][index.username]) === username) { sheet.getRange(row + 1, index['password hash'] + 1, 1, 7).setValues([[authPbkdf2Hex_(newPassword, salt, AUTH_CONFIG_.PBKDF2_ITERATIONS), salt, AUTH_CONFIG_.PBKDF2_ITERATIONS, Number(values[row][index['auth version']] || 0) + 1, values[row][index.status], new Date().toISOString(), 'false']]); return { success: true }; }
  throw new Error('Pengguna tidak ditemukan.');
}
