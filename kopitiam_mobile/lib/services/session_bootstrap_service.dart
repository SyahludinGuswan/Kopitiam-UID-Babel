import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'device_session_service.dart';
import 'role_provider.dart';

class SessionBootstrapService {
  static const sessionKeys = [
    'token',
    'deviceToken',
    'username',
    'role',
    'roleVerifiedOnline',
    'kodeUiw',
    'kodeUp3',
    'kodeUlp',
    'ulp',
    'bidang',
    'tim',
    'subTim',
    'aksesMenu',
  ];

  static Future<Map<String, dynamic>?> restore() async {
    final deviceToken = await DeviceSessionService.token();
    if (deviceToken.isEmpty) return null;

    try {
      final result = await ApiService.cekPerangkat();
      if (result['success'] != true) {
        await clearPreferencesOnly();
        await DeviceSessionService.clear();
        return null;
      }
      var session = RoleProvider.markOnline(Map<String, dynamic>.from(result));
      session = await RoleProvider.verifyOnline(session);
      await DeviceSessionService.save(
        deviceToken: (session['deviceToken'] ?? deviceToken).toString(),
        profile: session,
      );
      await _savePreferences(session);
      return session;
    } catch (_) {
      final cached = await DeviceSessionService.profile();
      final verifiedAt = await DeviceSessionService.verifiedAt();
      final owner = await DeviceSessionService.verifiedUsername();
      final now = DateTime.now().toUtc();
      if (cached == null ||
          owner.isEmpty ||
          DeviceSessionService.normalizeUsername(cached['username']) != owner ||
          verifiedAt == null ||
          now.isBefore(verifiedAt) ||
          now.difference(verifiedAt) >= const Duration(days: 1)) {
        return null;
      }
      final session = RoleProvider.markOffline(cached, verifiedAt);
      await _savePreferences(session);
      return session;
    }
  }

  static Future<void> _savePreferences(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in sessionKeys) {
      await prefs.setString(key, (session[key] ?? '').toString());
    }
    final offline = session['offlineLogin'] == true;
    await prefs.setBool('offlineLogin', offline);
    if (offline) {
      await prefs.setString(
        'offlineExpiresAt',
        (session['offlineExpiresAt'] ?? '').toString(),
      );
    } else {
      await prefs.remove('offlineExpiresAt');
    }
  }

  static Future<void> clearPreferencesOnly() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in sessionKeys) {
      await prefs.remove(key);
    }
    await prefs.remove('offlineLogin');
    await prefs.remove('offlineExpiresAt');
  }
}
