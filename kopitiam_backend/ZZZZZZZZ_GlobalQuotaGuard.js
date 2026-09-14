/* Workspace-wide quota guard. Uses the current per-action limits as requested. */
function globalQuotaBusy_(message, retryAfterSeconds) {
  return {
    success: false,
    kode: 'SERVER_BUSY',
    message: message,
    retryAfterSeconds: Math.max(1, Number(retryAfterSeconds || 1)),
  };
}

function consumeGlobalActionQuota_(action, now) {
  action = String(action || '').trim();
  var policy = ACTION_LIMITS_[action];
  if (!policy) return { success: true };

  now = Number(now || Date.now());
  var windowMs = policy.seconds * 1000;
  var windowId = Math.floor(now / windowMs);
  var resetAfterSeconds = Math.max(
    1,
    Math.ceil(((windowId + 1) * windowMs - now) / 1000),
  );
  var key = 'global_quota_' + action + '_' + windowId;
  var lock = LockService.getScriptLock();
  var locked = false;
  try {
    lock.waitLock(3000);
    locked = true;
    var cache = CacheService.getScriptCache();
    var count = Number(cache.get(key) || 0) + 1;
    cache.put(key, String(count), policy.seconds + 5);
    if (count > policy.limit) {
      return globalQuotaBusy_(
        'Server sedang menerima terlalu banyak permintaan. Data lokal tetap aman; sistem akan mencoba lagi.',
        resetAfterSeconds,
      );
    }
    return {
      success: true,
      remaining: Math.max(0, policy.limit - count),
      resetAfterSeconds: resetAfterSeconds,
    };
  } catch (error) {
    console.error(
      'Global quota gagal:',
      error && error.stack ? error.stack : error,
    );
    return globalQuotaBusy_(
      'Server sedang sibuk. Data lokal tetap aman; sistem akan mencoba lagi.',
      3,
    );
  } finally {
    if (locked) lock.releaseLock();
  }
}
