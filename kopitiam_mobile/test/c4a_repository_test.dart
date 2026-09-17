import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/temuan_inspeksi.dart';

void main() {
  group('C4A phase 2 delivery state', () {
    test('new local rows normalize to queued and server rows to synced', () {
      final queued = TemuanInspeksi.fromMap({
        'kode_temuan': 'PEG-16140260908001.TO-001',
        'kode_wo': '',
        'is_dirty': 1,
      });
      expect(queued.syncStatus, TemuanInspeksi.statusQueued);
      expect(queued.dirty, true);

      final synced = TemuanInspeksi.fromRemote({
        'Kode Temuan': 'PEG-16140260908001.TO-001',
        'Kode WO': '',
      });
      expect(synced.syncStatus, TemuanInspeksi.statusSynced);
      expect(synced.dirty, false);
    });

    test('sending is recovered as queued after application restart', () {
      final recovered = TemuanInspeksi.fromMap({
        'kode_temuan': 'PEG-16140260908002.TO-002',
        'kode_wo': '',
        'is_dirty': 1,
        'sync_status': TemuanInspeksi.statusSending,
        'retry_count': 2,
        'sync_error': 'timeout',
      });
      expect(recovered.syncStatus, TemuanInspeksi.statusQueued);
      expect(recovered.retryCount, 2);
      expect(recovered.syncError, 'timeout');
    });

    test(
      'repository exposes query, durable queue, validation and retry service',
      () {
        final source = File('lib/services/temuan_repository.dart')
            .readAsStringSync();
        expect(source, contains('Future<List<TemuanInspeksi>> daftarC4a'));
        expect(source, contains("kode_wo = '' AND is_dirty = 1"));
        expect(source, contains('validateC4a(item)'));
        expect(source, contains('Future<C4aSyncResult> sinkronC4a'));
        expect(source, contains('Future<bool> kirimUlangC4a'));
        expect(source, contains('class C4aSyncService'));
        expect(source, contains("..['Kode WO'] = ''"));
        expect(source, contains("..['Jenis WO'] = ''"));
      },
    );

    test(
      'dashboard provides local list, sync button, failed retry and FAB',
      () {
        final source = File('lib/screens/dashboard_unified.dart')
            .readAsStringSync();
        expect(source, contains('class C4aFindingsHome'));
        expect(source, contains("label: const Text('Sinkron')"));
        expect(source, contains("label: const Text('Kirim ulang')"));
        expect(source, contains('floatingActionButton: FloatingActionButton'));
        expect(source, contains('TemuanFormScreen.c4a'));
      },
    );

    test('clean Kopitiam baseline includes queue and Gardu fields', () {
      final source = File('lib/services/sqlite_service.dart')
          .readAsStringSync();
      final helper = File('lib/services/database_helper.dart')
          .readAsStringSync();
      final storage = File('lib/services/local_account_storage.dart')
          .readAsStringSync();
      expect(storage, contains("_databasePrefix = 'kopitiam_account_'"));
      expect(storage, contains("_accountsDirectory = 'kopitiam_accounts'"));
      expect(source, contains('databaseVersion = 1'));
      expect(source, isNot(contains('onUpgrade:')));
      for (final column in [
        'sync_status',
        'sync_error',
        'retry_count',
        'last_attempt_at',
      ]) {
        expect(source, contains(column));
      }
      for (final column in [
        'jurusan_terpasang',
        'jurusan_terpakai',
        'koordinat_penginputan_wbp',
        'jarak_gardu_petugas_wbp',
        'koordinat_penginputan_lwbp',
        'jarak_gardu_petugas_lwbp',
      ]) {
        expect(helper, contains(column));
      }
      expect(source, contains('idx_temuan_c4a_queue'));
    });
  });
}
