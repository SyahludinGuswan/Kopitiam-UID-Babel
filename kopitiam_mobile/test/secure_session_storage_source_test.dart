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

    expect(login, isNot(contains('SharedPreferences')));
    expect(main, isNot(contains('SharedPreferences')));
    expect(bootstrap, isNot(contains('prefs.set')));
    expect(bootstrap, isNot(contains('prefs.get')));
    expect(deviceSession, contains('FlutterSecureStorage'));
    expect(api, contains('DeviceSessionService.save'));
    expect(localAuth, contains('FlutterSecureStorage'));
  });
}