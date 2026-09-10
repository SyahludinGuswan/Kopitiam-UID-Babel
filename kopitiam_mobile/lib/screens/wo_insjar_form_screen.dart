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
  static const gold = Color(0xFFD6A93A);
  static const yellow = Color(0xFFF6D03F);
  static const surface = Color(0xFFFBFDFE);
  static const background = Color(0xFFF4F7FB);
  static const line = Color(0xFFDCE8EC);
  static const muted = Color(0xFF667D86);
  static const soft = Color(0xFFE8F4FC);
  static const success = Color(0xFF16834B);

  final repo = WoInsjarRepository();
  LocationFix? awal;
  LocationFix? akhir;
  DateTime? mulai;
  DateTime? selesai;
  double kms = 0;
  String status = WoInsjar.statusMulai;
  bool loadingAwal = false;
  bool loadingAkhir = false;
  bool saving = false;
  double? accuracyAwal;
  double? accuracyAkhir;

  WoInsjar? get wo => widget.existing;
  bool get readOnly => WoInsjar.normalisasiStatus(status) == WoInsjar.statusSelesai;
  bool get complete => awal != null && akhir != null && selesai != null;
  String get duration => mulai == null || selesai == null ? (wo?.durasiPekerjaan.isNotEmpty == true ? wo!.durasiPekerjaan : '-') : WoInsjar.hitungDurasi(mulai!, selesai!);

  @override
  void initState() {
    super.initState();
    final item = wo;
    kms = item?.realisasiKms ?? 0;
    status = WoInsjar.normalisasiStatus(item?.statusWo);
    mulai = WoInsjar.parseStamp(item?.waktuMulai ?? '');
    selesai = WoInsjar.parseStamp(item?.waktuSelesai ?? '');
    awal = parseFix(item?.koordinatAwal ?? '');
    akhir = parseFix(item?.koordinatAkhir ?? '');
  }

  LocationFix? parseFix(String value) {
    if (value.trim().isEmpty) return null;
    final parts = value.split(',');
    if (parts.length < 2) return null;
    return LocationFix(latitude: double.tryParse(parts[0].trim()) ?? 0, longitude: double.tryParse(parts[1].trim()) ?? 0, accuracy: 5, capturedAt: DateTime.now(), samples: 30, locked: true);
  }

  Future<void> capture(bool start) async {
    if (readOnly || saving || (!start && awal == null)) return;
    setState(() { if (start) { loadingAwal = true; accuracyAwal = null; } else { loadingAkhir = true; accuracyAkhir = null; } });
    try {
      final fix = await HighAccuracyLocationService.acquire(onSample: (_, value) { if (!mounted) return; setState(() { if (start) { accuracyAwal = value; } else { accuracyAkhir = value; } }); });
      if (!mounted) return;
      setState(() {
        if (start) { awal = fix; mulai ??= fix.capturedAt; status = WoInsjar.statusDalam; } else { akhir = fix; selesai = fix.capturedAt; }
        if (awal != null && akhir != null) kms = Geolocator.distanceBetween(awal!.latitude, awal!.longitude, akhir!.latitude, akhir!.longitude) / 1000;
      });
    } catch (error) { if (mounted) message('$error', true); }
    finally { if (mounted) setState(() { if (start) { loadingAwal = false; } else { loadingAkhir = false; } }); }
  }

  Future<void> save() async {
    if (readOnly || wo == null || saving) return;
    setState(() => saving = true);
    try {
      await repo.simpan(wo!.copyWith(koordinatAwal: awal?.coordinate, koordinatAkhir: akhir?.coordinate, realisasiKms: kms, waktuMulai: mulai == null ? null : WoInsjar.stampLengkap(mulai!), waktuSelesai: selesai == null ? null : WoInsjar.stampLengkap(selesai!), durasiPekerjaan: duration == '-' ? null : duration, statusWo: complete ? WoInsjar.statusSelesai : status, isDirty: true));
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) message('Gagal menyimpan WO: $error', true); }
    finally { if (mounted) setState(() => saving = false); }
  }

  void message(String text, bool error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : ink));
  BoxDecoration box() => BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: line));
  Widget read(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)), child: Text(value.trim().isEmpty ? '-' : value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))]);
  Widget section(int number, String title, Widget child) => Container(padding: const EdgeInsets.symmetric(vertical: 22), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: gold), shape: BoxShape.circle), child: Text(number.toString().padLeft(2, '0'), style: const TextStyle(color: Color(0xFF8B6100), fontSize: 10, fontWeight: FontWeight.w900))), const SizedBox(width: 11), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))]), const SizedBox(height: 16), Padding(padding: const EdgeInsets.only(left: 39), child: child)]));
  Widget coordinates() => Column(children: [coordinateCard('Koordinat awal', awal, loadingAwal, true), const SizedBox(height: 10), coordinateCard('Koordinat akhir', akhir, loadingAkhir, false)]);
  Widget coordinateCard(String title, LocationFix? fix, bool loading, bool start) { final locked = !start && awal == null; final accuracy = start ? accuracyAwal : accuracyAkhir; return AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: locked ? .62 : 1, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: fix != null ? const Color(0xFF86CFA5) : line)), child: Column(children: [Row(children: [Icon(Icons.my_location_rounded, color: fix != null ? success : blue, size: 24), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), Text(loading ? 'Mengumpulkan sampel GPS' : fix?.coordinate ?? (locked ? 'Menunggu koordinat awal' : 'Belum diambil'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10))]))]), if (loading) Text(accuracy == null ? 'Menunggu...' : 'Akurasi terbaik: ${accuracy.toStringAsFixed(1)} m', style: const TextStyle(color: blue, fontSize: 10, fontWeight: FontWeight.w800)), if (!readOnly) Padding(padding: const EdgeInsets.only(top: 10), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: locked || loading || saving ? null : () => capture(start), child: Text(loading ? 'Mencari koordinat...' : fix == null ? 'Ambil koordinat' : 'Ambil ulang koordinat'))))]))); }
  Widget area(WoInsjar item) => Container(decoration: box(), child: Column(children: [read('PENYULANG', item.penyulang), const Divider(height: 1), read('SECTION', [item.sectionAwal, item.sectionAkhir].where((v) => v.trim().isNotEmpty).join(' - '))]));
  Widget summary() => GridView.count(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.75, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [metric('Realisasi kmS', '${kms.toStringAsFixed(3)} km'), metric('Durasi', duration), metric('Waktu mulai', mulai == null ? 'Belum tersedia' : WoInsjar.stampLengkap(mulai!)), metric('Waktu selesai', selesai == null ? 'Belum tersedia' : WoInsjar.stampLengkap(selesai!))]);
  Widget metric(String label, String value) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(color: muted, fontSize: 9)), const SizedBox(height: 4), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]);

  @override
  Widget build(BuildContext context) {
    final item = wo;
    if (item == null) return const Scaffold(body: Center(child: Text('WO tidak ditemukan.')));
    return Scaffold(backgroundColor: background, appBar: AppBar(backgroundColor: surface, foregroundColor: ink, elevation: 0, title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Inspeksi Jaringan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), Text('Form Work Order', style: TextStyle(color: muted, fontSize: 11))]), body: Column(children: [Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [_hero(item), section(1, 'Area inspeksi', area(item)), section(2, 'Koordinat Pekerjaan', coordinates()), section(3, 'Temuan inspeksi', SizedBox(height: 360, child: TemuanTab(key: ValueKey('temuan-${item.kodeWo}-${awal != null}'), wo: item, sesi: widget.sesi, canAddTemuan: awal != null && !readOnly))), section(4, 'Ringkasan pekerjaan', summary())])), if (!readOnly) Container(padding: const EdgeInsets.fromLTRB(18, 12, 18, 16), decoration: const BoxDecoration(color: surface, border: Border(top: BorderSide(color: line))), child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: complete ? yellow : navy, foregroundColor: complete ? ink : surface), child: saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator()) : Text(complete ? 'Simpan & selesaikan WO' : 'Simpan progres'))))]));
  }
}
