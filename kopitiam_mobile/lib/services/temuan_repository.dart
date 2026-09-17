import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/c4a_selection.dart';
import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'c4a_numbering.dart';
import 'photo_watermark_service.dart';
import 'sqlite_service.dart';

typedef TemuanSender = Future<Map<String, dynamic>> Function(String token, Map<String, dynamic> row);
class C4aSyncResult { final int berhasil, gagal; const C4aSyncResult({this.berhasil = 0, this.gagal = 0}); }

class TemuanRepository {
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  final _db = SqliteService.instance;
  final Database? database;
  final TemuanSender? _sender;
  TemuanRepository({this.database, TemuanSender? sender}) : _sender = sender;

  Future<Map<String, dynamic>> _send(String token, Map<String, dynamic> payload) =>
      _sender == null ? ApiService.syncTemuan(token, payload) : _sender(token, payload);

  Future<Database> _database() async {
    final db = database ?? await _db.database;
    await db.execute('''CREATE TABLE IF NOT EXISTS temuan_inspeksi (
      kode_temuan TEXT PRIMARY KEY, kode_wo TEXT NOT NULL DEFAULT '', kode_uiw TEXT DEFAULT '',
      kode_up3 TEXT DEFAULT '', kode_ulp TEXT DEFAULT '', ulp TEXT DEFAULT '', hari TEXT DEFAULT '',
      tanggal TEXT DEFAULT '', penyulang TEXT DEFAULT '', section_awal TEXT DEFAULT '', section_akhir TEXT DEFAULT '',
      section TEXT DEFAULT '', segmen TEXT DEFAULT '', nomor_gardu TEXT DEFAULT '', koordinat TEXT DEFAULT '',
      lat TEXT DEFAULT '', long TEXT DEFAULT '', jenis_object TEXT DEFAULT '', tier TEXT DEFAULT '', temuan TEXT DEFAULT '',
      jarak REAL, jenis_pohon TEXT DEFAULT '', tinggi_pohon REAL, prioritas TEXT DEFAULT '', pekerjaan TEXT DEFAULT '',
      jenis_wo TEXT DEFAULT '', foto_temuan TEXT DEFAULT '', foto_lingkungan TEXT DEFAULT '', link_foto TEXT DEFAULT '',
      link_lingkungan TEXT DEFAULT '', waktu_input TEXT DEFAULT '', user_input TEXT DEFAULT '', folder_path TEXT DEFAULT '',
      is_dirty INTEGER DEFAULT 1, sync_status TEXT NOT NULL DEFAULT 'queued', sync_error TEXT NOT NULL DEFAULT '',
      retry_count INTEGER NOT NULL DEFAULT 0, last_attempt_at TEXT NOT NULL DEFAULT '')''');
    await _addColumn(db, 'sync_status', "TEXT NOT NULL DEFAULT 'queued'");
    await _addColumn(db, 'sync_error', "TEXT NOT NULL DEFAULT ''");
    await _addColumn(db, 'retry_count', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumn(db, 'last_attempt_at', "TEXT NOT NULL DEFAULT ''");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_temuan_c4a_queue ON temuan_inspeksi(kode_wo,is_dirty,sync_status)');
    return db;
  }
  Future<void> _addColumn(Database db, String name, String definition) async {
    final info = await db.rawQuery('PRAGMA table_info(temuan_inspeksi)');
    if (!info.any((row) => '${row['name']}'.toLowerCase() == name)) await db.execute('ALTER TABLE temuan_inspeksi ADD COLUMN $name $definition');
  }

  Future<List<TemuanInspeksi>> untukWo(String kodeWo) async {
    final db = await _database();
    final rows = await db.query('temuan_inspeksi', where: 'kode_wo = ?', whereArgs: [kodeWo], orderBy: 'kode_temuan');
    return rows.map(TemuanInspeksi.fromMap).toList();
  }
  Future<List<TemuanInspeksi>> daftarC4a({String? status}) async {
    final db = await _database(), filter = status?.trim().toLowerCase();
    final rows = await db.query('temuan_inspeksi', where: filter == null || filter.isEmpty ? "kode_wo = ''" : "kode_wo = '' AND sync_status = ?", whereArgs: filter == null || filter.isEmpty ? null : [filter], orderBy: 'waktu_input DESC, kode_temuan DESC');
    return rows.map(TemuanInspeksi.fromMap).toList();
  }
  Future<String> kodeBaru(String kodeWo) async {
    final db = await _database();
    final rows = await db.rawQuery('SELECT kode_temuan FROM temuan_inspeksi WHERE kode_wo = ? ORDER BY kode_temuan DESC LIMIT 1', [kodeWo]);
    final number = rows.isEmpty ? 0 : int.tryParse('${rows.first['kode_temuan']}'.split('.TO-').last) ?? 0;
    return '$kodeWo.TO-${(number + 1).toString().padLeft(3, '0')}';
  }
  Future<void> simpan(TemuanInspeksi item) async {
    if (item.kodeWo.isEmpty) throw StateError('Gunakan simpanC4a untuk temuan tanpa WO.');
    final db = await _database(), stored = await _preparePhotos(item);
    await db.insert('temuan_inspeksi', stored.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<TemuanInspeksi> simpanC4a(TemuanInspeksi draft, {DateTime? savedAt}) async {
    validateC4a(draft); await _validateLandscapePhoto(draft.fotoTemuan); await _validateLandscapePhoto(draft.fotoLingkungan);
    final db = await _database();
    return db.transaction((txn) async {
      final now = savedAt ?? DateTime.now();
      final rows = (await txn.query('temuan_inspeksi', where: "kode_wo = '' AND kode_ulp = ?", whereArgs: [draft.kodeUlp])).map(TemuanInspeksi.fromMap).toList();
      final code = C4aNumbering.code(draft.kodeUlp, now, C4aNumbering.nextDaily(rows, draft.kodeUlp, draft.penyulang, now), C4aNumbering.nextTo(rows, draft.kodeUlp));
      final item = TemuanInspeksi.fromMap({...draft.toMap(), 'kode_temuan': code, 'hari': WoInsjar.hariIndonesia[now.weekday - 1], 'tanggal': WoInsjar.formatTanggal(now), 'waktu_input': WoInsjar.stampLengkap(now), 'folder_path': folderC4a(draft.kodeUlp, draft.jenisObject, code, now), 'is_dirty': 1, 'sync_status': TemuanInspeksi.statusQueued, 'sync_error': '', 'retry_count': 0, 'last_attempt_at': '', 'link_foto': '', 'link_lingkungan': ''});
      final stored = await _preparePhotos(item);
      await txn.insert('temuan_inspeksi', stored.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
      return stored;
    });
  }
  Future<void> _validateLandscapePhoto(String path) async {
    await _validatePhoto(File(path)); final decoded = img.decodeJpg(await File(path).readAsBytes());
    if (decoded == null || decoded.width <= decoded.height) throw StateError('Foto C4A harus JPEG landscape dari kamera aplikasi.');
  }
  Future<TemuanInspeksi> _preparePhotos(TemuanInspeksi item) async {
    if (item.fotoTemuan.isEmpty || item.fotoLingkungan.isEmpty) throw StateError('Foto Temuan dan Foto Sekitar Tiang wajib diambil.');
    final a = item.kodeWo.isNotEmpty && _sudahWatermark(item.fotoTemuan) ? item.fotoTemuan : await PhotoWatermarkService.render(sourcePath: item.fotoTemuan, item: item, photoLabel: 'Foto Temuan');
    final b = item.kodeWo.isNotEmpty && _sudahWatermark(item.fotoLingkungan) ? item.fotoLingkungan : await PhotoWatermarkService.render(sourcePath: item.fotoLingkungan, item: item, photoLabel: 'Foto Lingkungan');
    final primary = await _persistPhoto(a, item.kodeTemuan, 'Foto Temuan'), environment = await _persistPhoto(b, item.kodeTemuan, 'Foto Lingkungan');
    return TemuanInspeksi.fromMap({...item.toMap(), 'foto_temuan': primary.path, 'foto_lingkungan': environment.path});
  }
  Future<File> _persistPhoto(String sourcePath, String code, String label) async {
    final source = File(sourcePath); await _validatePhoto(source);
    final root = await _db.accountDocumentsDirectory(), folder = Directory(p.join(root.path, 'temuan_photos', _safeName(code))); await folder.create(recursive: true);
    final match = RegExp(r'(\d{6})(?=\.jpe?g$)', caseSensitive: false).firstMatch(p.basename(source.path));
    final stamp = match?.group(1) ?? DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(8, 14);
    final destination = File(p.join(folder.path, '${_safeName(code)}.$label.$stamp.jpg'));
    return p.equals(source.path, destination.path) ? source : source.copy(destination.path);
  }
  Future<void> _validatePhoto(File file) async {
    if (!await file.exists()) throw StateError('File foto tidak ditemukan. Ambil ulang foto.');
    final length = await file.length(); if (length <= 0 || length > maxPhotoBytes) throw StateError('Ukuran foto harus lebih kecil dari 5 MB.');
    final header = await file.openRead(0, 3).fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
    if (header.length < 3 || header[0] != 0xff || header[1] != 0xd8 || header[2] != 0xff) throw StateError('Format foto tidak valid. Gunakan kamera aplikasi.');
  }
  String _safeName(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  bool _sudahWatermark(String path) => path.endsWith('_wm.jpg');

  Future<void> unduh(String token, String kodeWo) async {
    final response = await ApiService.getTemuan(token, kodeWo); if (response['success'] != true || response['rows'] is! List) return;
    final db = await _database();
    for (final row in response['rows'] as List) if (row is Map) await db.insert('temuan_inspeksi', TemuanInspeksi.fromRemote(Map<String, dynamic>.from(row)).toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  Future<Map<String, dynamic>> _payload(TemuanInspeksi item) async {
    validateC4a(item); final primary = File(item.fotoTemuan), environment = File(item.fotoLingkungan); await _validatePhoto(primary); await _validatePhoto(environment);
    return item.toRemote()..['Kode WO'] = ''..['Jenis WO'] = ''..['Foto Temuan'] = p.basename(primary.path)..['Foto Lingkungan Sekitaran Tiang'] = p.basename(environment.path)..['fotoTemuanBase64'] = base64Encode(await primary.readAsBytes())..['fotoLingkunganBase64'] = base64Encode(await environment.readAsBytes());
  }
  Future<C4aSyncResult> sinkronC4a(String token, {bool hanyaGagal = false}) async {
    final db = await _database();
    final rows = await db.query('temuan_inspeksi', where: hanyaGagal ? "kode_wo = '' AND is_dirty = 1 AND sync_status = ?" : "kode_wo = '' AND is_dirty = 1 AND sync_status IN (?,?,?,?)", whereArgs: hanyaGagal ? [TemuanInspeksi.statusFailed] : [TemuanInspeksi.statusDraft, TemuanInspeksi.statusQueued, TemuanInspeksi.statusFailed, TemuanInspeksi.statusSending], orderBy: 'waktu_input, kode_temuan');
    var ok = 0, failed = 0;
    for (final row in rows) {
      final item = TemuanInspeksi.fromMap(row), attempt = DateTime.now().toUtc().toIso8601String();
      await db.update('temuan_inspeksi', {'sync_status': TemuanInspeksi.statusSending, 'sync_error': '', 'last_attempt_at': attempt}, where: 'kode_temuan = ?', whereArgs: [item.kodeTemuan]);
      try {
        final response = await _send(token, await _payload(item)); if (response['success'] != true) throw StateError('${response['message'] ?? 'Sinkronisasi gagal.'}');
        await db.update('temuan_inspeksi', {'is_dirty': 0, 'sync_status': TemuanInspeksi.statusSynced, 'sync_error': '', 'link_foto': '${response['linkFoto'] ?? ''}', 'link_lingkungan': '${response['linkLingkungan'] ?? ''}', 'folder_path': '${response['folderPath'] ?? item.folderPath}', 'last_attempt_at': attempt}, where: 'kode_temuan = ?', whereArgs: [item.kodeTemuan]); ok++;
      } catch (error) {
        await db.update('temuan_inspeksi', {'is_dirty': 1, 'sync_status': TemuanInspeksi.statusFailed, 'sync_error': error.toString().replaceFirst('Bad state: ', ''), 'retry_count': item.retryCount + 1, 'last_attempt_at': attempt}, where: 'kode_temuan = ?', whereArgs: [item.kodeTemuan]); failed++;
      }
    }
    return C4aSyncResult(berhasil: ok, gagal: failed);
  }
  Future<bool> kirimUlangC4a(String token, String code) async {
    final db = await _database(); await db.update('temuan_inspeksi', {'sync_status': TemuanInspeksi.statusQueued, 'sync_error': ''}, where: "kode_temuan = ? AND kode_wo = ''", whereArgs: [code]);
    final rows = await db.query('temuan_inspeksi', where: 'kode_temuan = ?', whereArgs: [code], limit: 1); if (rows.isEmpty) return false;
    final item = TemuanInspeksi.fromMap(rows.first);
    try {
      final response = await _send(token, await _payload(item)); if (response['success'] != true) throw StateError('${response['message'] ?? 'Sinkronisasi gagal.'}');
      await db.update('temuan_inspeksi', {'is_dirty': 0, 'sync_status': TemuanInspeksi.statusSynced, 'sync_error': '', 'link_foto': '${response['linkFoto'] ?? ''}', 'link_lingkungan': '${response['linkLingkungan'] ?? ''}', 'folder_path': '${response['folderPath'] ?? item.folderPath}', 'last_attempt_at': DateTime.now().toUtc().toIso8601String()}, where: 'kode_temuan = ?', whereArgs: [code]); return true;
    } catch (error) {
      await db.update('temuan_inspeksi', {'is_dirty': 1, 'sync_status': TemuanInspeksi.statusFailed, 'sync_error': error.toString().replaceFirst('Bad state: ', ''), 'retry_count': item.retryCount + 1, 'last_attempt_at': DateTime.now().toUtc().toIso8601String()}, where: 'kode_temuan = ?', whereArgs: [code]); return false;
    }
  }
  Future<void> sinkron(String token) async {
    final db = await _database(), rows = await db.query('temuan_inspeksi', where: "is_dirty = 1 AND kode_wo <> ''");
    for (final row in rows) {
      final item = TemuanInspeksi.fromMap(row), primary = File(TemuanInspeksi.fromMap(row).fotoTemuan), environment = File(TemuanInspeksi.fromMap(row).fotoLingkungan); await _validatePhoto(primary); await _validatePhoto(environment);
      final payload = item.toRemote()..['Foto Temuan'] = p.basename(primary.path)..['Foto Lingkungan Sekitaran Tiang'] = p.basename(environment.path)..['fotoTemuanBase64'] = base64Encode(await primary.readAsBytes())..['fotoLingkunganBase64'] = base64Encode(await environment.readAsBytes());
      final response = await ApiService.syncTemuan(token, payload); if (response['success'] != true) throw StateError('${response['message'] ?? 'Sinkronisasi foto gagal.'}');
      await db.update('temuan_inspeksi', {'is_dirty': 0, 'sync_status': TemuanInspeksi.statusSynced, 'link_foto': '${response['linkFoto'] ?? ''}', 'link_lingkungan': '${response['linkLingkungan'] ?? ''}', 'folder_path': '${response['folderPath'] ?? item.folderPath}'}, where: 'kode_temuan = ?', whereArgs: [item.kodeTemuan]);
    }
  }

  Future<List<Map<String, dynamic>>> master(String dataset) async { final db = await _database(); final rows = await db.query('master_data_rows', columns: ['payload_json'], where: 'dataset = ?', whereArgs: [dataset]); return rows.map((row) => Map<String, dynamic>.from(jsonDecode('${row['payload_json']}'))).toList(); }
  String jenisObject(Map<String, dynamic> sesi) { final value = '${sesi['subTim'] ?? sesi['tim'] ?? ''}'.toLowerCase(); if (value.contains('inspeksi jaringan') || value.contains('insjar')) return 'Jaringan'; if (value.contains('inspeksi gardu') || value.contains('insdu')) return 'Gardu'; return ''; }
  bool isRowC4a(String value) => const {'rabas / pangkas','tebang sedang','tebang besar'}.contains(value.trim().toLowerCase().replaceAll(RegExp(r'\s*/\s*'), ' / ').replaceAll(RegExp(r'\s+'), ' '));
  void validateC4a(TemuanInspeksi item) {
    if (item.kodeWo.isNotEmpty || item.jenisWo.isNotEmpty) throw StateError('C4A harus tanpa WO.');
    if (!RegExp(r'^\d+$').hasMatch(item.kodeUiw) || !C4aSelection.up3Labels.containsKey(item.kodeUp3) || !C4aSelection.ulpLabels.containsKey(item.kodeUlp) || !item.kodeUlp.startsWith(item.kodeUp3) || [item.ulp,item.userInput,item.penyulang,item.section,item.temuan,item.prioritas].any((s) => s.trim().isEmpty) || !['Jaringan','Gardu'].contains(item.jenisObject) || !['Tier 1','Tier 2'].contains(item.tier)) throw StateError('Lengkapi unit, aset, Tier, Temuan, Prioritas, dan akun login.');
    if (!C4aSelection.validCoordinate(item.lat,item.long) || item.koordinat.replaceAll(' ','') != '${item.lat},${item.long}'.replaceAll(' ','')) throw StateError('Koordinat Temuan tidak valid.');
    if (item.jenisObject == 'Jaringan' && (item.segmen.trim().isEmpty || item.sectionAwal.isEmpty || item.sectionAkhir.isEmpty || item.sectionAwal == item.sectionAkhir || item.section != C4aSelection.section(item.sectionAwal,item.sectionAkhir) || item.nomorGardu.isNotEmpty)) throw StateError('Lengkapi Section berbeda dan Segmen jaringan.');
    if (item.jenisObject == 'Gardu' && (item.nomorGardu.isEmpty || item.sectionAwal.isNotEmpty || item.sectionAkhir.isNotEmpty)) throw StateError('Pilih Nomor Gardu dari master.');
    if (isRowC4a(item.temuan) && (item.jenisPohon.trim().isEmpty || prioritasC4a(item.temuan,item.jarak,item.tinggiPohon,const []) != item.prioritas)) throw StateError('Jarak, tinggi, jenis pohon dan prioritas ROW harus valid.');
    if (item.fotoTemuan.isEmpty || item.fotoLingkungan.isEmpty || item.fotoTemuan == item.fotoLingkungan) throw StateError('Kedua foto bukti berbeda wajib diambil.');
  }
  String prioritasC4a(String temuan,double? jarak,double? tinggi,List<Map<String,dynamic>> master) { if (isRowC4a(temuan)) { if (jarak == null || tinggi == null || !jarak.isFinite || !tinggi.isFinite || jarak < 0 || tinggi <= 0) return ''; if (tinggi >= jarak * math.sqrt(2)) return 'Mayor'; return prioritas(temuan,jarak,tinggi,master); } final values = master.where((r) => _same(_find(r,['Temuan']),temuan)).map((r) => _find(r,['Prioritas'])).where((v) => v.isNotEmpty).toSet(); return values.length == 1 ? values.single : ''; }
  String prioritas(String temuan,double? jarak,double? tinggi,List<Map<String,dynamic>> master) { if (isRowC4a(temuan)) { final d=jarak??0,h=tinggi??0; if(h<9)return d>5?'Minor':'Mayor'; if(d<3)return 'Mayor'; if(d<6)return 'Sedang'; return 'Minor'; } for(final row in master){final n=_find(row,const ['Temuan','Nama Temuan']);if(n.isNotEmpty&&_same(n,temuan))return _find(row,const ['Prioritas']);}return ''; }
  static String _find(Map<String,dynamic> row,List<String> keys){String n(String k)=>k.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'),'');for(final k in keys){final v='${row[k]??''}'.trim();if(v.isNotEmpty)return v;}final set=keys.map(n).toSet();for(final e in row.entries)if(set.contains(n(e.key))&&'${e.value??''}'.trim().isNotEmpty)return '${e.value}'.trim();return '';}
  static bool _same(String a,String b)=>a.trim().toLowerCase()==b.trim().toLowerCase();
  static String folder(WoInsjar wo,String object,String code,DateTime now)=>_folder(wo.kodeUlp,object,'${wo.kodeWo}/$code',now);
  static String folderC4a(String ulp,String object,String code,DateTime now)=>_folder(ulp,object,code,now);
  static String _folder(String ulp,String object,String leaf,DateTime now){const m=['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];return 'Kopitiam/Rekap Temuan Inspeksi/$ulp/$object/${now.year}/${now.month.toString().padLeft(2,'0')}. ${m[now.month-1]}/${now.day.toString().padLeft(2,'0')}/$leaf/';}
}

class C4aSyncService {
  final TemuanRepository repository; final String token; final Duration interval; final Future<bool> Function() online; Timer? _timer; bool _running=false;
  C4aSyncService({required this.repository,required this.token,this.interval=const Duration(seconds:15),Future<bool> Function()? online}):online=online??_hasNetwork;
  void start({void Function(C4aSyncResult result)? onResult}){_timer?.cancel();_timer=Timer.periodic(interval,(_)=>flush(onResult:onResult));unawaited(flush(onResult:onResult));}
  Future<void> flush({void Function(C4aSyncResult result)? onResult})async{if(_running||token.isEmpty||!await online())return;_running=true;try{onResult?.call(await repository.sinkronC4a(token));}finally{_running=false;}}
  void dispose()=>_timer?.cancel();
  static Future<bool> _hasNetwork()async{try{final r=await InternetAddress.lookup('script.google.com').timeout(const Duration(seconds:4));return r.isNotEmpty&&r.first.rawAddress.isNotEmpty;}catch(_){return false;}}
}
