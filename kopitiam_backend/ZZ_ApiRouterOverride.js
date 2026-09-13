/* Final API router override with split master endpoints. */
function doPost(e) {
  try {
    var body = parseBody_(e);
    var action = String(body.action || '').trim();
    var quota = consumeActionQuota_(action, runtimeIdentity_(body));
    if (!quota.success) return json_(quota);
    if (action === 'login' || action === 'loginPerangkat') return json_(loginPerangkat_(body.username, body.password, body.perangkat));
    if (action === 'cekPerangkat') return json_(cekPerangkat_(body.deviceToken));
    if (action === 'getRoleProfile' || action === 'getProfilPeran') return json_(getRoleProfile_(body.token));
    if (action === 'logoutPerangkat') return json_(logoutPerangkat_(body.deviceToken, body.token));
    if (action === 'cekSesi') return json_(cekSesi_(body.token));
    if (action === 'logout') return json_(logout_(body.token));
    if (action === 'getMasterData') return json_(getMasterData_(body.token));
    if (action === 'getMasterGardu') return json_(getMasterGardu_(body.token));
    if (action === 'getWoInsjar') return json_(getWoInsjar_(body.token));
    if (action === 'syncWoInsjar') return json_(syncWoCoreVerified_(body.token, 'insjar', CONFIG.WO_INSJAR_SHEET, body.rows));
    if (action === 'getWoInsdu') return json_(getWoInsdu_(body.token));
    if (action === 'syncWoInsdu') return json_(syncWoCoreVerified_(body.token, 'insdu', CONFIG.WO_INSDU_SHEET || 'WO_Ins_Du', body.rows));
    if (action === 'getWoRow') return json_(getWoRow_(body.token));
    if (action === 'syncWoRow') return json_(syncWoCoreVerified_(body.token, 'row', CONFIG.WO_ROW_SHEET, body.rows));
    if (action === 'getWoHarJar') return json_(getHarExecution_(body.token, 'jar'));
    if (action === 'getWoHarDu') return json_(getHarExecution_(body.token, 'du'));
    if (action === 'syncWoHarJar' || action === 'syncWoHarDu') {
      var mode = action === 'syncWoHarJar' ? 'jar' : 'du';
      return json_(syncHarVerified_(body.token, mode, body.rows));
    }
    if (action === 'getTemuanInspeksi') return json_(getTemuanInspeksi_(body.token, body.kodeWo));
    if (action === 'syncTemuanInspeksi') return json_(syncTemuanInspeksiIdempotent_(body.token, body.row));
    return json_(fail_('ACTION_INVALID', 'Action API tidak dikenal.'));
  } catch (error) {
    console.error(error && error.stack ? error.stack : error);
    return json_(fail_('SERVER_ERROR', 'Permintaan tidak dapat diproses.'));
  }
}
