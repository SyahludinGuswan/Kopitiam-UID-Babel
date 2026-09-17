import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_har_jar.dart';
import '../models/wo_material_har_jar.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'database_helper.dart';
import 'photo_watermark_service.dart';
import 'sqlite_service.dart';
import 'wo_insjar_repository.dart' show WoSyncResult;

class WoHarJarRepository {
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  final _db = SqliteService.instance;
  Future<Database> _database() async => _db.database;

  Future<List<WoHarJar>> semua() async {
    final db = await _database();
    final rows = await db.rawQuery("SELECT * FROM ${DatabaseHelper.woHarJarTable} ORDER BY CASE status_wo WHEN '${WoHarJar.statusMenunggu}' THEN 0 WHEN '${WoHarJar.statusSedang}' THEN 1 ELSE 2 END, kode_wo DESC");
    return rows.map(WoHarJar.fromMap).toList();
  }

  Future<int> jumlahBelumSinkron() async {
    final db = await _database();
    final result = await db.rawQuery("SELECT COUNT(*) AS total FROM ${DatabaseHelper.woHarJarTable} WHERE is_synced = 0 AND status_wo = '${WoHarJar.statusSelesai}'");
    return (result.first['total'] as int?) ?? 0;
  }

  Future<WoHarJar?> cari(String kodeWo) async {
    final db = await _database();
    final rows = await db.query(DatabaseHelper.woHarJarTable, where: 'kode_wo = ?', whereArgs: [kodeWo], limit: 1);
    return rows.isEmpty ? null : WoHarJar.fromMap(rows.first);
  }

  Future<List<WoMaterialHarJar>> materialUntukWo(String kodeWo) async {
    final db = await _database();
    final rows = await db.query(DatabaseHelper.woMaterialHarJarTable, where: 'kode_wo = ?', whereArgs: [kodeWo], orderBy: 'id ASC');
    return rows.map(WoMaterialHarJar.fromMap).toList();
  }

  Future<List<String>> daftarMaterialMaster() async {
    final db = await _database();
    final rows = await db.query('master_data_rows', columns: ['payload_json'], where: 'dataset = ?', whereArgs: ['Master_Material']);
    final result = <String>{};
    for (final row in rows) {
      try {
        final payload = jsonDecode('${row['payload_json']}');
        if (payload is! Map) continue;
        for (final key in ['Material', 'Nama Material', 'Nama', 'material']) {
          final value = '${payload[key] ?? ''}'.trim();
          if (value.isNotEmpty) { result.add(value); break; }
        }
      } catch (_) { continue; }
    }
    return result.toList()..sort();
  }

