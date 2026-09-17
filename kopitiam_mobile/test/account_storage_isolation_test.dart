import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/services/local_account_storage.dart';

void main() {
  test('namespace akun stabil, berbeda, dan tidak memuat username mentah', () {
    final first = LocalAccountStorage.namespaceForUsername(' Petugas.A ');
    final equivalent = LocalAccountStorage.namespaceForUsername('petugas.a');
    final second = LocalAccountStorage.namespaceForUsername('petugas.b');

    expect(first, equivalent);
    expect(first, isNot(second));
    expect(first, isNot(contains('petugas.a')));
    expect(first, hasLength(64));
  });

  test('akun kosong ditolak sebelum data lokal dapat dibuka', () {
    expect(
      () => LocalAccountStorage.namespaceForUsername('   '),
      throwsStateError,
    );
  });

  test('database, foto, dan lifecycle memakai namespace akun', () {
    final storage = File('lib/services/local_account_storage.dart')
        .readAsStringSync();
    final sqlite = File('lib/services/sqlite_service.dart').readAsStringSync();
    final bootstrap = File('lib/services/session_bootstrap_service.dart')
        .readAsStringSync();
    final login = File('lib/screens/widgets/login_sheet.dart')
        .readAsStringSync();

    expect(
      storage,
      contains("p.join(root.path, _accountsDirectory, namespace)"),
    );
    expect(storage, contains("_databasePrefix = 'kopitiam_account_'"));
    expect(storage, contains(r"'$_databasePrefix$namespace.db'"));
    expect(storage, isNot(contains('kopitiam_local.db')));
    expect(sqlite, contains('clearActiveAccount'));
    expect(bootstrap, contains('SqliteService.instance.activateForProfile'));
    expect(bootstrap, contains('SqliteService.instance.clearActiveAccount'));
    expect(login, contains('SqliteService.instance.activateForProfile'));

    for (final path in [
      'lib/services/temuan_repository.dart',
      'lib/services/wo_row_repository.dart',
      'lib/services/wo_har_jar_repository.dart',
      'lib/services/wo_har_du_repository.dart',
      'lib/services/har_execution_repository.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('accountDocumentsDirectory'),
        reason: path,
      );
    }
  });
}
