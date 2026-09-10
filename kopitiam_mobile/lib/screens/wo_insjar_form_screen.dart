import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/wo_insjar_repository.dart';
import 'temuan_tab.dart';

class WoInsjarFormScreen extends StatefulWidget {
  final WoInsjar? existing;
  final Map<String, dynamic> sesi;

  const WoInsjarFormScreen({super.key, this.existing, required this.sesi});

  @override
  State<WoInsjarFormScreen> createState() => _WoInsjarFormScreenState();
}

class _WoInsjarFormScreenState extends State<WoInsjarFormScreen> {
  static const ink = Color(0xFF071F33);
  static const navy = Color(0xFF063B5C);
  static const blue = Color(0xFF004D8C);
  static const blueLight = Color(0xFF176DA8);
  static const gold = Color(0xFFD6A93A);
  static const yellow = Color(0xFFF6D03F);
  static const surface = Color(0xFFFBFDFE);
  static const background = Color(0xFFF4F7FB);
  static const line = Color(0xFFDCE8EC);
  static const muted = Color(0xFF667D86);
  static const soft = Color(0xFFE8F4FC);
  static const success = Color(0xFF16834B);

  final _repo = WoInsjarRepository();
  LocationFix? _awal;
  LocationFix? _akhir;
  DateTime? _mulai;
  DateTime? _selesai;
  double _kms = 0;
  String _status = WoInsjar.statusMulai;
  bool _gettingAwal = false;
  bool _gettingAkhir = false;
  bool _saving = false;
  double? _awalSearchAccuracy;
  double? _akhirSearchAccuracy;

  WoInsjar? get _wo => widget.existing;
  bool get _readOnly => WoInsjar.normalisasiStatus(_status) == WoInsjar.statusSelesai;
  bool get _readyToComplete => _awal != null && _akhir != null && _selesai != null;

  @override
  void initState() {
    super.initState();
    final wo = _wo;
    _kms = wo?.realisasiKms ?? 0;
    _status = WoInsjar.normalisasiStatus(wo?.statusWo);
    _mulai = WoInsjar.parseStamp(wo?.waktuMulai ?? '');
    _selesai = WoInsjar.parseStamp(wo?.waktuSelesai ?? '');
    _awal = _savedFix(wo?.koordinatAwal ?? '');
    _akhir = _savedFix(wo?.koordinatAkhir ?? '');
  }

  LocationFix? _savedFix(String coordinate) {
    if (coordinate.trim().isEmpty) return null;
    final parts = coordinate.split(',');
    if (parts.length < 2) return null;
    return LocationFix(latitude: double.tryParse(parts[0].trim()) ?? 0, longitude: double.tryParse(parts[1].trim()) ?? 0, accuracy: 5, capturedAt: DateTime.now(), samples: 30, locked: true);
  }

  String get _duration {
    if (_mulai == null || _selesai == null) return _wo?.durasiPekerjaan.isNotEmpty == true ? _wo!.durasiPekerjaan : '-';
    return WoInsjar.hitungDurasi(_mulai!, _selesai!);
  }

  Future<void> _getCoordinate(bool start) async {
    if (_readOnly || _saving || (!start && _awal == null)) return;
    setState(() { if (start) { _gettingAwal = true; _awalSearchAccuracy = null; } else { _gettingAkhir = true; _akhirSearchAccuracy = null; } });
    try {
      final fix = await HighAccuracyLocationService.acquire(onSample: (_, bestAccuracy) { if (!mounted) return; setState(() { if (start) { _awalSearchAccuracy = bestAccuracy; } else { _akhirSearchAccuracy = bestAccuracy; } }); });
      if (!mounted) return;
      setState(() {
        if (start) { _awal = fix; _mulai ??= fix.capturedAt; _status = WoInsjar.statusDalam; } else { _akhir = fix; _selesai = fix.capturedAt; }
        if (_awal != null && _akhir != null) _kms = Geolocator.distanceBetween(_awal!.latitude, _awal!.longitude, _akhir!.latitude, _akhir!.longitude) / 1000;
      });
    } catch (error) { if (mounted) _message('$error', error: true); } finally { if (mounted) setState(() { if (start) { _gettingAwal = false; } else { _gettingAkhir = false; } }); }
  }

