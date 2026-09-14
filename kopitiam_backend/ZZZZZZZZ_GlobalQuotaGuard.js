/* Workspace-wide quota guard. Uses the current per-action limits as requested. */
function consumeGlobalActionQuota_(action, now) {
  action = String(action || '').trim();
  var policy = ACTION_LIMITS_[action];
  if (!policy) return { success: true };

  now = Number(now || Date.now());
  var windowMs = policy.seconds * 1000;
  var windowId = Math.floor(now / windowMs);
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
      return fail_(
        'SERVER_BUSY',
        'Server sedang menerima terlalu banyak permintaan. Data lokal tetap aman; coba lagi sebentar.',
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
      'Global quota gagal:',
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
