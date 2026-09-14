import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/services/device_session_service.dart';
import 'package:kopitiam_mobile/services/local_auth_service.dart';
import 'package:kopitiam_mobile/services/role_provider.dart';

void main() {
  test('offline account comparison is normalized but never cross-account', () {
    expect(LocalAuthService.sameOfflineAccount(' Koba.Insdu ', 'koba.insdu'), isTrue);
    expect(LocalAuthService.sameOfflineAccount('koba.insdu', 'toboali.insdu'), isFalse);
    expect(LocalAuthService.sameOfflineAccount('', 'koba.insdu'), isFalse);
  });

  test('device owner normalization is stable', () {
    expect(DeviceSessionService.normalizeUsername(' Koba.Insdu '), 'koba.insdu');
  });

  test('online role is trusted only with an explicit true verification flag', () {
    final missing = RoleProvider.fromSession({'username':'u','role':'Admin'});
    final falseFlag = RoleProvider.fromSession({'username':'u','role':'Admin','roleVerifiedOnline':false});
    final verified = RoleProvider.fromSession({'username':'u','role':'Admin','roleVerifiedOnline':true});
    expect(missing.profile.verified, isFalse);
    expect(falseFlag.profile.verified, isFalse);
    expect(verified.profile.verified, isTrue);
  });

  test('offline lease is limited to one day', () {
    final valid = RoleProvider.markOffline(
      {'username':'u','role':'Admin'},
      DateTime.now().toUtc(),
    );
    final expired = RoleProvider.markOffline(
      {'username':'u','role':'Admin'},
      DateTime.now().toUtc().subtract(const Duration(days:1)),
    );
    expect(RoleProvider.fromSession(valid).profile.verified, isTrue);
    expect(RoleProvider.fromSession(expired).profile.verified, isFalse);
  });
}
