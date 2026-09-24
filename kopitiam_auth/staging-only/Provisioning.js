/*
 * Copy this file into the Auth STAGING Apps Script editor only.
 * It is excluded from normal clasp pushes by kopitiam_auth/.claspignore.
 */
function provisionStagingTestCredential_() {
  var props = PropertiesService.getScriptProperties();
  var lock = null;
  var stagingInputsClaimed = false;
  try {
    var environment = String(props.getProperty('AUTH_ENVIRONMENT') || '').trim().toUpperCase();
    var authSpreadsheetId = String(props.getProperty('AUTH_SPREADSHEET_ID') || '').trim();
    var stagingSpreadsheetId = String(props.getProperty('AUTH_STAGING_SPREADSHEET_ID') || '').trim();
    if (environment !== 'STAGING' || !authSpreadsheetId || authSpreadsheetId !== stagingSpreadsheetId) {
      throw new Error('Provisioning hanya diizinkan untuk Auth STAGING dengan spreadsheet ID staging yang cocok.');
    }

    stagingInputsClaimed = true;
    var username = authNormalize_(props.getProperty('STAGING_TEST_USERNAME'));
    var password = String(props.getProperty('STAGING_TEST_PASSWORD') || '');
    if (!/^staging\.[a-z0-9][a-z0-9._-]{0,50}$/.test(username)) {
      throw new Error('STAGING_TEST_USERNAME wajib diawali staging. dan hanya berisi karakter yang diizinkan.');
    }
    if (password.length < 12 || password.length > 128) {
      throw new Error('STAGING_TEST_PASSWORD harus berisi 12 sampai 128 karakter.');
    }

    lock = LockService.getScriptLock();
    lock.waitLock(20000);
    var sheet = authSheet_();
    var values = sheet.getDataRange().getDisplayValues();
    var index = authHeaderIndex_(values[0] || []);
    for (var row = 1; row < values.length; row++) {
      if (authNormalize_(values[row][index.username]) === username) {
        throw new Error('Akun uji staging sudah ada; fungsi ini tidak mengubah akun yang ada.');
      }
    }

    var salt = authBytesHex_(Utilities.computeDigest(
      Utilities.DigestAlgorithm.SHA_256,
      Utilities.getUuid() + Utilities.getUuid(),
      Utilities.Charset.UTF_8,
    ));
    var iterations = AUTH_CONFIG_.PBKDF2_ITERATIONS;
    var passwordHash = authPbkdf2Hex_(password, salt, iterations);
    if (!/^[a-f0-9]{64}$/i.test(passwordHash)) {
      throw new Error('Hash kata sandi staging gagal dibuat.');
    }
    sheet.getRange(sheet.getLastRow() + 1, 1, 1, AUTH_HEADERS_.length).setValues([[
      username,
      passwordHash,
      salt,
      iterations,
      1,
      'Aktif',
      new Date().toISOString(),
      'false',
    ]]);
    return { success: true, created: true, username: username };
  } finally {
    if (stagingInputsClaimed) {
      props.deleteProperty('STAGING_TEST_PASSWORD');
      props.deleteProperty('STAGING_TEST_USERNAME');
    }
    if (lock) lock.releaseLock();
  }
}
