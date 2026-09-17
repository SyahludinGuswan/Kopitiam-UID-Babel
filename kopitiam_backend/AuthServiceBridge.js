/* Signed internal client for the separate Kopitiam authentication project. */
var AUTH_SERVICE_MAX_SKEW_MS_ = 5 * 60 * 1000;

function authServiceConfig_() {
  var props = PropertiesService.getScriptProperties();
  var url = String(props.getProperty('AUTH_SERVICE_URL') || '').trim();
  var secret = String(props.getProperty('AUTH_SERVICE_SHARED_SECRET') || '');
  if (!/^https:\/\/script\.google\.com\/macros\/s\/[A-Za-z0-9_-]+\/exec$/.test(url) || secret.length < 32) {
    throw new Error('Auth service belum dikonfigurasi.');
  }
  return { url: url, secret: secret };
}

function authServiceCall_(action, payload) {
  var config;
  try { config = authServiceConfig_(); }
  catch (_) { return fail_('AUTHORIZATION_UNAVAILABLE', 'Layanan autentikasi belum siap. Coba lagi nanti.'); }
  action = String(action || '').trim();
  payload = payload || {};
  var timestamp = Date.now();
  var nonce = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '');
  var payloadJson = JSON.stringify(payload);
  var signed = action + '\n' + timestamp + '\n' + nonce + '\n' + payloadJson;
  var envelope = { action: action, timestamp: timestamp, nonce: nonce, payloadJson: payloadJson, signature: hmacSha256Hex_(config.secret, signed) };
  try {
    var response = UrlFetchApp.fetch(config.url, { method: 'post', contentType: 'application/json', payload: JSON.stringify(envelope), muteHttpExceptions: true, followRedirects: true });
    var status = response.getResponseCode();
    var text = response.getContentText();
    if (status < 200 || status >= 300 || text.length > 32 * 1024) throw new Error('HTTP ' + status);
    var result = JSON.parse(text);
    if (!result || typeof result !== 'object' || typeof result.success !== 'boolean') throw new Error('Respons tidak valid');
    return result;
  } catch (error) {
    console.error('Auth service gagal:', error && error.stack ? error.stack : error);
    return fail_('AUTHORIZATION_UNAVAILABLE', 'Layanan autentikasi belum dapat dihubungi. Coba lagi nanti.');
  }
}

function hmacSha256Hex_(secret, message) {
  return Utilities.computeHmacSha256Signature(String(message), String(secret), Utilities.Charset.UTF_8).map(function (byte) {
    var value = byte < 0 ? byte + 256 : byte;
    return ('0' + value.toString(16)).slice(-2);
  }).join('');
}

function operationalSession_(auth) {
  var username = String(auth && auth.username || '').trim();
  var token = String(auth && auth.token || '').trim();
  var deviceToken = String(auth && auth.deviceToken || '').trim();
  if (!username || !/^[a-f0-9]{64}$/i.test(token) || !/^[a-f0-9]{64}$/i.test(deviceToken)) return fail_('SESSION_INVALID', 'Respons sesi autentikasi tidak valid.');
  var account = accountStatus_(username);
  var row = findUser_(username);
  if (!account.exists || !account.active || !row) return fail_('ACCOUNT_INACTIVE', 'Akun tidak aktif atau tidak ditemukan.');
  var session = userFromRow_(row);
  session.success = true;
  session.token = token;
  session.deviceToken = deviceToken;
  session.authVersion = Number(auth.authVersion || 0);
  return session;
}