import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/wo_insdu.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/temuan_repository.dart';
import '../services/wo_insdu_repository.dart';
import 'temuan_tab.dart';

class WoInsduFormScreen extends StatefulWidget {
  final WoInsdu existing;
  final Map<String, dynamic> sesi;
  const WoInsduFormScreen({super.key, required this.existing, required this.sesi});

  @override
  State<WoInsduFormScreen> createState() => _WoInsduFormScreenState();
}

class _WoInsduFormScreenState extends State<WoInsduFormScreen> {
  static const blue = Color(0xFF075B96);
  static const darkBlue = Color(0xFF06325F);
  static const navy = Color(0xFF071B30);
  static const gold = Color(0xFFFFC928);
  static const paleGold = Color(0xFFFFF4C7);
  static const cyan = Color(0xFFC8F1F8);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFD7E0E8);
  static const page = Color(0xFFF0F8FC);

  static const coverOptions = ['Lengkap', 'Tidak Lengkap', 'Rusak', 'Tidak ada'];
  static const jumperOptions = [
    'A3C',
    'A3CS (Lengkap)',
    'A3CS (Tidak Lengkap)',
    'Protective Sleeve (Lengkap)',
    'Protective Sleeve (Tidak Lengkap)',
  ];
  static const wbpLoad = {'bebanUtamaRWbp':'FASA R','bebanUtamaSWbp':'FASA S','bebanUtamaTWbp':'FASA T','bebanJurusanNWbp':'NETRAL N'};
  static const wbpVoltage = {'teganganRswbp':'R-S','teganganStwbp':'S-T','teganganRtwbp':'R-T','teganganRnwbp':'R-N','teganganSnwbp':'S-N','teganganTnwbp':'T-N'};
  static const lwbpLoad = {'bebanUtamaRLwbp':'FASA R','bebanUtamaSLwbp':'FASA S','bebanUtamaTLwbp':'FASA T','bebanJurusanNLwbp':'NETRAL N'};
  static const lwbpVoltage = {'teganganRslwbp':'R-S','teganganStlwbp':'S-T','teganganRtlwbp':'R-T','teganganRnlwbp':'R-N','teganganSnlwbp':'S-N','teganganTnlwbp':'T-N'};
  static const conditionLabels = {
    'coverFcoAtas':'Cover FCO Atas','coverFcoBawah':'Cover FCO Bawah','coverBushingTm':'Cover Bushing TM',
    'coverBushingTr':'Cover Bushing TR','coverArrester':'Cover Arrester','jumperanAtas':'Jumperan Atas','jumperanBawah':'Jumperan Bawah',
  };

  final _repo = WoInsduRepository();
  final _temuanRepo = TemuanRepository();
  final Map<String, TextEditingController> _fields = {};
  bool _saving = false, _gettingWbp = false, _gettingLwbp = false;
  double? _wbpAccuracy, _lwbpAccuracy, _wbpDistance, _lwbpDistance;
  LocationFix? _wbpFix, _lwbpFix;
  String _wbpTime = '', _lwbpTime = '';
  int _findingCount = 0;

  WoInsdu get wo => widget.existing;
  bool get readOnly => WoInsdu.normalisasiStatus(wo.statusWo) == WoInsdu.statusSelesai;
  Iterable<String> get _numericKeys => [...wbpLoad.keys, ...wbpVoltage.keys, ...lwbpLoad.keys, ...lwbpVoltage.keys];

  @override
  void initState() {
    super.initState();
    final values = <String, Object?>{
      'jurusanTerpasang':wo.jurusanTerpasang,'jurusanTerpakai':wo.jurusanTerpakai,
      'bebanUtamaRWbp':wo.bebanUtamaRWbp,'bebanUtamaSWbp':wo.bebanUtamaSWbp,'bebanUtamaTWbp':wo.bebanUtamaTWbp,'bebanJurusanNWbp':wo.bebanJurusanNWbp,
      'teganganRswbp':wo.teganganRswbp,'teganganStwbp':wo.teganganStwbp,'teganganRtwbp':wo.teganganRtwbp,'teganganRnwbp':wo.teganganRnwbp,'teganganSnwbp':wo.teganganSnwbp,'teganganTnwbp':wo.teganganTnwbp,
      'bebanUtamaRLwbp':wo.bebanUtamaRLwbp,'bebanUtamaSLwbp':wo.bebanUtamaSLwbp,'bebanUtamaTLwbp':wo.bebanUtamaTLwbp,'bebanJurusanNLwbp':wo.bebanJurusanNLwbp,
      'teganganRslwbp':wo.teganganRslwbp,'teganganStlwbp':wo.teganganStlwbp,'teganganRtlwbp':wo.teganganRtlwbp,'teganganRnlwbp':wo.teganganRnlwbp,'teganganSnlwbp':wo.teganganSnlwbp,'teganganTnlwbp':wo.teganganTnlwbp,
      'coverFcoAtas':wo.coverFcoAtas,'coverFcoBawah':wo.coverFcoBawah,'coverBushingTm':wo.coverBushingTm,'coverBushingTr':wo.coverBushingTr,'coverArrester':wo.coverArrester,'jumperanAtas':wo.jumperanAtas,'jumperanBawah':wo.jumperanBawah,
    };
    for (final entry in values.entries) {
      final raw = entry.value == null ? '' : '${entry.value}';
      _fields[entry.key] = TextEditingController(text: _numericKeys.contains(entry.key) ? raw.replaceAll('.', ',') : raw);
    }
    _wbpFix = _parseFix(wo.koordinatPenginputanWbp);
    _lwbpFix = _parseFix(wo.koordinatPenginputanLwbp);
    _wbpTime = wo.waktuPenginputanWbp;
    _lwbpTime = wo.waktuPenginputanLwbp;
    _wbpDistance = wo.jarakGarduPetugasWbp;
    _lwbpDistance = wo.jarakGarduPetugasLwbp;
    _refreshFindingCount();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _refreshFindingCount() async {
    final count = (await _temuanRepo.untukWo(wo.kodeWo)).length;
    if (mounted) setState(() => _findingCount = count);
  }

  LocationFix? _parseFix(String value) {
    final parts = value.split(',');
    if (parts.length < 2) return null;
    final latitude = double.tryParse(parts[0].trim());
    final longitude = double.tryParse(parts[1].trim());
    if (latitude == null || longitude == null) return null;
    return LocationFix(latitude:latitude, longitude:longitude, accuracy:5, capturedAt:DateTime.now(), samples:1, locked:true);
  }

  List<double>? get _garduCoordinate {
    final raw = wo.koordinatGardu.trim().isNotEmpty ? wo.koordinatGardu : '${wo.lat},${wo.long}';
    final parts = raw.split(',');
    if (parts.length < 2) return null;
    final latitude = double.tryParse(parts[0].trim());
    final longitude = double.tryParse(parts[1].trim());
    return latitude == null || longitude == null ? null : [latitude, longitude];
  }

  String? _decimalError(String key) {
    final value = _fields[key]!.text.trim();
    if (value.isEmpty) return null;
    if (value.contains('.')) return 'Gunakan (,) sebagai pemisah';
    return RegExp(r'^\d+(,\d+)?$').hasMatch(value) ? null : 'Angka tidak valid';
  }

  double? _number(String key) {
    final value = _fields[key]!.text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : double.tryParse(value);
  }
  int? _integer(String key) => int.tryParse(_fields[key]!.text.trim());
  String _text(String key) => _fields[key]!.text.trim();
  bool get _hasDecimalError => _numericKeys.any((key) => _decimalError(key) != null);
  bool get _complete =>
      _integer('jurusanTerpasang') != null &&
      _integer('jurusanTerpakai') != null &&
      _numericKeys.every((key) => _number(key) != null) &&
      conditionLabels.keys.every((key) => _text(key).isNotEmpty) &&
      _wbpFix != null && _lwbpFix != null && _wbpTime.isNotEmpty && _lwbpTime.isNotEmpty;

  Future<void> _capture(bool wbp) async {
    final blocked = wbp ? _wbpFix != null || _gettingWbp : _lwbpFix != null || _gettingLwbp;
    if (readOnly || _saving || blocked) return;
    setState(() { if (wbp) { _gettingWbp = true; _wbpAccuracy = null; } else { _gettingLwbp = true; _lwbpAccuracy = null; } });
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, accuracy) {
          if (!mounted) return;
          setState(() { if (wbp) { _wbpAccuracy = accuracy; } else { _lwbpAccuracy = accuracy; } });
        },
      );
      if (!mounted) return;
      final gardu = _garduCoordinate;
      final distance = gardu == null ? null : Geolocator.distanceBetween(gardu[0], gardu[1], fix.latitude, fix.longitude);
      final stamp = WoInsjar.stampLengkap(fix.capturedAt);
      setState(() {
        if (wbp) { _wbpFix = fix; _wbpTime = stamp; _wbpDistance = distance; }
        else { _lwbpFix = fix; _lwbpTime = stamp; _lwbpDistance = distance; }
      });
    } catch (error) {
      if (mounted) _message('$error', error:true);
    } finally {
      if (mounted) setState(() { if (wbp) { _gettingWbp = false; } else { _gettingLwbp = false; } });
    }
  }

  Future<void> _savePressed() async {
    if (_saving || readOnly) return;
    if (_hasDecimalError) { setState(() {}); _message('Perbaiki kolom merah. Gunakan (,) sebagai pemisah.', error:true); return; }
    await _refreshFindingCount();
    if (!_complete) { await _persist(false); return; }
    if (!mounted) return;
    final finish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
        icon: const Icon(Icons.fact_check_rounded, color:blue, size:42),
        title: const Text('Semua data sudah lengkap'),
        content: const Text('Simpan data sekaligus selesaikan WO ini? WO yang selesai akan dikunci dan siap disinkronkan.'),
        actions: [
          TextButton(onPressed:() => Navigator.pop(dialogContext, false), child:const Text('Simpan saja')),
          FilledButton(onPressed:() => Navigator.pop(dialogContext, true), style:FilledButton.styleFrom(backgroundColor:gold, foregroundColor:navy), child:const Text('Selesaikan WO')),
        ],
      ),
    );
    if (finish != null) await _persist(finish);
  }

  Future<void> _persist(bool finish) async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final start = WoInsjar.parseStamp(wo.waktuMulai) ?? WoInsjar.parseStamp(_wbpTime) ?? now;
      final saved = WoInsdu(
        id:wo.id,no:wo.no,kodeWo:wo.kodeWo,kodeUiw:wo.kodeUiw,kodeUp3:wo.kodeUp3,kodeUlp:wo.kodeUlp,ulp:wo.ulp,hari:wo.hari,tanggal:wo.tanggal,penyulang:wo.penyulang,section:wo.section,nomorGardu:wo.nomorGardu,koordinatGardu:wo.koordinatGardu,lat:wo.lat,long:wo.long,jurusan:wo.jurusan,
        jurusanTerpasang:_integer('jurusanTerpasang'),jurusanTerpakai:_integer('jurusanTerpakai'),
        bebanUtamaRWbp:_number('bebanUtamaRWbp'),bebanUtamaSWbp:_number('bebanUtamaSWbp'),bebanUtamaTWbp:_number('bebanUtamaTWbp'),bebanJurusanNWbp:_number('bebanJurusanNWbp'),teganganRswbp:_number('teganganRswbp'),teganganStwbp:_number('teganganStwbp'),teganganRtwbp:_number('teganganRtwbp'),teganganRnwbp:_number('teganganRnwbp'),teganganSnwbp:_number('teganganSnwbp'),teganganTnwbp:_number('teganganTnwbp'),
        bebanUtamaRLwbp:_number('bebanUtamaRLwbp'),bebanUtamaSLwbp:_number('bebanUtamaSLwbp'),bebanUtamaTLwbp:_number('bebanUtamaTLwbp'),bebanJurusanNLwbp:_number('bebanJurusanNLwbp'),teganganRslwbp:_number('teganganRslwbp'),teganganStlwbp:_number('teganganStlwbp'),teganganRtlwbp:_number('teganganRtlwbp'),teganganRnlwbp:_number('teganganRnlwbp'),teganganSnlwbp:_number('teganganSnlwbp'),teganganTnlwbp:_number('teganganTnlwbp'),
        koordinatPenginputanWbp:_wbpFix?.coordinate ?? '',waktuPenginputanWbp:_wbpTime,jarakGarduPetugasWbp:_wbpDistance,koordinatPenginputanLwbp:_lwbpFix?.coordinate ?? '',waktuPenginputanLwbp:_lwbpTime,jarakGarduPetugasLwbp:_lwbpDistance,
        coverFcoAtas:_text('coverFcoAtas'),coverFcoBawah:_text('coverFcoBawah'),coverBushingTm:_text('coverBushingTm'),coverBushingTr:_text('coverBushingTr'),coverArrester:_text('coverArrester'),jumperanAtas:_text('jumperanAtas'),jumperanBawah:_text('jumperanBawah'),
        waktuMulai:wo.waktuMulai.isEmpty ? WoInsjar.stampLengkap(start) : wo.waktuMulai,waktuSelesai:finish ? WoInsjar.stampLengkap(now) : wo.waktuSelesai,durasiPekerjaan:finish ? WoInsjar.hitungDurasi(start,now) : wo.durasiPekerjaan,statusWo:finish ? WoInsdu.statusSelesai : WoInsdu.statusDalam,isDirty:finish,
      );
      await _repo.simpan(saved, dirty:finish);
      if (!mounted) return;
      if (finish) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
            icon: const Icon(Icons.check_circle_rounded, color:Color(0xFF16A34A), size:48),
            title: const Text('WO sudah selesai'),
            content: Text('Semua data Inspeksi Gardu telah disimpan dan dikunci.\n\n${wo.kodeWo}'),
            actions: [FilledButton(onPressed:() => Navigator.pop(dialogContext), style:FilledButton.styleFrom(backgroundColor:gold, foregroundColor:navy), child:const Text('Tutup'))],
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _message('Gagal menyimpan WO: $error', error:true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error=false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text), backgroundColor:error ? Colors.red.shade700 : Colors.green.shade700));

  WoInsjar get _findingWo => WoInsjar(
    kodeWo:wo.kodeWo,kodeUiw:wo.kodeUiw,kodeUp3:wo.kodeUp3,kodeUlp:wo.kodeUlp,ulp:wo.ulp,
    hari:wo.hari,tanggal:wo.tanggal,penyulang:wo.penyulang,section:wo.section,statusWo:WoInsjar.statusDalam,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: page,
    appBar: AppBar(backgroundColor:blue, foregroundColor:Colors.white, title:const Text('Inspeksi Gardu', style:TextStyle(fontWeight:FontWeight.w900))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16,18,16,28),
      children: [
        _hero(), const SizedBox(height:20), _identity(), const SizedBox(height:18),
        _measurement('02','Pengukuran WBP',true), const SizedBox(height:18),
        _measurement('03','Pengukuran LWBP',false), const SizedBox(height:18),
        _conditions(), const SizedBox(height:18), _findings(), const SizedBox(height:18), _summary(),
      ],
    ),
    bottomNavigationBar: readOnly ? null : SafeArea(
      minimum: const EdgeInsets.fromLTRB(16,10,16,14),
      child: SizedBox(
        height:54,
        child: ElevatedButton(
          onPressed:_saving ? null : _savePressed,
          style:ElevatedButton.styleFrom(backgroundColor:gold, foregroundColor:navy, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
          child:Text(_saving ? 'Menyimpan...' : 'Simpan', style:const TextStyle(fontWeight:FontWeight.w900)),
        ),
      ),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.fromLTRB(22,24,22,26),
    decoration: BoxDecoration(gradient:const LinearGradient(colors:[blue,darkBlue]), borderRadius:BorderRadius.circular(25)),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Row(children:[const Expanded(child:Text('WORK ORDER INSPEKSI GARDU', style:TextStyle(color:Color(0xFFB9D9EA),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.5))), _statusChip()]),
      const SizedBox(height:27),
      const Text('NOMOR GARDU', style:TextStyle(color:gold,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.3)),
      const SizedBox(height:8),
      Text(wo.nomorGardu.isEmpty ? '-' : wo.nomorGardu, style:const TextStyle(color:Colors.white,fontSize:40,height:1,fontWeight:FontWeight.w900)),
      const SizedBox(height:20),
      Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(border:Border.all(color:const Color(0xFF70A8CC)),borderRadius:BorderRadius.circular(10)),child:Text(wo.kodeWo,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800))),
      const SizedBox(height:20),
      Text('${wo.ulp} • ${wo.penyulang} • ${wo.tanggal}', style:const TextStyle(color:Color(0xFFD7EAF5),fontSize:13)),
    ]),
  );

  Widget _statusChip() => Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
    decoration:BoxDecoration(color:paleGold,borderRadius:BorderRadius.circular(99)),
    child:Text(WoInsdu.normalisasiStatus(wo.statusWo),style:const TextStyle(color:Color(0xFF8A6200),fontSize:10,fontWeight:FontWeight.w900)),
  );

  Widget _identity() => _card('01','Identitas Gardu',Padding(
    padding:const EdgeInsets.all(18),
    child:Column(children:[
      Row(children:[Expanded(child:_readonly('PENYULANG',wo.penyulang)),const SizedBox(width:12),Expanded(child:_readonly('SECTION',wo.section))]),
      const SizedBox(height:15),
      Row(children:[Expanded(child:_integerField('jurusanTerpasang','JURUSAN TERPASANG')),const SizedBox(width:12),Expanded(child:_integerField('jurusanTerpakai','JURUSAN TERPAKAI'))]),
    ]),
  ));

  Widget _measurement(String number, String title, bool wbp) {
    final fix = wbp ? _wbpFix : _lwbpFix;
    final loading = wbp ? _gettingWbp : _gettingLwbp;
    final accuracy = wbp ? _wbpAccuracy : _lwbpAccuracy;
    final distance = wbp ? _wbpDistance : _lwbpDistance;
    final time = wbp ? _wbpTime : _lwbpTime;
    return _card(number,title,Padding(
      padding:const EdgeInsets.all(18),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _locationHeader(wbp), const SizedBox(height:12),
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(border:Border.all(color:line),borderRadius:BorderRadius.circular(12)),child:Text(loading ? (accuracy==null?'Mencari koordinat...':'Akurasi terbaik ${accuracy.toStringAsFixed(1)} m') : (fix?.coordinate ?? 'Belum direkam'),style:const TextStyle(color:blue,fontSize:12,fontWeight:FontWeight.w900))),
        _timeRow(wbp?'Waktu Penginputan WBP':'Waktu Penginputan LWBP',time),
        Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[const Expanded(child:Text('Jarak Gardu ke Petugas',style:TextStyle(color:muted,fontSize:12))),Text(distance==null?'—':'${distance.toStringAsFixed(1).replaceAll('.', ',')} m',style:const TextStyle(color:navy,fontSize:28,fontWeight:FontWeight.w900))])),
        const Divider(), _groupHeader('A','Beban Utama','ARUS'), _numericGrid(wbp?wbpLoad:lwbpLoad,wbp),
        const SizedBox(height:20), const Divider(), _groupHeader('V','Tegangan','VOLT'), _numericGrid(wbp?wbpVoltage:lwbpVoltage,wbp),
      ]),
    ));
  }

  Widget _locationHeader(bool wbp) => Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:cyan,borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFF7FC8D8))),
    child:Row(children:[
      Container(width:48,height:48,alignment:Alignment.center,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Stack(alignment:Alignment.center,children:[const Icon(Icons.gps_fixed_rounded,color:blue,size:32),Container(width:7,height:7,decoration:const BoxDecoration(color:gold,shape:BoxShape.circle))])),
      const SizedBox(width:12),
      Expanded(child:Text(wbp?'Lokasi Penginputan WBP':'Lokasi Penginputan LWBP',style:const TextStyle(color:navy,fontWeight:FontWeight.w900))),
    ]),
  );

  Widget _timeRow(String label, String value) => Padding(
    padding:const EdgeInsets.symmetric(vertical:15),
    child:Row(children:[
      Container(width:40,height:40,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFFD7F0FA),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.access_time_rounded,color:blue,size:20)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:muted,fontSize:11)),const SizedBox(height:3),Text(value.isEmpty?'Belum direkam':value,style:const TextStyle(color:navy,fontSize:12,fontWeight:FontWeight.w900))])),
    ]),
  );

  Widget _groupHeader(String unit, String title, String suffix) => Padding(
    padding:const EdgeInsets.symmetric(vertical:14),
    child:Row(children:[Container(width:30,height:30,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFFBDEEF6),borderRadius:BorderRadius.circular(9)),child:Text(unit,style:const TextStyle(color:blue,fontWeight:FontWeight.w900))),const SizedBox(width:10),Text(title,style:const TextStyle(color:navy,fontSize:15,fontWeight:FontWeight.w900)),const Spacer(),Text(suffix,style:const TextStyle(color:blue,fontSize:10,fontWeight:FontWeight.w900))]),
  );

  Widget _numericGrid(Map<String,String> entries, bool wbp) => LayoutBuilder(
    builder:(context,constraints) {
      final width=(constraints.maxWidth-12)/2;
      return Wrap(
        spacing:12,
        runSpacing:14,
        children:entries.entries.map((entry) => SizedBox(
          width:width,
          child:TextField(controller:_fields[entry.key],enabled:!readOnly,keyboardType:const TextInputType.numberWithOptions(decimal:true),onTap:()=>_capture(wbp),onChanged:(_)=>setState((){}),decoration:_decoration(entry.value).copyWith(errorText:_decimalError(entry.key))),
        )).toList(),
      );
    },
  );

  Widget _conditions() => _card('04','Kondisi Cover & Jumperan',Padding(
    padding:const EdgeInsets.all(18),
    child:Column(children:conditionLabels.entries.map((entry) {
      final options=entry.key.startsWith('jumperan')?jumperOptions:coverOptions;
      final current=_text(entry.key);
      return Padding(
        padding:const EdgeInsets.only(bottom:14),
        child:DropdownButtonFormField<String>(key:ValueKey('condition-${entry.key}-$current'),isExpanded:true,initialValue:options.contains(current)?current:null,hint:const Text('Pilih kondisi'),items:options.map((value)=>DropdownMenuItem(value:value,child:Text(value))).toList(),onChanged:readOnly?null:(value)=>setState(()=>_fields[entry.key]!.text=value??''),decoration:_decoration(entry.value.toUpperCase())),
      );
    }).toList()),
  ));

  Widget _findings() {
    final token = '${widget.sesi['token'] ?? ''}';
    final child = token.isEmpty
        ? Center(child:Text('$_findingCount Temuan',style:const TextStyle(fontWeight:FontWeight.w900)))
        : TemuanTab(key:ValueKey('temuan-${wo.kodeWo}'),wo:_findingWo,sesi:widget.sesi,canAddTemuan:!readOnly);
    return _card('05','Temuan Inspeksi',SizedBox(height:390,child:child));
  }

  Widget _summary() => _card('06','Ringkasan Pekerjaan',Padding(
    padding:const EdgeInsets.fromLTRB(18,8,18,18),
    child:Column(children:[
      _summaryRow(Icons.access_time_rounded,'Waktu Mulai',wo.waktuMulai),
      _summaryRow(Icons.access_time_rounded,'Waktu Selesai',wo.waktuSelesai),
      _summaryRow(Icons.timelapse_rounded,'Durasi',wo.durasiPekerjaan),
      _summaryRow(Icons.chat_bubble_outline_rounded,'Jumlah Temuan','$_findingCount temuan',last:true),
    ]),
  ));

  Widget _summaryRow(IconData icon, String label, String value, {bool last=false}) => Container(
    constraints:const BoxConstraints(minHeight:66),
    decoration:BoxDecoration(border:last?null:const Border(bottom:BorderSide(color:line))),
    child:Row(children:[Container(width:40,height:40,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFFD7F0FA),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:blue,size:20)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(label,style:const TextStyle(color:muted,fontSize:11)),const SizedBox(height:3),Text(value.trim().isEmpty?'-':value,style:const TextStyle(color:navy,fontSize:12,fontWeight:FontWeight.w900))]))]),
  );

  Widget _card(String number, String title, Widget child) => Container(
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:line)),
    clipBehavior:Clip.antiAlias,
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.all(18),child:Row(children:[Container(width:36,height:36,alignment:Alignment.center,decoration:BoxDecoration(color:paleGold,shape:BoxShape.circle,border:Border.all(color:gold)),child:Text(number,style:const TextStyle(color:Color(0xFF7A5700),fontSize:11,fontWeight:FontWeight.w900))),const SizedBox(width:12),Text(title,style:const TextStyle(color:navy,fontSize:17,fontWeight:FontWeight.w900))])),const Divider(height:1),child]),
  );

  Widget _readonly(String label, String value) => InputDecorator(decoration:_decoration(label),child:Text(value.isEmpty?'-':value,style:const TextStyle(fontWeight:FontWeight.w900)));
  Widget _integerField(String key, String label) => TextField(controller:_fields[key],enabled:!readOnly,keyboardType:TextInputType.number,decoration:_decoration(label));
  InputDecoration _decoration(String label) => InputDecoration(labelText:label,floatingLabelBehavior:FloatingLabelBehavior.always,isDense:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(13),borderSide:const BorderSide(color:line)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),borderSide:const BorderSide(color:line)),errorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),borderSide:const BorderSide(color:Colors.red,width:1.5)),focusedErrorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),borderSide:const BorderSide(color:Colors.red,width:2)));
}
