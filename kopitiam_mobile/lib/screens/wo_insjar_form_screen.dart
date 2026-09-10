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

class _WoInsjarFormScreenState extends State<WoInsjarFormScreen> with SingleTickerProviderStateMixin {
  static const blue = Color(0xFF0A3E74), navy = Color(0xFF071B30), amber = Color(0xFFFFAE00), muted = Color(0xFF64748B), line = Color(0xFFE2E8F0);
  final _repo = WoInsjarRepository();
  late final TabController _tabs;
  LocationFix? _awal, _akhir;
  DateTime? _mulai, _selesai;
  double _kms = 0;
  String _status = WoInsjar.statusMulai;
  bool _gettingAwal = false, _gettingAkhir = false, _saving = false;
  double? _awalSearchAccuracy, _akhirSearchAccuracy;
  WoInsjar? get _wo => widget.existing;
  bool get _readOnly => WoInsjar.normalisasiStatus(_status) == WoInsjar.statusSelesai;
  bool get _readyToComplete => _awal != null && _akhir != null && _selesai != null;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); final wo = _wo; _kms = wo?.realisasiKms ?? 0; _status = WoInsjar.normalisasiStatus(wo?.statusWo); _mulai = WoInsjar.parseStamp(wo?.waktuMulai ?? ''); _selesai = WoInsjar.parseStamp(wo?.waktuSelesai ?? ''); _awal = _savedFix(wo?.koordinatAwal ?? ''); _akhir = _savedFix(wo?.koordinatAkhir ?? ''); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
  LocationFix? _savedFix(String coordinate) { if (coordinate.trim().isEmpty) return null; final parts = coordinate.split(','); if (parts.length < 2) return null; return LocationFix(latitude: double.tryParse(parts[0].trim()) ?? 0, longitude: double.tryParse(parts[1].trim()) ?? 0, accuracy: 5, capturedAt: DateTime.now(), samples: 30, locked: true); }
  String get _duration => _mulai == null || _selesai == null ? (_wo?.durasiPekerjaan.isNotEmpty == true ? _wo!.durasiPekerjaan : '-') : WoInsjar.hitungDurasi(_mulai!, _selesai!);

  Future<void> _getCoordinate(bool start) async {
    if (_readOnly || _saving) return;
    setState(() { if (start) { _gettingAwal = true; _awalSearchAccuracy = null; } else { _gettingAkhir = true; _akhirSearchAccuracy = null; } });
    try {
      final fix = await HighAccuracyLocationService.acquire(onSample: (_, accuracy) { if (!mounted) return; setState(() { if (start) { _awalSearchAccuracy = accuracy; } else { _akhirSearchAccuracy = accuracy; } }); });
      if (!mounted) return;
      setState(() { if (start) { _awal = fix; _mulai ??= fix.capturedAt; } else { _akhir = fix; _selesai = fix.capturedAt; } if (_awal != null && _akhir != null) { _kms = Geolocator.distanceBetween(_awal!.latitude, _awal!.longitude, _akhir!.latitude, _akhir!.longitude) / 1000; } else if (_awal != null) { _status = WoInsjar.statusDalam; } });
    } catch (error) { if (mounted) _message('$error', error: true); } finally { if (mounted) setState(() { if (start) { _gettingAwal = false; } else { _gettingAkhir = false; } }); }
  }

  Future<void> _save() async {
    if (_readOnly || _wo == null || _saving) return;
    setState(() => _saving = true);
    try { await _repo.simpan(_wo!.copyWith(koordinatAwal: _awal?.coordinate, koordinatAkhir: _akhir?.coordinate, realisasiKms: _kms, waktuMulai: _mulai == null ? null : WoInsjar.stampLengkap(_mulai!), waktuSelesai: _selesai == null ? null : WoInsjar.stampLengkap(_selesai!), durasiPekerjaan: _duration == '-' ? null : _duration, statusWo: _readyToComplete ? WoInsjar.statusSelesai : _status, isDirty: true)); if (mounted) Navigator.pop(context, true); } catch (error) { if (mounted) _message('Gagal menyimpan WO: $error', error: true); } finally { if (mounted) setState(() => _saving = false); }
  }
  void _message(String text, {bool error = false}) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green)); }

  @override
  Widget build(BuildContext context) {
    final wo = _wo;
    if (wo == null) return const Scaffold(body: Center(child: Text('WO tidak ditemukan.')));
    return Scaffold(backgroundColor: const Color(0xFFF4F7FB), appBar: AppBar(backgroundColor: blue, foregroundColor: Colors.white, title: const Text('WO Inspeksi Jaringan', style: TextStyle(fontWeight: FontWeight.w800)), bottom: TabBar(controller: _tabs, labelColor: Colors.white, unselectedLabelColor: const Color(0xFFB8DCEF), indicatorColor: const Color(0xFF00E5FF), tabs: const [Tab(text: 'Work Order'), Tab(text: 'Temuan')])), body: Column(children: [_header(wo), Expanded(child: TabBarView(controller: _tabs, children: [_workOrder(wo), Stack(children: [TemuanTab(key: ValueKey('temuan-${wo.kodeWo}'), wo: wo, sesi: widget.sesi, canAddTemuan: _awal != null), if (_readOnly) const Positioned(right: 8, bottom: 8, child: Text('Read-only'))])]))]);
  }

  Widget _header(WoInsjar wo) => Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Kode WO', style: TextStyle(color: Color(0xFFB8DCEF))), const SizedBox(height: 4), Text(wo.kodeWo, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text('${wo.ulp} • ${wo.kodeUlp}', style: const TextStyle(color: Color(0xFFD5E8F3)))]);
  Widget _workOrder(WoInsjar wo) => Column(children: [Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), children: [_identity(wo), const SizedBox(height: 14), _coordinateCard('Koordinat Awal', _awal, _gettingAwal, true), const SizedBox(height: 14), _coordinateCard('Koordinat Akhir', _akhir, _gettingAkhir, false), const SizedBox(height: 14), _summary()])), if (!_readOnly) Container(color: Colors.white, padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: amber, foregroundColor: navy), child: _saving ? const CircularProgressIndicator(color: blue) : Text(_readyToComplete ? 'Simpan & Selesaikan WO' : 'Simpan WO ke Server Lokal'))))]);
  Widget _identity(WoInsjar wo) => Container(padding: const EdgeInsets.all(14), decoration: _box(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Penyulang'), _value(wo.penyulang), const SizedBox(height: 12), Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Section Awal'), _value(wo.sectionAwal)])), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Section Akhir'), _value(wo.sectionAkhir)]))]), const SizedBox(height: 12), _label('Section'), _value(wo.section)]);
  Widget _coordinateCard(String title, LocationFix? fix, bool loading, bool start) { final locked = !start && _awal == null; final accuracy = start ? _awalSearchAccuracy : _akhirSearchAccuracy; return AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: locked ? .62 : 1, child: Container(padding: const EdgeInsets.all(16), decoration: _box(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))), if (_readOnly) const Icon(Icons.lock_rounded, size: 17, color: muted)]), const SizedBox(height: 8), Text(fix?.coordinate ?? '-', style: const TextStyle(color: blue, fontWeight: FontWeight.w700)), if (loading || fix != null) ...[const SizedBox(height: 6), Text(loading ? accuracy == null ? 'Menunggu sampel GPS...' : 'Akurasi terbaik: ${accuracy.toStringAsFixed(1)} m' : 'Akurasi: ${fix!.accuracyLabel}', style: const TextStyle(color: blue, fontSize: 12, fontWeight: FontWeight.w700))], if (!_readOnly) ...[const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: loading || _saving || locked ? null : () => _getCoordinate(start), icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.3)) : const Icon(Icons.my_location_rounded), label: Text(loading ? 'Mencari koordinat...' : 'Ambil Koordinat Perangkat')))] ])));
  }
  Widget _summary() => Container(padding: const EdgeInsets.all(16), decoration: _box(), child: Column(children: [_row('Realisasi kmS', '${_kms.toStringAsFixed(3)} km'), const Divider(), _row('Waktu Mulai', _mulai == null ? '-' : WoInsjar.stampLengkap(_mulai!)), const Divider(), _row('Waktu Selesai', _selesai == null ? '-' : WoInsjar.stampLengkap(_selesai!)), const Divider(), _row('Durasi Pekerjaan', _duration), const Divider(), _row('Status WO', _status)]));
  BoxDecoration _box() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line));
  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)));
  Widget _value(String text) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)), child: Text(text.isEmpty ? '-' : text));
  Widget _row(String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 112, child: Text(label, style: const TextStyle(color: muted, fontSize: 12))), const SizedBox(width: 8), Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))) ]);
}
