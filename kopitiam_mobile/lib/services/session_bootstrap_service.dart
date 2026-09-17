import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'device_session_service.dart';
import 'local_auth_service.dart';
import 'role_provider.dart';
import 'sqlite_service.dart';

class SessionBootstrapService {
  static const _legacySessionKeys = [
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
    await clearLegacyPreferences();
    final deviceToken = await DeviceSessionService.token();
    if (deviceToken.isEmpty) return null;

    try {
      final result = await ApiService.cekPerangkat();
      if (result['success'] != true) {
        await clearSession();
        return null;
      }
      var session = RoleProvider.markOnline(Map<String, dynamic>.from(result));
      session = await RoleProvider.verifyOnline(session);
      await DeviceSessionService.save(
        deviceToken: (session['deviceToken'] ?? deviceToken).toString(),
        profile: session,
      );
      await SqliteService.instance.activateForProfile(session);
      await LocalAuthService.clearOfflineStatus();
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
        await clearSession();
        return null;
      }
      final session = RoleProvider.markOffline(cached, verifiedAt);
      await SqliteService.instance.activateForProfile(session);
      await LocalAuthService.markOfflineUntil(
        verifiedAt.add(const Duration(days: 1)),
      );
      return session;
    }
  }

  static Future<void> clearLegacyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacySessionKeys) {
      await prefs.remove(key);
    }
    await prefs.remove('offlineLogin');
    await prefs.remove('offlineExpiresAt');
  }

  static Future<void> clearSession() async {
    await SqliteService.instance.clearActiveAccount();
    await DeviceSessionService.clear();
    await LocalAuthService.clear();
    await clearLegacyPreferences();
  }
}
