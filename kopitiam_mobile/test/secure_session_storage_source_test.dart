import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('credential dan profil sesi tidak ditulis ke SharedPreferences', () {
    final login = File('lib/screens/widgets/login_sheet.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final bootstrap = File(
      'lib/services/session_bootstrap_service.dart',
    ).readAsStringSync();
    final deviceSession = File(
      'lib/services/device_session_service.dart',
    ).readAsStringSync();
    final api = File('lib/services/api_service.dart').readAsStringSync();
    final localAuth = File(
      'lib/services/local_auth_service.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/screens/settings_session_section.dart',
    ).readAsStringSync();
    final temuanTab = File('lib/screens/temuan_tab.dart').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(login, isNot(contains('SharedPreferences')));
    expect(main, isNot(contains('SharedPreferences')));
    expect(bootstrap, isNot(contains('prefs.set')));
    expect(bootstrap, isNot(contains('prefs.get')));
    expect(deviceSession, contains('FlutterSecureStorage'));
    expect(api, contains('DeviceSessionService.save'));
    expect(localAuth, contains('FlutterSecureStorage'));
    expect(temuanTab, contains('ApiService.logoutPerangkat'));
    expect(temuanTab, contains('SessionBootstrapService.clearSession'));
    expect(settings, contains('ApiService.logoutPerangkat'));
    expect(settings, contains('await _clear()'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
  });
}