  Future<WoSyncResult> download(String token) async {
    final response = await ApiService.getWoHarJar(token);
    final pendingList = response['rows'];
    if (response['success'] == true && pendingList is List && pendingList.isEmpty) {
      final totalSheet = (response['totalSheet'] as num?)?.toInt() ?? 0;
      final rejectedByUlp = (response['rejectedByUlp'] as num?)?.toInt() ?? 0;
      if (totalSheet > 0 && rejectedByUlp > 0) return WoSyncResult(total: 0, diproses: 0, pesan: 'Ditemukan $totalSheet data WO Har Jar di server, tetapi $rejectedByUlp tidak cocok dengan Kode ULP akun Anda (${response['kodeUlpFilter'] ?? ''} vs ${response['sampleKodeUlp'] ?? ''} pada data). Hubungi admin.');
    }
    if (response['success'] != true || pendingList is! List) return WoSyncResult(total: 0, diproses: 0, pesan: (response['message'] ?? 'Download WO Har Jar gagal.').toString());
    final db = await _database();
    final now = DateTime.now().toUtc().toIso8601String();
    var added = 0;
    await db.transaction((txn) async {
      for (final row in pendingList) {
        if (row is! Map) continue;
        final item = WoHarJar.fromRemote(Map<String, dynamic>.from(row));
        final status = WoHarJar.normalisasiStatus(item.statusWo);
        if (status == WoHarJar.statusSelesai || status == WoHarJar.statusTersinkron) continue;
        final inserted = await txn.insert(DatabaseHelper.woHarJarTable, item.copyWith(statusWo: WoHarJar.statusMenunggu).toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
        if (inserted > 0) added++;
      }
      await txn.insert('sync_metadata', {'key': 'WO_Har_Jar', 'synced_at': now, 'row_count': added, 'status': 'success', 'error_message': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return WoSyncResult(total: added, diproses: added);
  }

  Future<void> mulaiPekerjaan(String kodeWo) async {
    final db = await _database();
    await db.update(DatabaseHelper.woHarJarTable, {'status_wo': WoHarJar.statusSedang, 'waktu_input': WoInsjar.stampLengkap(DateTime.now())}, where: 'kode_wo = ? AND status_wo = ?', whereArgs: [kodeWo, WoHarJar.statusMenunggu]);
  }

  String generateKodeMaterial(String kodeWo) => 'MAT-$kodeWo-${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(900) + 100}';

  Future<void> simpanSelesai(WoHarJar item, List<WoMaterialHarJar> materials) async {
    if (item.fotoSesudah.isEmpty) throw StateError('Foto Sesudah wajib diambil.');
    final watermarked = item.fotoSesudah.endsWith('_wm.jpg') ? item.fotoSesudah : await PhotoWatermarkService.render(sourcePath: item.fotoSesudah, item: _watermarkItem(item), photoLabel: 'Foto Sesudah');
    final photoPath = await _persistPhoto(watermarked, item.kodeWo);
    final stored = item.copyWith(fotoSesudah: photoPath.path, statusWo: WoHarJar.statusSelesai, isSynced: false);
    final db = await _database();
    await db.transaction((txn) async {
      await txn.insert(DatabaseHelper.woHarJarTable, stored.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(DatabaseHelper.woMaterialHarJarTable, where: 'kode_wo = ?', whereArgs: [item.kodeWo]);
      for (final material in materials) await txn.insert(DatabaseHelper.woMaterialHarJarTable, material.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  TemuanInspeksi _watermarkItem(WoHarJar item) => TemuanInspeksi(kodeTemuan: item.kodeTemuan, kodeWo: item.kodeWo, temuan: item.temuan, jenisObject: item.jenisObject, tier: item.tier, prioritas: item.prioritas, koordinat: item.koordinat, ulp: item.ulp, penyulang: item.penyulang, section: item.section, segmen: item.segmen, hari: item.hari, tanggal: item.tanggal, waktuInput: item.waktuInput);

  Future<File> _persistPhoto(String sourcePath, String kodeWo) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw StateError('File foto tidak ditemukan. Ambil ulang foto.');
    final length = await source.length();
    if (length <= 0 || length > maxPhotoBytes) throw StateError('Ukuran foto harus lebih kecil dari 5 MB.');
    final header = await source.openRead(0, 3).fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (header.length < 3 || header[0] != 0xFF || header[1] != 0xD8 || header[2] != 0xFF) throw StateError('Format foto tidak valid. Gunakan kamera aplikasi.');
    final root = await _db.accountDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'har_jar_photos', _safeName(kodeWo)));
    await folder.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(8, 14);
    return source.copy(p.join(folder.path, '${_safeName(kodeWo)}.Foto Sesudah.$stamp.jpg'));
  }

  String _safeName(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<WoSyncResult> sinkron(String token) async {
    final db = await _database();
    final rows = await db.query(DatabaseHelper.woHarJarTable, where: "is_synced = 0 AND status_wo = '${WoHarJar.statusSelesai}'", orderBy: 'kode_wo ASC');
    if (rows.isEmpty) return const WoSyncResult(total: 0, diproses: 0, pesan: 'Belum ada WO Har Jar selesai yang siap disinkronkan.');
    var processed = 0;
    String? firstError;
    for (final row in rows) {
      final item = WoHarJar.fromMap(row);
      try {
        final photo = File(item.fotoSesudah);
        if (!await photo.exists()) throw StateError('${item.kodeWo}: Foto Sesudah tidak tersedia sebelum sinkron.');
        final materials = await materialUntukWo(item.kodeWo);
        final payload = item.toRemote()
          ..['Foto Sesudah'] = p.basename(photo.path)
          ..['fotoSesudahBase64'] = base64Encode(await photo.readAsBytes())
          ..['materials'] = materials.map((m) => m.toRemote()).toList();
        final response = await ApiService.syncWoHarJar(token, [payload]);
        payload.remove('fotoSesudahBase64');
        if (response['success'] != true || (response['diproses'] as num?)?.toInt() != 1) {
          firstError ??= '${response['message'] ?? '${item.kodeWo}: receipt belum valid.'}';
          continue;
        }
        await db.transaction((txn) async {
          await txn.delete(DatabaseHelper.woMaterialHarJarTable, where: 'kode_wo = ?', whereArgs: [item.kodeWo]);
          await txn.delete(DatabaseHelper.woHarJarTable, where: 'kode_wo = ?', whereArgs: [item.kodeWo]);
        });
        processed++;
      } catch (error) {
        firstError ??= '$error';
      }
    }
    return WoSyncResult(total: rows.length, diproses: processed, pesan: processed == rows.length ? null : '$processed dari ${rows.length} WO Har Jar berhasil. ${firstError ?? 'WO gagal tetap disimpan untuk retry.'}');
  }
}
