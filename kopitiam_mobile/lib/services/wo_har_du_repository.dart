import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/wo_har_du.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'database_helper.dart';
import 'sqlite_service.dart';
import 'wo_insjar_repository.dart' show WoSyncResult;

class WoHarDuRepository {
  final SqliteService _db = SqliteService.instance;

  Future<List<WoHarDu>> semua() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT * FROM ${DatabaseHelper.woHarDuTable} ORDER BY CASE status_wo WHEN '${WoHarDu.statusMenunggu}' THEN 0 WHEN '${WoHarDu.statusSedang}' THEN 1 ELSE 2 END, kode_wo DESC",
    );
    return rows.map(WoHarDu.fromMap).toList();
  }

  Future<WoHarDu?> cari(String kodeWo) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.woHarDuTable,
      where: 'kode_wo = ?',
      whereArgs: [kodeWo],
      limit: 1,
    );
    return rows.isEmpty ? null : WoHarDu.fromMap(rows.first);
  }

  Future<WoSyncResult> download(String token) async {
    final response = await ApiService.getWoHarDu(token);
    final rows = response['rows'];
    if (response['success'] != true || rows is! List)
      return WoSyncResult(
        total: 0,
        diproses: 0,
        pesan: '${response['message'] ?? 'Download WO Har Du gagal.'}',
      );
    if (rows.isEmpty) {
      final sheet = (response['totalSheet'] as num?)?.toInt() ?? 0;
      final rejected = (response['rejectedByUlp'] as num?)?.toInt() ?? 0;
      if (sheet > 0 && rejected > 0)
        return WoSyncResult(
          total: 0,
          diproses: 0,
          pesan:
              'Ada $sheet WO Har Du di server, tetapi $rejected tidak cocok dengan Kode ULP akun (${response['kodeUlpFilter'] ?? '-'} vs ${response['sampleKodeUlp'] ?? '-'}).',
        );
    }
    final db = await _db.database;
    var available = 0;
    var added = 0;
    await db.transaction((txn) async {
      for (final raw in rows) {
        if (raw is! Map) continue;
        final item = WoHarDu.fromRemote(Map<String, dynamic>.from(raw));
        if (item.kodeWo.isEmpty) continue;
        final status = WoHarDu.normalisasiStatus(item.statusWo);
        if (status == WoHarDu.statusSelesai ||
            status == WoHarDu.statusTersinkron)
          continue;
        available++;
        final inserted = await txn.insert(
          DatabaseHelper.woHarDuTable,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted > 0) added++;
      }
      await txn.insert('sync_metadata', {
        'key': 'WO_Har_Du',
        'synced_at': DateTime.now().toUtc().toIso8601String(),
        'row_count': available,
        'status': 'success',
        'error_message': '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return WoSyncResult(total: available, diproses: added);
  }

  Future<void> mulaiPekerjaan(String kodeWo) async {
    final db = await _db.database;
    await db.update(
      DatabaseHelper.woHarDuTable,
      {
        'status_wo': WoHarDu.statusSedang,
        'waktu_input': WoInsjar.stampLengkap(DateTime.now()),
        'is_synced': 0,
      },
      where: 'kode_wo = ? AND status_wo = ?',
      whereArgs: [kodeWo, WoHarDu.statusMenunggu],
    );
  }

  Future<void> simpanSelesai(
    WoHarDu source, {
    required String fotoSesudah,
    required String koordinat,
    required double latitude,
    required double longitude,
    required String catatan,
    required String username,
  }) async {
    final photo = File(fotoSesudah);
    if (!await photo.exists()) throw StateError('Foto Sesudah wajib diambil.');
    final root = await _db.accountDocumentsDirectory();
    final folder = Directory(
      p.join(root.path, 'har_du_photos', _safe(source.kodeWo)),
    );
    await folder.create(recursive: true);
    final storedPhoto = await photo.copy(
      p.join(
        folder.path,
        '${_safe(source.kodeWo)}.${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
    final now = DateTime.now();
    final start = WoInsjar.parseStamp(source.waktuInput);
    final values = source.toMap()
      ..remove('id')
      ..addAll({
        'koordinat': koordinat,
        'lat': latitude,
        'long': longitude,
        'foto_sesudah': storedPhoto.path,
        'catatan_petugas': catatan,
        'status_wo': WoHarDu.statusSelesai,
        'user_input': username,
        'waktu_input': source.waktuInput.isEmpty
            ? WoInsjar.stampLengkap(now)
            : source.waktuInput,
        'waktu_selesai': WoInsjar.stampLengkap(now),
        'durasi': start == null ? '-' : WoInsjar.hitungDurasi(start, now),
        'is_synced': 0,
      });
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.woHarDuTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WoSyncResult> sinkron(String token) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.woHarDuTable,
      where: 'is_synced = 0 AND status_wo = ?',
      whereArgs: [WoHarDu.statusSelesai],
      orderBy: 'kode_wo ASC',
    );
    if (rows.isEmpty)
      return const WoSyncResult(
        total: 0,
        diproses: 0,
        pesan: 'Belum ada WO Har Du selesai yang siap disinkronkan.',
      );
    var processed = 0;
    String? firstError;
    for (final row in rows) {
      final item = WoHarDu.fromMap(row);
      try {
        final photo = File(item.fotoSesudah);
        if (!await photo.exists())
          throw StateError('${item.kodeWo}: Foto Sesudah tidak ditemukan.');
        final payload = item.toRemote()
          ..['Foto Sesudah'] = p.basename(photo.path)
          ..['fotoSesudahBase64'] = base64Encode(await photo.readAsBytes());
        final response = await ApiService.syncWoHarDu(token, [payload]);
        payload.remove('fotoSesudahBase64');
        if (response['success'] != true ||
            (response['diproses'] as num?)?.toInt() != 1) {
          firstError ??=
              '${response['message'] ?? '${item.kodeWo}: receipt belum valid.'}';
          continue;
        }
        await db.delete(
          DatabaseHelper.woHarDuTable,
          where: 'kode_wo = ?',
          whereArgs: [item.kodeWo],
        );
        processed++;
      } catch (error) {
        firstError ??= '$error';
      }
    }
    return WoSyncResult(
      total: rows.length,
      diproses: processed,
      pesan: processed == rows.length
          ? null
          : '$processed dari ${rows.length} WO Har Du berhasil. ${firstError ?? 'WO gagal tetap disimpan untuk retry.'}',
    );
  }

  String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