  Future<void> _save() async {
    if (_readOnly || _wo == null || _saving) return;
    final complete = _readyToComplete;
    final nextStatus = complete ? WoInsjar.statusSelesai : _status;
    setState(() => _saving = true);
    try {
      await _repo.simpan(_wo!.copyWith(koordinatAwal: _awal?.coordinate, koordinatAkhir: _akhir?.coordinate, realisasiKms: _kms, waktuMulai: _mulai == null ? null : WoInsjar.stampLengkap(_mulai!), waktuSelesai: _selesai == null ? null : WoInsjar.stampLengkap(_selesai!), durasiPekerjaan: _duration == '-' ? null : _duration, statusWo: nextStatus, isDirty: true));
      if (!mounted) return;
      if (complete) { await _showFinishedDialog(); if (mounted) Navigator.pop(context, true); } else { _message('Data Progress Pekerjaan Tersimpan'); }
    } catch (error) { if (mounted) _message('Gagal menyimpan WO: $error', error: true); } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _showFinishedDialog() => showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => Dialog(clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 26), decoration: const BoxDecoration(gradient: LinearGradient(colors: [blueLight, blue, navy], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: const Column(children: [CircleAvatar(radius: 28, backgroundColor: yellow, foregroundColor: ink, child: Icon(Icons.check_rounded, size: 30)), SizedBox(height: 16), Text('WO sudah selesai', style: TextStyle(color: surface, fontSize: 21, fontWeight: FontWeight.w900))]),), Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Text('Silahkan lakukan sinkron data', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 22), SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(dialogContext), style: FilledButton.styleFrom(backgroundColor: navy, minimumSize: const Size.fromHeight(48)), child: const Text('Tutup')))]))]));

  void _message(String text, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : ink));

  @override
  Widget build(BuildContext context) {
    final wo = _wo;
    if (wo == null) return const Scaffold(body: Center(child: Text('WO tidak ditemukan.')));
    return Scaffold(backgroundColor: background, appBar: AppBar(backgroundColor: surface, foregroundColor: ink, elevation: 0, surfaceTintColor: surface, title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Inspeksi Jaringan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), Text('Form Work Order', style: TextStyle(color: muted, fontSize: 11))])), body: Column(children: [Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [_hero(wo), _section(1, 'Area inspeksi', _area(wo)), _section(2, 'Koordinat Pekerjaan', _coordinates()), _section(3, 'Temuan inspeksi', SizedBox(height: 360, child: TemuanTab(key: ValueKey('temuan-${wo.kodeWo}-${_awal != null}'), wo: wo, sesi: widget.sesi, canAddTemuan: _awal != null && !_readOnly))), _section(4, 'Ringkasan pekerjaan', _summary())])), if (!_readOnly) Container(padding: const EdgeInsets.fromLTRB(18, 12, 18, 16), decoration: const BoxDecoration(color: surface, border: Border(top: BorderSide(color: line))), child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: _readyToComplete ? yellow : navy, foregroundColor: _readyToComplete ? ink : surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), child: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: surface)) : Text(_readyToComplete ? 'Simpan & selesaikan WO' : 'Simpan progres', style: const TextStyle(fontWeight: FontWeight.w900)))))]));
  }

  Widget _hero(WoInsjar wo) => Container(clipBehavior: Clip.antiAlias, padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [blueLight, blue, navy], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x2E063B5C), blurRadius: 28, offset: Offset(0, 12))]), child: Stack(children: [const Positioned(right: -34, top: -54, child: _GoldRing(size: 118)), const Positioned(right: 34, top: 18, child: _GoldRing(size: 72, opacity: .4)), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('KODE WORK ORDER', style: TextStyle(color: Color(0xFFD7EBEF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)), const SizedBox(height: 5), Text(wo.kodeWo, style: const TextStyle(color: surface, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 14), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Text('${wo.ulp} • ${wo.kodeUlp}', style: const TextStyle(color: Color(0xFFD7EBEF), fontSize: 11))), _heroStatus()])])]);
  Widget _heroStatus(){final done=_readOnly;return Container(height:30,padding:const EdgeInsets.symmetric(horizontal:11),decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(100),border:Border.all(color:gold),boxShadow:const[BoxShadow(color:Color(0x33071F33),blurRadius:16,offset:Offset(0,7))]),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(done?Icons.check_circle_rounded:Icons.circle,size:done?13:7,color:done?success:blueLight),const SizedBox(width:6),Text(done?'Selesai':'Sedang dikerjakan',style:TextStyle(color:done?success:blue,fontSize:10,fontWeight:FontWeight.w900))]));}
  Widget _section(int number,String title,Widget child)=>Container(padding:const EdgeInsets.symmetric(vertical:24),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:line))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:27,height:27,alignment:Alignment.center,decoration:BoxDecoration(border:Border.all(color:gold),shape:BoxShape.circle),child:Text(number.toString().padLeft(2,'0'),style:const TextStyle(color:Color(0xFF8B6100),fontSize:10,fontWeight:FontWeight.w900))),const SizedBox(width:12),Text(title,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900))]),const SizedBox(height:18),Padding(padding:const EdgeInsets.only(left:39),child:child)]));
  Widget _area(WoInsjar wo)=>Container(clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:line)),child:Column(children:[_areaRow('PENYULANG',wo.penyulang),const Divider(height:1,color:line),_areaRow('SECTION',[wo.sectionAwal,wo.sectionAkhir].where((v)=>v.trim().isNotEmpty).join(' - '))]));
  Widget _areaRow(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:13),child:Row(children:[SizedBox(width:84,child:Text(label,style:const TextStyle(color:muted,fontSize:9))),Expanded(child:Text(value.trim().isEmpty?'-':value,textAlign:TextAlign.right,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)))]));
  Widget _coordinates()=>Column(children:[_coordinateCard('Koordinat awal',_awal,_gettingAwal,true),const SizedBox(height:10),_coordinateCard('Koordinat akhir',_akhir,_gettingAkhir,false)]);
  Widget _coordinateCard(String title,LocationFix? fix,bool loading,bool start){final locked=!start&&_awal==null;final liveAccuracy=start?_awalSearchAccuracy:_akhirSearchAccuracy;return AnimatedOpacity(duration:const Duration(milliseconds:180),opacity:locked?.62:1,child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(15),border:Border.all(color:fix!=null?const Color(0xFF86CFA5):line)),child:Column(children:[Row(children:[_CoordinateRadar(loading:loading,done:fix!=null),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(height:2),Text(loading?'Mengumpulkan sampel GPS':fix?.coordinate??(locked?'Menunggu koordinat awal':'Belum diambil'),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:10))]))]),if(loading)...[const SizedBox(height:9),Row(children:[const Text('Mengunci titik paling akurat',style:TextStyle(color:blueLight,fontSize:10,fontWeight:FontWeight.w800)),const Spacer(),Text(liveAccuracy==null?'Menunggu...':'${liveAccuracy.toStringAsFixed(1)} m',style:const TextStyle(color:blue,fontSize:10,fontWeight:FontWeight.w900))])],if(!_readOnly)...[const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton(onPressed:locked||loading||_saving?null:()=>_getCoordinate(start),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(44),foregroundColor:blueLight,side:const BorderSide(color:blueLight),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(11))),child:Text(loading?'Mencari koordinat...':fix==null?'Ambil koordinat':'Ambil ulang koordinat',style:const TextStyle(fontWeight:FontWeight.w900))))])]));}
  Widget _summary()=>GridView.count(crossAxisCount:2,crossAxisSpacing:8,mainAxisSpacing:8,childAspectRatio:1.75,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),children:[_metric('Realisasi kmS','${_kms.toStringAsFixed(3)} km'),_metric('Durasi',_duration),_metric('Waktu mulai',_mulai==null?'Belum tersedia':WoInsjar.stampLengkap(_mulai!)),_metric('Waktu selesai',_selesai==null?'Belum tersedia':WoInsjar.stampLengkap(_selesai!))]);
  Widget _metric(String label,String value)=>Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:soft,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(label,style:const TextStyle(color:muted,fontSize:9)),const SizedBox(height:4),Text(value,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))]);
}
class _GoldRing extends StatelessWidget{final double size;final double opacity;const _GoldRing({required this.size,this.opacity=.72});@override Widget build(BuildContext context)=>Opacity(opacity:opacity,child:Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:_WoInsjarFormScreenState.gold))));}
class _CoordinateRadar extends StatelessWidget{final bool loading;final bool done;const _CoordinateRadar({required this.loading,required this.done});@override Widget build(BuildContext context)=>SizedBox.square(dimension:40,child:Stack(alignment:Alignment.center,children:[if(loading)const SizedBox.square(dimension:40,child:CircularProgressIndicator(strokeWidth:2,color:_WoInsjarFormScreenState.blueLight)),AnimatedContainer(duration:const Duration(milliseconds:180),width:36,height:36,decoration:BoxDecoration(color:done?const Color(0xFFE1F5EC):loading?_WoInsjarFormScreenState.blueLight:_WoInsjarFormScreenState.soft,borderRadius:BorderRadius.circular(loading?18:12)),child:Icon(Icons.my_location_rounded,size:18,color:done?_WoInsjarFormScreenState.success:loading?_WoInsjarFormScreenState.surface:_WoInsjarFormScreenState.blueLight))]));}
