/* Fail-closed live authorization check for every protected request. */
var LIVE_AUTH_PUBLIC_ACTIONS_ = {
  login: true,
  loginPerangkat: true,
  cekPerangkat: true,
  logout: true,
  logoutPerangkat: true
};

var LIVE_AUTH_FIELDS_ = [
  'username',
  'kodeUiw',
  'kodeUp3',
  'kodeUlp',
  'ulp',
  'role',
  'bidang',
  'tim',
  'subTim',
  'aksesMenu'
];

function liveAuthorizationSame_(cached, current) {
  return LIVE_AUTH_FIELDS_.every(function (field) {
    var left = field.indexOf('kode') === 0
      ? normalizeCode_(cached[field])
      : normalize_(cached[field]);
    var right = field.indexOf('kode') === 0
      ? normalizeCode_(current[field])
      : normalize_(current[field]);
    return left === right;
  });
}

function requireLiveAuthorization_(action, token) {
  action = String(action || '').trim();
  if (LIVE_AUTH_PUBLIC_ACTIONS_[action]) return { success: true };
  try {
    var auth = cekSesi_(token);
    if (!auth.success) return auth;
    var row = findUser_(auth.sesi.username);
    var status = accountStatus_(auth.sesi.username);
    if (!row || !status.exists || !status.active) {
      revokeBoundSession_(token, auth.sesi.deviceToken);
      return fail_('ACCOUNT_INACTIVE', 'Akun tidak aktif atau tidak ditemukan. Silakan login ulang.');
    }
    var current = userFromRow_(row);
    if (!liveAuthorizationSame_(auth.sesi, current)) {
      revokeBoundSession_(token, auth.sesi.deviceToken);
      return fail_('AUTHORIZATION_CHANGED', 'Role, unit, atau tim akun berubah. Silakan login ulang.');
    }
    return { success: true, sesi: current };
  } catch (error) {
    console.error('Live authorization gagal:', error && error.stack ? error.stack : error);
    return fail_('AUTHORIZATION_UNAVAILABLE', 'Hak akses belum dapat diverifikasi. Coba lagi saat server tersedia.');
  }
}
