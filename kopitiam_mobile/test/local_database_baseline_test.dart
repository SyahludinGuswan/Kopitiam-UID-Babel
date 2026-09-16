import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sqliteSource = File('lib/services/sqlite_service.dart').readAsStringSync();
  final helperSource = File('lib/services/database_helper.dart').readAsStringSync();
  final insjarSource = File('lib/services/wo_insjar_repository.dart').readAsStringSync();
  final insduSource = File('lib/services/wo_insdu_repository.dart').readAsStringSync();

  test('local database uses a clean Kopitiam baseline', () {
    expect(sqliteSource, contains("databaseName = 'kopitiam_local.db'"));
    expect(sqliteSource, contains('databaseVersion = 1'));
    expect(sqliteSource, isNot(contains('simandist_local.db')));
    expect(sqliteSource, isNot(contains('onUpgrade:')));
    expect(sqliteSource, contains('db.transaction'));
  });

  test('all current Insjar and Insdu columns exist in baseline schema', () {
    expect(sqliteSource, contains("tier TEXT NOT NULL DEFAULT ''"));
    for (final column in [
      'jurusan_terpasang', 'jurusan_terpakai', 'kapasitas',
      'arus_maksimal_per_fasa', 'koordinat_penginputan_wbp',
      'waktu_penginputan_wbp', 'jarak_gardu_petugas_wbp',
      'koordinat_penginputan_lwbp', 'waktu_penginputan_lwbp',
      'jarak_gardu_petugas_lwbp',
    ]) {
      expect(helperSource, contains(column), reason: column);
    }
  });

  test('repositories never mutate schema when opened', () {
    expect(insjarSource, isNot(contains('PRAGMA table_info')));
    expect(insjarSource, isNot(contains('ALTER TABLE')));
    expect(insduSource, isNot(contains('PRAGMA table_info')));
    expect(insduSource, isNot(contains('ALTER TABLE')));
  });
}
