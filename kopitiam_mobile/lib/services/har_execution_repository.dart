import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/har_execution.dart';
import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'photo_watermark_service.dart';
import 'sqlite_service.dart';

typedef HarDownload = Future<Map<String, dynamic>> Function(String type, String token);
typedef HarSend = Future<Map<String, dynamic>> Function(String type, String token, List<Map<String, dynamic>> rows);
typedef MasterProgress = void Function(double value, String label);

class HarDownloadResult {
  final int downloaded;
  final int available;
  final List<String> types;
  const HarDownloadResult(this.downloaded, this.available, this.types);
  bool get empty => available == 0;
}
class HarMasterState {
  final bool synced;
  final DateTime? lastSync;
  const HarMasterState(this.synced, this.lastSync);
}

class HarExecutionRepository {
  final Map<String, dynamic> session;
  final Database? database;
  final HarDownload downloadApi;
  final HarSend sendApi;
  Future<Database>? _ready;
  bool _busy = false;
  HarExecutionRepository(this.session, {this.database, HarDownload? downloadApi, HarSend? sendApi}) : downloadApi = downloadApi ?? _download, sendApi = sendApi ?? _send;
  static Future<Map<String, dynamic>> _download(String type, String token) => type == HarExecution.jar ? ApiService.getWoHarJar(token) : ApiService.getWoHarDu(token);
  static Future<Map<String, dynamic>> _send(String type, String token, List<Map<String, dynamic>> rows) => type == HarExecution.jar ? ApiService.syncWoHarJar(token, rows) : ApiService.syncWoHarDu(token, rows);
  String get owner => '${session['username'] ?? ''}'.trim().toLowerCase();
  String get token => '${session['token'] ?? ''}';
  List<String> get allowedTypes => HarExecution.allowedTypes(session);
  void _access(String type) { if (owner.isEmpty || !allowedTypes.contains(type)) throw StateError('Akun tidak memiliki akses WO ini.'); }
  Future<Database> _db() => _ready ??= _init();
  Future<Database> _init() async {
    final db = database ?? await SqliteService.instance.database;
    await db.execute('''CREATE TABLE IF NOT EXISTS har_execution_v2 (owner TEXT NOT NULL, jenis_wo TEXT NOT NULL, kode_wo TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(owner,jenis_wo,kode_wo))''');
    return db;
  }
  Future<void> _put(DatabaseExecutor db, HarExecution item) => db.insert('har_execution_v2', {'owner': owner, 'jenis_wo': item.type, 'kode_wo': item.code, 'payload': jsonEncode(item.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace).then((_) {});
  Future<HarExecution?> _get(DatabaseExecutor db, String type, String code) async {
    final rows = await db.query('har_execution_v2', where: 'owner = ? AND jenis_wo = ? AND kode_wo = ?', whereArgs: [owner,type,code]);
    return rows.isEmpty ? null : HarExecution.decode('${rows.first['payload']}');
  }
  Future<HarExecution?> get(String type, String code) async { _access(type); return _get(await _db(), type, code); }
  Future<List<HarExecution>> list(String type) async {
    _access(type);
    final rows = await (await _db()).query('har_execution_v2', where: 'owner = ? AND jenis_wo = ?', whereArgs: [owner,type], orderBy: 'kode_wo DESC');
    return rows.map((e) => HarExecution.decode('${e['payload']}')).toList();
  }
  Future<List<HarExecution>> listAll() async {
    final result = <HarExecution>[];
    for (final type in allowedTypes) { result.addAll(await list(type)); }
    result.sort((a,b) {
      final rankA = a.finished ? 2 : a.started ? 1 : 0;
      final rankB = b.finished ? 2 : b.started ? 1 : 0;
      return rankA != rankB ? rankA.compareTo(rankB) : b.code.compareTo(a.code);
    });
    return result;
  }
  Future<int> download(String type) async {
    _access(type);
    final response = await downloadApi(type, token);
    if (response['success'] != true || response['rows'] is! List) throw StateError('${response['message'] ?? 'Download gagal.'}');
    final db = await _db(); int count = 0;
    await db.transaction((txn) async {
      for (final raw in response['rows'] as List) {
        final row = Map<String, dynamic>.from(raw as Map)..['Jenis WO'] = type;
        final code = '${row['Kode WO'] ?? ''}'.trim(); if (code.isEmpty) continue;
        final old = await _get(txn, type, code);
        if (old != null && (old.dirty || old.started)) continue;
        final item = HarExecution(header: row); if (old == null && item.finished) continue;
        await _put(txn, item); count++;
      }
    });
    return count;
  }
  Future<HarDownloadResult> downloadAssigned() async {
    if (HarExecution.isAdmin(session)) throw StateError('Admin tidak dapat mengunduh WO.');
    var downloaded = 0, available = 0;
    for (final type in allowedTypes) {
      final response = await downloadApi(type, token);
      if (response['success'] != true || response['rows'] is! List) throw StateError('${response['message'] ?? 'Download gagal.'}');
      available += (response['rows'] as List).length;
      final db = await _db();
      await db.transaction((txn) async {
        for (final raw in response['rows'] as List) {
          final row = Map<String,dynamic>.from(raw as Map)..['Jenis WO']=type;
          final code='${row['Kode WO']??''}'.trim(); if(code.isEmpty) continue;
          final old=await _get(txn,type,code); if(old!=null&&(old.dirty||old.started)) continue;
          final item=HarExecution(header:row); if(old==null&&item.finished) continue;
          await _put(txn,item); downloaded++;
        }
      });
    }
    return HarDownloadResult(downloaded,available,List.of(allowedTypes));
  }
  Future<void> start(String type, String code) async {
    _access(type); final db = await _db();
    await db.transaction((txn) async { final item = await _get(txn,type,code); if (item == null) throw StateError('WO belum diunduh.'); if (item.started) return; await _put(txn,item.change(header: {...item.header, 'Status WO': HarExecution.progress, 'Waktu Mulai': WoInsjar.stampLengkap(DateTime.now())}, dirty:true, revision:item.revision+1)); });
  }
  Future<List<HarMaterial>> materialMaster() async {
    final rows = await (await _db()).query('master_data_rows', columns:['payload_json'], where:'dataset = ?', whereArgs:['Master_Material']);
    final values = rows.map((r) => HarMaterial.fromMap(Map<String,dynamic>.from(jsonDecode('${r['payload_json']}')))).where((m)=>m.available).toList(); values.sort((a,b)=>a.name.compareTo(b.name)); return values;
  }
  Future<void> downloadAllMasters(MasterProgress progress) async {
    progress(0,'Menyiapkan Data Master');
    final responses = await Future.wait([ApiService.getMasterData(token),ApiService.getMasterGardu(token)]);
    final support=responses[0],gardu=responses[1];
    if(support['success']!=true||support['datasets'] is! Map) throw StateError('${support['message']??'Master Pendukung gagal.'}');
    if(gardu['success']!=true||gardu['rows'] is! List) throw StateError('${gardu['message']??'Master Gardu gagal.'}');
    final datasets=Map<String,dynamic>.from(support['datasets'])..['Master_Gardu']=gardu['rows'];
    final names=SqliteService.masterDatasets;
    var total=0; for(final name in names){final rows=datasets[name];if(rows is! List)throw StateError('Dataset tidak lengkap: $name');total+=rows.length;}
    final db=await _db(); var processed=0;
    await db.transaction((txn) async {
      for(final name in names){
        progress(total==0?0:processed/total,name=='Master_Gardu'?'Mengunduh Master Gardu':'Mengunduh Master Pendukung');
        final rows=datasets[name] as List; await txn.delete('master_data_rows',where:'dataset = ?',whereArgs:[name]);
        for(var i=0;i<rows.length;i++){final row=rows[i];if(row is! Map)continue;await txn.insert('master_data_rows',{'dataset':name,'row_key':'$i','payload_json':jsonEncode(Map<String,dynamic>.from(row)),'synced_at':DateTime.now().toUtc().toIso8601String()},conflictAlgorithm:ConflictAlgorithm.replace);processed++;progress(total==0?1:processed/total,name=='Master_Gardu'?'Mengunduh Master Gardu':'Mengunduh Master Pendukung');}
        await txn.insert('sync_metadata',{'key':name,'synced_at':DateTime.now().toUtc().toIso8601String(),'row_count':rows.length,'status':'success','error_message':''},conflictAlgorithm:ConflictAlgorithm.replace);
      }
      await txn.insert('sync_metadata',{'key':'HAR_MASTER_SYNC','synced_at':DateTime.now().toUtc().toIso8601String(),'row_count':total,'status':'success','error_message':''},conflictAlgorithm:ConflictAlgorithm.replace);
    });
    progress(1,'Master Data Sync');
  }
  Future<HarMasterState> masterState() async {
    final rows=await (await _db()).query('sync_metadata',where:'key = ? AND status = ?',whereArgs:['HAR_MASTER_SYNC','success'],limit:1);
    if(rows.isEmpty)return const HarMasterState(false,null);
    return HarMasterState(true,DateTime.tryParse('${rows.first['synced_at']}')?.toLocal());
  }
  Future<void> addJob(String type,String code,{required String description, required double quantity, required String set, required List<Map<String,dynamic>> materials}) async {
    _access(type); if (description.trim().isEmpty || !quantity.isFinite || quantity<=0 || set.trim().isEmpty) throw StateError('Lengkapi Uraian Pekerjaan, Jumlah, dan Set.');
    final master = await materialMaster(); final validated = <Map<String,dynamic>>[];
    for (final input in materials) { final matches = master.where((m)=>m.code == input['Kode Material']).toList(); final qty = input['Jumlah']; if (matches.length != 1 || qty is! num || !qty.isFinite || qty<=0 || !HarMaterial.ownership.contains(input['Kepemilikan'])) throw StateError('Material, jumlah, satuan master, atau kepemilikan tidak valid.'); validated.add({'Kode Penggunaan Material':HarExecution.newId('MAT'), 'Material':matches.single.name, 'Jumlah':qty, 'Satuan':matches.single.unit, 'Kepemilikan':input['Kepemilikan'], 'Catatan':''}); }
    final db = await _db(); await db.transaction((txn) async { final item = await _get(txn,type,code); if (item == null || !item.started || item.finished) throw StateError('WO harus dalam Progress Pekerjaan.'); final stamp = WoInsjar.stampLengkap(DateTime.now()); final id = HarExecution.newId('PKJ'); final row = {...item.lineage(),'Kode Pekerjaan':id,'Uraian Pekerjaan':description.trim(),'Jumlah':quantity,'Set':set.trim(),'User Input':owner,'Waktu Input':stamp}; final children = validated.map((m)=>{...item.lineage(),'Kode Pekerjaan':id,'Uraian Pekerjaan':description.trim(),'User Input':owner,'Waktu Input':stamp,...m}).toList(); await _put(txn,item.change(jobs:[...item.jobs,row],materials:[...item.materials,...children],dirty:true,revision:item.revision+1)); });
  }
  Future<void> finish(String type,String code,String photo,String notes) async {
    _access(type); final item = await get(type,code); if (item == null || !item.started || item.finished) throw StateError('WO tidak dapat diselesaikan.'); final source = File(photo); if (!await source.exists() || await source.length()>5*1024*1024) throw StateError('Foto Sesudah wajib, maksimal 5 MB.'); final image = img.decodeJpg(await source.readAsBytes()); if (image == null || image.width<=image.height) throw StateError('Foto harus JPEG landscape dari kamera.'); final stamp = WoInsjar.stampLengkap(DateTime.now());
    final watermark = TemuanInspeksi(kodeTemuan:item.value('Kode Temuan'),kodeWo:item.code,jenisObject:item.value('Jenis Object'),temuan:item.value('Temuan'),ulp:item.value('ULP'),penyulang:item.value('Penyulang'),section:item.value('Section'),segmen:item.value('Segmen'),nomorGardu:item.value('Nomor Gardu'),koordinat:item.value('Koordinat'),waktuInput:stamp,userInput:owner); final rendered = await PhotoWatermarkService.render(sourcePath:photo,item:watermark,photoLabel:'Foto Sesudah'); final root = await SqliteService.instance.accountDocumentsDirectory(); final dir = Directory(p.join(root.path,'har_execution_photos')); await dir.create(recursive:true); final target = await File(rendered).copy(p.join(dir.path,'${HarExecution.newId('HAR')}.jpg')); final db = await _db(); await db.transaction((txn) async { final current = await _get(txn,type,code); if (current == null || current.finished) throw StateError('WO sudah selesai.'); await _put(txn,current.change(header:{...current.header,'Status WO':HarExecution.done,'Waktu Selesai':stamp,'User Input':owner,'Catatan Petugas':notes.trim()},photo:target.path,dirty:true,revision:current.revision+1)); });
  }
  Future<String> sync(String type) async {
    _access(type); if (_busy) return 'Sinkronisasi masih berjalan.'; _busy=true; int ok=0,failed=0;
    try { for (final item in (await list(type)).where((e)=>e.dirty)) { try { final payload = {'schemaVersion':2, ...item.header,'jobs':item.jobs,'materials':item.materials}; if (item.finished) { final photo = File(item.photo); if (!await photo.exists()) throw StateError('Foto lokal tidak ditemukan; data tetap disimpan.'); payload['fotoSesudahBase64'] = base64Encode(await photo.readAsBytes()); } final response = await sendApi(type,token,[payload]); final accepted = response['accepted'] as List? ?? []; if (response['success'] != true || !accepted.contains(item.code)) throw StateError('${response['message'] ?? 'Konfirmasi server tidak lengkap.'}'); final db = await _db(); await db.transaction((txn) async { final current = await _get(txn,type,item.code); if (current == null || current.revision != item.revision) return; final links = response['photos'] as Map? ?? {}; await _put(txn,current.change(dirty:false,error:'',header:{...current.header,if(links[item.code] is Map) ...Map<String,dynamic>.from(links[item.code] as Map)})); }); ok++; } catch(e) { final db=await _db(); await db.transaction((txn) async {final current=await _get(txn,type,item.code);if(current!=null)await _put(txn,current.change(error:'$e'));});failed++; } } } finally {_busy=false;} return '$ok WO tersinkron, $failed gagal. Data lokal dipertahankan.';
  }
  Future<String> syncAll() async { final messages=<String>[]; for(final type in allowedTypes){messages.add(await sync(type));} return messages.join('\n'); }
}
