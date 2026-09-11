import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/screens/widgets/master_data_accordion.dart';
import 'package:sqflite/sqflite.dart';

class MasterMemoryDb implements Database, Transaction {
  final metadata = <String, Map<String, Object?>>{};
  final rows = <Map<String, Object?>>[];
  @override
  Future<List<Map<String, Object?>>> query(String table, {
    bool? distinct, List<String>? columns, String? where,
    List<Object?>? whereArgs, String? groupBy, String? having,
    String? orderBy, int? limit, int? offset,
  }) async {
    if (table == 'sync_metadata') return metadata.values.toList();
    return whereArgs?.isNotEmpty == true
        ? rows.where((row) => row['dataset'] == whereArgs!.first).toList()
        : rows;
  }
  @override
  Future<int> insert(String table, Map<String, Object?> values, {
    String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'sync_metadata') {
      metadata['${values['key']}'] = Map<String, Object?>.from(values);
    } else {
      rows.add(Map<String, Object?>.from(values));
    }
    return 1;
  }
  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    if (table == 'master_data_rows' && whereArgs?.isNotEmpty == true) {
      rows.removeWhere((row) => row['dataset'] == whereArgs!.first);
    }
    return 1;
  }
  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) => action(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> metadataRow(String key, String status) => {
  'key': key, 'status': status,
  'error_message': status == 'failed' ? 'Jaringan terputus' : '',
};
Future<void> openAccordion(WidgetTester tester) async {
  await tester.tap(find.text('Master Data'));
  await tester.pumpAndSettle();
}
Widget screen(MasterDataAccordion child) => MaterialApp(home: Scaffold(
  body: SingleChildScrollView(child: child),
));
const keys = ['User_App_Mobile', 'Master_Penyulang', 'Master_Keypoint',
  'Master_Temuan', 'Jenis Pohon', 'Master_Material',
  'Master_Pekerjaan_Har', 'Master_Gardu'];

void main() {
  test('status constants remain compatible', () {
    expect({MasterSyncStatus.pending, MasterSyncStatus.syncing,
      MasterSyncStatus.synced, MasterSyncStatus.failed},
      {'pending', 'syncing', 'synced', 'failed'});
  });

  testWidgets('renders pending, verified and failed datasets with retry', (tester) async {
    final db = MasterMemoryDb()
      ..metadata['Master_Penyulang'] = metadataRow('Master_Penyulang', 'success')
      ..metadata['Master_Gardu'] = metadataRow('Master_Gardu', 'failed');
    await tester.pumpWidget(screen(MasterDataAccordion(
      token: 'token', database: db,
      fetchGeneral: (_) async => {'success': true, 'datasets': {'Master_Penyulang': []}},
    )));
    await tester.pumpAndSettle();
    expect(find.text('SINKRON'), findsWidgets);
    await openAccordion(tester);
    expect(find.text('BELUM SINKRON'), findsWidgets);
    expect(find.text('TERBARU'), findsWidgets);
    expect(find.text('GAGAL'), findsWidgets);
    expect(find.text('Coba Ulang'), findsOneWidget);
  });

  testWidgets('retry changes failed Gardu to synced', (tester) async {
    final db = MasterMemoryDb()
      ..metadata['Master_Gardu'] = metadataRow('Master_Gardu', 'failed');
    await tester.pumpWidget(screen(MasterDataAccordion(
      token: 'token', database: db,
      fetchGardu: (_) async => {'success': true, 'rows': [{'GARDU': 'G1'}]},
    )));
    await tester.pumpAndSettle();
    await openAccordion(tester);
    await tester.ensureVisible(find.text('Coba Ulang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba Ulang'));
    await tester.pumpAndSettle();
    expect(db.metadata['Master_Gardu']?['status'], 'success');
    expect(find.text('Coba Ulang'), findsNothing);
    expect(find.text('TERBARU'), findsWidgets);
  });

  testWidgets('comparison marks changed data but writes only selected update', (tester) async {
    final db = MasterMemoryDb();
    for (final key in keys) {
      db.metadata[key] = metadataRow(key, 'success');
      db.rows.add({'dataset': key, 'payload_json': jsonEncode({'value': 'old'})});
    }
    final payload = {for (final key in keys.where((key) => key != 'Master_Gardu'))
      key: [{'value': key == 'Master_Temuan' ? 'new' : 'old'}]};
    await tester.pumpWidget(screen(MasterDataAccordion(
      token: 'token', database: db,
      fetchGeneral: (_) async => {'success': true, 'datasets': payload},
      fetchGardu: (_) async => {'success': true, 'rows': [{'value': 'old'}]},
    )));
    await tester.pumpAndSettle();
    await openAccordion(tester);
    expect(find.text('Update Master Data'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(8));
    expect(find.text('PERLU DIPERBARUI'), findsOneWidget);
    expect(db.rows.firstWhere((row) => row['dataset'] == 'Master_Temuan')['payload_json'], contains('old'));
    final checkbox = find.byType(Checkbox).at(3);
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Update Master Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Master Data'));
    await tester.pumpAndSettle();
    expect(db.rows.firstWhere((row) => row['dataset'] == 'Master_Temuan')['payload_json'], contains('new'));
    expect(db.rows.firstWhere((row) => row['dataset'] == 'Master_Gardu')['payload_json'], contains('old'));
    expect(find.text('PERLU DIPERBARUI'), findsNothing);
    expect(find.text('Update Master Data'), findsOneWidget);
  });

  testWidgets('failed comparison preserves local data and sync history', (tester) async {
    final db = MasterMemoryDb();
    for (final key in keys) db.metadata[key] = metadataRow(key, 'success');
    db.rows.add({'dataset': 'Master_Temuan', 'payload_json': '{"Temuan":"A"}'});
    await tester.pumpWidget(screen(MasterDataAccordion(
      token: 'token', database: db,
      fetchGeneral: (_) async => throw StateError('Tidak terhubung'),
      fetchGardu: (_) async => throw StateError('Tidak terhubung'),
    )));
    await tester.pumpAndSettle();
    await openAccordion(tester);
    expect(find.text('CEK GAGAL'), findsWidgets);
    expect(find.text('TERBARU'), findsNothing);
    expect(find.text('Update Master Data'), findsOneWidget);
    expect(db.rows.single['payload_json'], '{"Temuan":"A"}');
    expect(db.metadata['Master_Temuan']?['status'], 'success');
  });
}
