/* Per-account quota after live authorization. Payload identity is never used. */
function consumeLiveAccountQuota_(action, liveSession, now) {
  action = String(action || '').trim();
  var policy = ACTION_LIMITS_[action];
  if (!policy) return { success: true };
  if (!liveSession || typeof liveSession !== 'object') {
    return fail_('SESSION_INVALID', 'Sesi akun belum diverifikasi.');
  }
  var username = normalize_(liveSession.username || '');
  if (!username) {
    return fail_('SESSION_INVALID', 'Identitas akun belum diverifikasi.');
  }

  now = Number(now || Date.now());
  var windowMs = policy.seconds * 1000;
  var windowId = Math.floor(now / windowMs);
  var principal = sha256_('account:' + username).substring(0, 24);
  var key = 'account_quota_' + action + '_' + principal + '_' + windowId;
  var lock = LockService.getScriptLock();
  var locked = false;
  try {
    lock.waitLock(3000);
    locked = true;
    var cache = CacheService.getScriptCache();
    var count = Number(cache.get(key) || 0) + 1;
    cache.put(key, String(count), policy.seconds + 5);
    if (count > policy.limit) {
      return fail_(
        'ACTION_RATE_LIMIT',
        'Terlalu banyak permintaan untuk akun ini. Coba lagi sebentar.',
      );
    }
    return {
      success: true,
      remaining: Math.max(0, policy.limit - count),
      resetAfterSeconds: Math.max(
        1,
        Math.ceil(((windowId + 1) * windowMs - now) / 1000),
      ),
    };
  } catch (error) {
    console.error(
      'Live account quota gagal:',
      error && error.stack ? error.stack : error,
    );
    return fail_(
      'SERVER_BUSY',
      'Server sedang sibuk. Data lokal tetap aman; coba lagi sebentar.',
    );
  } finally {
    if (locked) lock.releaseLock();
  }
}

function consumePreAuthQuota_(action, body) {
  action = String(action || '').trim();
  body = body || {};
  if (action === 'login' || action === 'loginPerangkat') {
    return consumeActionQuota_(action, normalize_(body.username || 'anonymous'));
  }
  if (action === 'cekPerangkat') {
    return consumeActionQuota_(action, String(body.deviceToken || 'anonymous'));
  }
  if (action === 'logout' || action === 'logoutPerangkat') {
    return consumeActionQuota_(
      action,
      String(body.token || body.deviceToken || 'anonymous'),
    );
  }
  return { success: true };
}
