import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/local_user.dart';
import 'database_helper.dart';

class SqliteService {
  SqliteService._();
  static final SqliteService instance = SqliteService._();
  static const _databaseName = 'simandist_local.db';
  static const _databaseVersion = 10;
  static const masterDatasets = ['User_App_Mobile','Master_Penyulang','Master_Keypoint','Master_Temuan','Jenis Pohon','Master_Material','Master_Pekerjaan_Har','Master_Gardu'];
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, _databaseName),
      version: _databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createMasterSchema(db);
        if (oldVersion < 3) await _createWoSchema(db);
        if (oldVersion < 4) await _createWoRowSchema(db);
        if (oldVersion < 5) await _migrateWoRowV5(db);
        if (oldVersion < 6) await DatabaseHelper.createHarJarSchema(db);
        if (oldVersion < 7) await DatabaseHelper.createInsduSchema(db);
        if (oldVersion < 8) await DatabaseHelper.createYandalP0Schema(db);
        if (oldVersion < 9) await _createC4aQueueSchema(db);
        if (oldVersion < 10) await _migrateInsduV10(db);
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute("""CREATE TABLE user_app_mobile (id INTEGER PRIMARY KEY AUTOINCREMENT, remote_no TEXT NOT NULL, kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '', kode_ulp TEXT NOT NULL DEFAULT '', ulp TEXT NOT NULL DEFAULT '', username TEXT NOT NULL COLLATE NOCASE UNIQUE, password_hash TEXT NOT NULL, password_salt TEXT NOT NULL, role TEXT NOT NULL DEFAULT '', bidang TEXT NOT NULL DEFAULT '', tim TEXT NOT NULL DEFAULT '', sub_tim TEXT NOT NULL DEFAULT '', akses_menu TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1, source_updated_at TEXT, synced_at TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)""");
    await db.execute("""CREATE TABLE sync_metadata (key TEXT PRIMARY KEY, remote_revision TEXT NOT NULL DEFAULT '', synced_at TEXT, row_count INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'idle', error_message TEXT NOT NULL DEFAULT '')""");
    await _createMasterSchema(db);
    await _createWoSchema(db);
    await _createWoRowSchema(db);
    await DatabaseHelper.createHarJarSchema(db);
    await DatabaseHelper.createInsduSchema(db);
    await DatabaseHelper.createYandalP0Schema(db);
    await _createC4aQueueSchema(db);
  }

  Future<void> _createC4aQueueSchema(Database db) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS temuan_inspeksi (
      kode_temuan TEXT PRIMARY KEY, kode_wo TEXT NOT NULL DEFAULT '', kode_uiw TEXT DEFAULT '', kode_up3 TEXT DEFAULT '',
      kode_ulp TEXT DEFAULT '', ulp TEXT DEFAULT '', hari TEXT DEFAULT '', tanggal TEXT DEFAULT '', penyulang TEXT DEFAULT '',
      section_awal TEXT DEFAULT '', section_akhir TEXT DEFAULT '', section TEXT DEFAULT '', segmen TEXT DEFAULT '', nomor_gardu TEXT DEFAULT '',
      koordinat TEXT DEFAULT '', lat TEXT DEFAULT '', long TEXT DEFAULT '', jenis_object TEXT DEFAULT '', tier TEXT DEFAULT '', temuan TEXT DEFAULT '',
      jarak REAL, jenis_pohon TEXT DEFAULT '', tinggi_pohon REAL, prioritas TEXT DEFAULT '', pekerjaan TEXT DEFAULT '', jenis_wo TEXT DEFAULT '',
      foto_temuan TEXT DEFAULT '', foto_lingkungan TEXT DEFAULT '', link_foto TEXT DEFAULT '', link_lingkungan TEXT DEFAULT '',
      waktu_input TEXT DEFAULT '', user_input TEXT DEFAULT '', folder_path TEXT DEFAULT '', is_dirty INTEGER DEFAULT 1,
      sync_status TEXT NOT NULL DEFAULT 'queued', sync_error TEXT NOT NULL DEFAULT '', retry_count INTEGER NOT NULL DEFAULT 0,
      last_attempt_at TEXT NOT NULL DEFAULT '')""");
    await _addColumnIfMissing(db, 'temuan_inspeksi', 'sync_status', "TEXT NOT NULL DEFAULT 'queued'");
    await _addColumnIfMissing(db, 'temuan_inspeksi', 'sync_error', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'temuan_inspeksi', 'retry_count', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'temuan_inspeksi', 'last_attempt_at', "TEXT NOT NULL DEFAULT ''");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_temuan_c4a_queue ON temuan_inspeksi(kode_wo,is_dirty,sync_status)');
  }

  Future<void> _createMasterSchema(Database db) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS master_data_rows (id INTEGER PRIMARY KEY AUTOINCREMENT, dataset TEXT NOT NULL, row_key TEXT NOT NULL, payload_json TEXT NOT NULL, synced_at TEXT NOT NULL, UNIQUE(dataset,row_key))""");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_master_dataset ON master_data_rows(dataset)');
  }

  Future<void> _createWoSchema(Database db) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS wo_insjar (
      id INTEGER PRIMARY KEY AUTOINCREMENT, no TEXT NOT NULL DEFAULT '', kode_wo TEXT NOT NULL UNIQUE,
      kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '', kode_ulp TEXT NOT NULL DEFAULT '', ulp TEXT NOT NULL DEFAULT '',
      hari TEXT NOT NULL DEFAULT '', tanggal TEXT NOT NULL DEFAULT '', penyulang TEXT NOT NULL DEFAULT '', section_awal TEXT NOT NULL DEFAULT '',
      section_akhir TEXT NOT NULL DEFAULT '', section TEXT NOT NULL DEFAULT '', koordinat_awal TEXT NOT NULL DEFAULT '',
      koordinat_akhir TEXT NOT NULL DEFAULT '', realisasi_kms REAL, waktu_mulai TEXT NOT NULL DEFAULT '', waktu_selesai TEXT NOT NULL DEFAULT '',
      durasi_pekerjaan TEXT NOT NULL DEFAULT '', status_wo TEXT NOT NULL DEFAULT '', synced_at TEXT NOT NULL DEFAULT '', is_dirty INTEGER NOT NULL DEFAULT 0)""");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_insjar_tanggal ON wo_insjar(tanggal)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_insjar_status ON wo_insjar(status_wo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_insjar_dirty ON wo_insjar(is_dirty)');
  }

  Future<void> _createWoRowSchema(Database db) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS wo_row (
      id INTEGER PRIMARY KEY AUTOINCREMENT, no TEXT NOT NULL DEFAULT '', kode_wo TEXT NOT NULL UNIQUE,
      kode_temuan TEXT NOT NULL DEFAULT '', kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '', kode_ulp TEXT NOT NULL DEFAULT '',
      ulp TEXT NOT NULL DEFAULT '', hari TEXT NOT NULL DEFAULT '', tanggal TEXT NOT NULL DEFAULT '', penyulang TEXT NOT NULL DEFAULT '',
      section_awal TEXT NOT NULL DEFAULT '', section_akhir TEXT NOT NULL DEFAULT '', section TEXT NOT NULL DEFAULT '', segmen TEXT NOT NULL DEFAULT '',
      jenis_object TEXT NOT NULL DEFAULT '', tier TEXT NOT NULL DEFAULT '', temuan TEXT NOT NULL DEFAULT '', prioritas TEXT NOT NULL DEFAULT '',
      pekerjaan TEXT NOT NULL DEFAULT '', jenis_wo TEXT NOT NULL DEFAULT '', koordinat TEXT NOT NULL DEFAULT '', lat TEXT NOT NULL DEFAULT '',
      long TEXT NOT NULL DEFAULT '', jarak REAL, jenis_pohon TEXT NOT NULL DEFAULT '', tinggi_pohon REAL, tim_eksekusi TEXT NOT NULL DEFAULT '',
      tindak_lanjut TEXT NOT NULL DEFAULT '', ukuran_diameter_batang INTEGER, jenis_tebangan TEXT NOT NULL DEFAULT '', foto_temuan TEXT NOT NULL DEFAULT '',
      link_foto TEXT NOT NULL DEFAULT '', foto_lingkungan TEXT NOT NULL DEFAULT '', link_lingkungan TEXT NOT NULL DEFAULT '',
      foto_sesudah TEXT NOT NULL DEFAULT '', link_foto_sesudah TEXT NOT NULL DEFAULT '', status_wo TEXT NOT NULL DEFAULT '', user_input TEXT NOT NULL DEFAULT '',
      waktu_input TEXT NOT NULL DEFAULT '', waktu_realisasi TEXT NOT NULL DEFAULT '', folder_path TEXT NOT NULL DEFAULT '',
      synced_at TEXT NOT NULL DEFAULT '', is_dirty INTEGER NOT NULL DEFAULT 0)""");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_row_status ON wo_row(status_wo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_row_dirty ON wo_row(is_dirty)');
  }

  Future<void> _migrateWoRowV5(Database db) async {
    await _addColumnIfMissing(db, 'wo_row', 'section_awal', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'wo_row', 'section_akhir', "TEXT NOT NULL DEFAULT ''");
  }

  Future<void> _migrateInsduV10(Database db) async {
    await _addColumnIfMissing(db, DatabaseHelper.woInsduTable, 'jurusan_terpasang', 'INTEGER');
    await _addColumnIfMissing(db, DatabaseHelper.woInsduTable, 'jurusan_terpakai', 'INTEGER');
    await _addColumnIfMissing(db, DatabaseHelper.woInsduTable, 'koordinat_penginputan_wbp', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, DatabaseHelper.woInsduTable, 'jarak_gardu_petugas_wbp', 'REAL');
    await _addColumnIfMissing(db, DatabaseHelper.woInsduTable, 'koordinat_penginputan_lwbp', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, DatabaseHelper.woInsduTable, 'jarak_gardu_petugas_lwbp', 'REAL');
  }

  Future<void> _addColumnIfMissing(Database db, String table, String column, String definition) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    if (!rows.any((row) => row['name'].toString().toLowerCase() == column.toLowerCase())) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> replaceMasterData(Map<String, dynamic> datasets) async {
    for (final name in masterDatasets) {
      if (!datasets.containsKey(name) || datasets[name] is! List) throw StateError('Dataset tidak lengkap: $name');
    }
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final name in masterDatasets) {
        final rows = datasets[name] as List;
        await txn.delete('master_data_rows', where: 'dataset = ?', whereArgs: [name]);
        final batch = txn.batch();
        for (var index = 0; index < rows.length; index++) {
          final row = rows[index];
          if (row is! Map) continue;
          batch.insert('master_data_rows', {'dataset': name, 'row_key': '$index', 'payload_json': jsonEncode(Map<String, dynamic>.from(row)), 'synced_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        await txn.insert('sync_metadata', {'key': name, 'synced_at': now, 'row_count': rows.length, 'status': 'success', 'error_message': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<bool> hasMasterData() async {
    final db = await database;
    final placeholders = List.filled(masterDatasets.length, '?').join(',');
    final rows = await db.rawQuery("SELECT COUNT(*) AS total FROM sync_metadata WHERE status = 'success' AND key IN ($placeholders)", masterDatasets);
    return ((rows.first['total'] as int?) ?? 0) == masterDatasets.length;
  }

  Future<DateTime?> lastMasterSync() async {
    final db = await database;
    final placeholders = List.filled(masterDatasets.length, '?').join(',');
    final rows = await db.rawQuery("SELECT MAX(synced_at) AS value FROM sync_metadata WHERE status = 'success' AND key IN ($placeholders)", masterDatasets);
    final value = rows.first['value']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<void> upsertUsers(Iterable<LocalUser> users) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final user in users) {
        final values = user.toMap()..remove('id');
        values['updated_at'] = now;
        values['created_at'] = now;
        batch.insert('user_app_mobile', values, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<LocalUser?> findUser(String username) async {
    final db = await database;
    final rows = await db.query('user_app_mobile', where: 'username = ? AND is_active = 1', whereArgs: [username.trim().toLowerCase()], limit: 1);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  Future<bool> hasUsers() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM user_app_mobile');
    return ((result.first['total'] as int?) ?? 0) > 0;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  LocalUser _fromMap(Map<String, Object?> row) => LocalUser(
        id: row['id'] as int?,
        remoteNo: '${row['remote_no'] ?? ''}',
        kodeUiw: '${row['kode_uiw'] ?? ''}',
        kodeUp3: '${row['kode_up3'] ?? ''}',
        kodeUlp: '${row['kode_ulp'] ?? ''}',
        ulp: '${row['ulp'] ?? ''}',
        username: '${row['username'] ?? ''}',
        passwordHash: '${row['password_hash'] ?? ''}',
        passwordSalt: '${row['password_salt'] ?? ''}',
        role: '${row['role'] ?? ''}',
        bidang: '${row['bidang'] ?? ''}',
        tim: '${row['tim'] ?? ''}',
        subTim: '${row['sub_tim'] ?? ''}',
        aksesMenu: '${row['akses_menu'] ?? ''}',
        isActive: row['is_active'] == 1,
        sourceUpdatedAt: row['source_updated_at']?.toString(),
        syncedAt: '${row['synced_at'] ?? ''}',
      );
}
