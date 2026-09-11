import 'package:sqflite/sqflite.dart';

/// Skema SQLite offline-first untuk modul WO Har Jar, WO Har Du, WO Insdu, dan WO Yandal P0.
class DatabaseHelper {
  static const woHarJarTable = 'wo_har_jar';
  static const woHarDuTable = 'wo_har_du';
  static const woMaterialHarJarTable = 'wo_material_har_jar';
  static const woInsduTable = 'wo_insdu';
  static const woYandalP0Table = 'wo_yandal_p0';

  static Future<void> createHarJarSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS $woHarJarTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT, no TEXT NOT NULL DEFAULT '', kode_wo TEXT NOT NULL UNIQUE,
      kode_temuan TEXT NOT NULL DEFAULT '', kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '',
      kode_ulp TEXT NOT NULL DEFAULT '', ulp TEXT NOT NULL DEFAULT '', hari TEXT NOT NULL DEFAULT '', tanggal TEXT NOT NULL DEFAULT '',
      penyulang TEXT NOT NULL DEFAULT '', section TEXT NOT NULL DEFAULT '', segmen TEXT NOT NULL DEFAULT '', jenis_object TEXT NOT NULL DEFAULT '',
      tier TEXT NOT NULL DEFAULT '', temuan TEXT NOT NULL DEFAULT '', prioritas TEXT NOT NULL DEFAULT '', pekerjaan TEXT NOT NULL DEFAULT '',
      jenis_wo TEXT NOT NULL DEFAULT '', koordinat TEXT NOT NULL DEFAULT '', lat REAL, long REAL, foto_temuan TEXT NOT NULL DEFAULT '',
      link_foto_temuan TEXT NOT NULL DEFAULT '', foto_tiang_sekitar TEXT NOT NULL DEFAULT '', link_foto_tiang_sekitar TEXT NOT NULL DEFAULT '',
      foto_sesudah TEXT NOT NULL DEFAULT '', link_foto_sesudah TEXT NOT NULL DEFAULT '', catatan_petugas TEXT NOT NULL DEFAULT '',
      tim_eksekusi TEXT NOT NULL DEFAULT '', tanggal_penugasan TEXT NOT NULL DEFAULT '', catatan_koordinator TEXT NOT NULL DEFAULT '',
      nama_koordinator TEXT NOT NULL DEFAULT '', status_wo TEXT NOT NULL DEFAULT 'Menunggu', user_input TEXT NOT NULL DEFAULT '',
      waktu_input TEXT NOT NULL DEFAULT '', waktu_selesai TEXT NOT NULL DEFAULT '', durasi TEXT NOT NULL DEFAULT '',
      folder_path TEXT NOT NULL DEFAULT '', is_synced INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_har_jar_status ON $woHarJarTable(status_wo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_har_jar_synced ON $woHarJarTable(is_synced)');

    await db.execute('''CREATE TABLE IF NOT EXISTS $woHarDuTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT, no TEXT NOT NULL DEFAULT '', kode_wo TEXT NOT NULL UNIQUE,
      kode_temuan TEXT NOT NULL DEFAULT '', kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '',
      kode_ulp TEXT NOT NULL DEFAULT '', ulp TEXT NOT NULL DEFAULT '', hari TEXT NOT NULL DEFAULT '', tanggal TEXT NOT NULL DEFAULT '',
      penyulang TEXT NOT NULL DEFAULT '', section TEXT NOT NULL DEFAULT '', nomor_gardu TEXT NOT NULL DEFAULT '',
      jenis_object TEXT NOT NULL DEFAULT '', tier TEXT NOT NULL DEFAULT '', temuan TEXT NOT NULL DEFAULT '', prioritas TEXT NOT NULL DEFAULT '',
      pekerjaan TEXT NOT NULL DEFAULT '', jenis_wo TEXT NOT NULL DEFAULT '', koordinat TEXT NOT NULL DEFAULT '', lat REAL, long REAL,
      foto_temuan TEXT NOT NULL DEFAULT '', link_foto_temuan TEXT NOT NULL DEFAULT '', foto_tiang_sekitar TEXT NOT NULL DEFAULT '',
      link_foto_tiang_sekitar TEXT NOT NULL DEFAULT '', foto_sesudah TEXT NOT NULL DEFAULT '', link_foto_sesudah TEXT NOT NULL DEFAULT '',
      catatan_petugas TEXT NOT NULL DEFAULT '', tim_eksekusi TEXT NOT NULL DEFAULT '', tanggal_penugasan TEXT NOT NULL DEFAULT '',
      catatan_koordinator TEXT NOT NULL DEFAULT '', nama_koordinator TEXT NOT NULL DEFAULT '', status_wo TEXT NOT NULL DEFAULT 'Menunggu',
      user_input TEXT NOT NULL DEFAULT '', waktu_input TEXT NOT NULL DEFAULT '', waktu_selesai TEXT NOT NULL DEFAULT '',
      durasi TEXT NOT NULL DEFAULT '', folder_path TEXT NOT NULL DEFAULT '', is_synced INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_har_du_status ON $woHarDuTable(status_wo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_har_du_synced ON $woHarDuTable(is_synced)');

    await db.execute('''CREATE TABLE IF NOT EXISTS $woMaterialHarJarTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT, kode_penggunaan_material TEXT NOT NULL UNIQUE, kode_wo TEXT NOT NULL,
      material TEXT NOT NULL DEFAULT '', jumlah REAL NOT NULL DEFAULT 0, satuan TEXT NOT NULL DEFAULT '',
      kepemilikan TEXT NOT NULL DEFAULT '', keterangan TEXT NOT NULL DEFAULT '', user_input TEXT NOT NULL DEFAULT '',
      waktu_input TEXT NOT NULL DEFAULT '', is_synced INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (kode_wo) REFERENCES $woHarJarTable (kode_wo) ON DELETE CASCADE
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_material_kode_wo ON $woMaterialHarJarTable(kode_wo)');
  }

  static Future<void> createInsduSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS $woInsduTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT, no TEXT NOT NULL DEFAULT '', kode_wo TEXT NOT NULL UNIQUE,
      kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '', kode_ulp TEXT NOT NULL DEFAULT '',
      ulp TEXT NOT NULL DEFAULT '', hari TEXT NOT NULL DEFAULT '', tanggal TEXT NOT NULL DEFAULT '',
      penyulang TEXT NOT NULL DEFAULT '', section TEXT NOT NULL DEFAULT '', nomor_gardu TEXT NOT NULL DEFAULT '',
      koordinat_gardu TEXT NOT NULL DEFAULT '', lat REAL, long REAL, jurusan TEXT NOT NULL DEFAULT '',
      jurusan_terpasang INTEGER, jurusan_terpakai INTEGER,
      beban_utama_r_wbp REAL, beban_utama_s_wbp REAL, beban_utama_t_wbp REAL, beban_jurusan_n_wbp REAL,
      tegangan_rs_wbp REAL, tegangan_st_wbp REAL, tegangan_rt_wbp REAL, tegangan_rn_wbp REAL, tegangan_sn_wbp REAL, tegangan_tn_wbp REAL,
      beban_utama_r_lwbp REAL, beban_utama_s_lwbp REAL, beban_utama_t_lwbp REAL, beban_jurusan_n_lwbp REAL,
      tegangan_rs_lwbp REAL, tegangan_st_lwbp REAL, tegangan_rt_lwbp REAL, tegangan_rn_lwbp REAL, tegangan_sn_lwbp REAL, tegangan_tn_lwbp REAL,
      koordinat_penginputan_wbp TEXT NOT NULL DEFAULT '', jarak_gardu_petugas_wbp REAL,
      koordinat_penginputan_lwbp TEXT NOT NULL DEFAULT '', jarak_gardu_petugas_lwbp REAL,
      cover_fco_atas TEXT NOT NULL DEFAULT '', cover_fco_bawah TEXT NOT NULL DEFAULT '', cover_bushing_tm TEXT NOT NULL DEFAULT '',
      cover_bushing_tr TEXT NOT NULL DEFAULT '', cover_arrester TEXT NOT NULL DEFAULT '', jumperan_atas TEXT NOT NULL DEFAULT '',
      jumperan_bawah TEXT NOT NULL DEFAULT '', waktu_mulai TEXT NOT NULL DEFAULT '', waktu_selesai TEXT NOT NULL DEFAULT '',
      durasi_pekerjaan TEXT NOT NULL DEFAULT '', status_wo TEXT NOT NULL DEFAULT 'Mulai Pengerjaan',
      synced_at TEXT NOT NULL DEFAULT '', is_dirty INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_insdu_status ON $woInsduTable(status_wo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_insdu_dirty ON $woInsduTable(is_dirty)');
  }

  static Future<void> createYandalP0Schema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS $woYandalP0Table (
      id INTEGER PRIMARY KEY AUTOINCREMENT, no TEXT NOT NULL DEFAULT '', kode_wo TEXT NOT NULL UNIQUE,
      kode_temuan TEXT NOT NULL DEFAULT '', kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '', up3 TEXT NOT NULL DEFAULT '',
      kode_ulp TEXT NOT NULL DEFAULT '', ulp TEXT NOT NULL DEFAULT '', hari TEXT NOT NULL DEFAULT '', tanggal TEXT NOT NULL DEFAULT '',
      jenis_p0 TEXT NOT NULL DEFAULT '', penyulang TEXT NOT NULL DEFAULT '', section TEXT NOT NULL DEFAULT '', segmen TEXT NOT NULL DEFAULT '',
      nomor_gardu TEXT NOT NULL DEFAULT '', jenis_object TEXT NOT NULL DEFAULT '', tier TEXT NOT NULL DEFAULT '', temuan TEXT NOT NULL DEFAULT '',
      prioritas TEXT NOT NULL DEFAULT '', koordinat TEXT NOT NULL DEFAULT '', lat REAL, long REAL, foto_temuan TEXT NOT NULL DEFAULT '',
      link_foto TEXT NOT NULL DEFAULT '', foto_lingkungan TEXT NOT NULL DEFAULT '', link_lingkungan TEXT NOT NULL DEFAULT '',
      foto_tindak_lanjut TEXT NOT NULL DEFAULT '', link_foto_tindak_lanjut TEXT NOT NULL DEFAULT '', tindak_lanjut TEXT NOT NULL DEFAULT '',
      regu_yantek TEXT NOT NULL DEFAULT '', nomor_hp TEXT NOT NULL DEFAULT '', catatan TEXT NOT NULL DEFAULT '',
      status_wo TEXT NOT NULL DEFAULT 'Menunggu', dibuat_oleh TEXT NOT NULL DEFAULT '', diteruskan_oleh TEXT NOT NULL DEFAULT '',
      waktu_mulai TEXT NOT NULL DEFAULT '', waktu_selesai TEXT NOT NULL DEFAULT '', durasi TEXT NOT NULL DEFAULT '',
      folder_path TEXT NOT NULL DEFAULT '', is_synced INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_yandal_p0_status ON $woYandalP0Table(status_wo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_yandal_p0_synced ON $woYandalP0Table(is_synced)');
  }
}
