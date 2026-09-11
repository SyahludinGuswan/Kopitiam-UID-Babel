import 'package:sqflite/sqflite.dart';

import '../models/wo_insdu.dart';
import 'api_service.dart';
import 'sqlite_service.dart';

class WoInsduSyncResult {
  final int total;
  final int diproses;
  final String? pesan;
  const WoInsduSyncResult({required this.total, required this.diproses, this.pesan});
}

class WoInsduRepository {
  final SqliteService _db = SqliteService.instance;
  static const table = 'wo_insdu';

  Future<Database> _database() async {
    final db = await _db.database;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final columns = info.map((row) => '${row['name']}').toSet();
    for (final entry in const {
      'waktu_penginputan_wbp': "TEXT NOT NULL DEFAULT ''",
      'waktu_penginputan_lwbp': "TEXT NOT NULL DEFAULT ''",
    }.entries) {
      if (!columns.contains(entry.key)) await db.execute('ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}');
    }
    return db;
  }

  Future<List<WoInsdu>> semua() async {
    final db = await _database();
    final rows = await db.query(table, orderBy: "CASE status_wo WHEN '${WoInsdu.statusMulai}' THEN 0 WHEN '${WoInsdu.statusDalam}' THEN 1 ELSE 2 END, tanggal DESC, kode_wo DESC");
    return rows.map(WoInsdu.fromMap).toList();
  }

  Future<WoInsdu?> cari(String kodeWo) async {
    final db = await _database();
    final rows = await db.query(table, where: 'kode_wo = ?', whereArgs: [kodeWo], limit: 1);
    return rows.isEmpty ? null : WoInsdu.fromMap(rows.first);
  }

  Future<void> simpan(WoInsdu wo, {bool dirty = true}) async {
    final db = await _database();
    await db.insert(table, wo.toMap()..['is_dirty'] = dirty ? 1 : 0, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> mulaiPekerjaan(String kodeWo) async {
    final db = await _database();
    await db.update(table, {'status_wo': WoInsdu.statusDalam}, where: 'kode_wo = ? AND status_wo = ?', whereArgs: [kodeWo, WoInsdu.statusMulai]);
  }

  Future<WoInsduSyncResult> download(String token) async {
    final response = await ApiService.getWoInsdu(token);
    if (response['success'] == true && response['rows'] is List && (response['rows'] as List).isEmpty) {
      final totalSheet = (response['totalSheet'] as num?)?.toInt() ?? 0;
      final rejectedByUlp = (response['rejectedByUlp'] as num?)?.toInt() ?? 0;
      if (totalSheet > 0 && rejectedByUlp > 0) return WoInsduSyncResult(total: 0, diproses: 0, pesan: 'Ditemukan $totalSheet data WO Inspeksi Gardu, tetapi $rejectedByUlp tidak cocok dengan Kode ULP akun Anda.');
    }
    if (response['success'] != true || response['rows'] is! List) return WoInsduSyncResult(total: 0, diproses: 0, pesan: '${response['message'] ?? 'Data WO Inspeksi Gardu tidak valid.'}');
    final db = await _database();
    var added = 0;
    for (final raw in response['rows'] as List) {
      if (raw is! Map) continue;
      final wo = WoInsdu.fromRemote(Map<String, dynamic>.from(raw));
      if (wo.kodeWo.isEmpty) continue;
      final exists = await db.query(table, columns: ['kode_wo'], where: 'kode_wo = ?', whereArgs: [wo.kodeWo], limit: 1);
      if (exists.isNotEmpty) continue;
      await db.insert(table, wo.toMap()..['is_dirty'] = 0);
      added++;
    }
    return WoInsduSyncResult(total: added, diproses: added);
  }

  Future<WoInsduSyncResult> sinkron(String token) async {
    final db = await _database();
    final rows = await db.query(table, where: 'is_dirty = 1 AND status_wo = ?', whereArgs: [WoInsdu.statusSelesai]);
    if (rows.isEmpty) return const WoInsduSyncResult(total: 0, diproses: 0, pesan: 'Belum ada WO Inspeksi Gardu selesai yang siap disinkronkan.');
    final response = await ApiService.syncWoInsdu(token, rows.map((row) => WoInsdu.fromMap(row).toRemote()).toList());
    if (response['success'] != true) return WoInsduSyncResult(total: rows.length, diproses: 0, pesan: '${response['message'] ?? 'Sinkronisasi WO Inspeksi Gardu gagal.'}');
    final done = (response['diproses'] as num?)?.toInt() ?? rows.length;
    if (done != rows.length) return WoInsduSyncResult(total: rows.length, diproses: done, pesan: 'Konfirmasi server tidak lengkap. Data lokal dipertahankan.');
    await db.transaction((txn) async { for (final row in rows) { await txn.delete(table, where: 'kode_wo = ? AND status_wo = ?', whereArgs: [row['kode_wo'], WoInsdu.statusSelesai]); } });
    return WoInsduSyncResult(total: rows.length, diproses: done);
  }
}
