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
  static const ocean = Color(0xFF0A3E74);
  static const navy = Color(0xFF071B30);
  static const gold = Color(0xFFFFAE00);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const page = Color(0xFFF4F7FB);

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
  bool get _readOnly =>
      WoInsjar.normalisasiStatus(_status) == WoInsjar.statusSelesai;
  bool get _readyToComplete =>
      _awal != null && _akhir != null && _selesai != null;

  @override
  void initState() {
    super.initState();
    final item = _wo;
    _kms = item?.realisasiKms ?? 0;
    _status = WoInsjar.normalisasiStatus(item?.statusWo);
    _mulai = WoInsjar.parseStamp(item?.waktuMulai ?? '');
    _selesai = WoInsjar.parseStamp(item?.waktuSelesai ?? '');
    _awal = _parseFix(item?.koordinatAwal ?? '');
    _akhir = _parseFix(item?.koordinatAkhir ?? '');
  }

  LocationFix? _parseFix(String value) {
    if (value.trim().isEmpty) return null;
    final parts = value.split(',');
    if (parts.length < 2) return null;
    return LocationFix(
      latitude: double.tryParse(parts[0].trim()) ?? 0,
      longitude: double.tryParse(parts[1].trim()) ?? 0,
      accuracy: 5,
      capturedAt: DateTime.now(),
      samples: 30,
      locked: true,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _duration {
    if (_mulai == null || _selesai == null) {
      return _wo?.durasiPekerjaan.isNotEmpty == true
          ? _wo!.durasiPekerjaan
          : '-';
    }
    return WoInsjar.hitungDurasi(_mulai!, _selesai!);
  }

  Future<void> _getCoordinate(bool start) async {
    if (_readOnly || _saving || (!start && _awal == null)) return;
    setState(() {
      if (start) {
        _gettingAwal = true;
        _awalSearchAccuracy = null;
      } else {
        _gettingAkhir = true;
        _akhirSearchAccuracy = null;
      }
    });
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, accuracy) {
          if (!mounted) return;
          setState(() {
            if (start) {
              _awalSearchAccuracy = accuracy;
            } else {
              _akhirSearchAccuracy = accuracy;
            }
          });
        },
      );
      if (!mounted) return;
      setState(() {
        if (start) {
          _awal = fix;
          _mulai ??= fix.capturedAt;
          _status = WoInsjar.statusDalam;
        } else {
          _akhir = fix;
          _selesai = fix.capturedAt;
        }
        if (_awal != null && _akhir != null) {
          _kms = Geolocator.distanceBetween(
                _awal!.latitude,
                _awal!.longitude,
                _akhir!.latitude,
                _akhir!.longitude,
              ) /
              1000;
        }
      });
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          if (start) {
            _gettingAwal = false;
          } else {
            _gettingAkhir = false;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (_readOnly || _wo == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _repo.simpan(
        _wo!.copyWith(
          koordinatAwal: _awal?.coordinate,
          koordinatAkhir: _akhir?.coordinate,
          realisasiKms: _kms,
          waktuMulai: _mulai == null ? null : WoInsjar.stampLengkap(_mulai!),
          waktuSelesai:
              _selesai == null ? null : WoInsjar.stampLengkap(_selesai!),
          durasiPekerjaan: _duration == '-' ? null : _duration,
          statusWo: _readyToComplete ? WoInsjar.statusSelesai : _status,
          isDirty: true,
        ),
      );
      if (mounted) {
        _message(
          _readyToComplete
              ? 'Temuan Tersimpan. WO siap disinkronkan.'
              : 'Progress inspeksi tersimpan di perangkat.',
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) _message('Gagal menyimpan WO: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _wo;
    if (item == null) {
      return const Scaffold(body: Center(child: Text('WO tidak ditemukan.')));
    }

    return Scaffold(
      backgroundColor: page,
      appBar: AppBar(
        backgroundColor: ocean,
        foregroundColor: Colors.white,
        title: const Text(
          'Inspeksi Jaringan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          _hero(item),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _sectionTitle('01', 'Area inspeksi', 'Ruang kerja yang ditugaskan'),
                _areaSection(item),
                const SizedBox(height: 20),
                _sectionTitle('02', 'Koordinat pekerjaan', 'Kunci lokasi dengan GPS perangkat'),
                _coordinateSection(),
                const SizedBox(height: 20),
                _sectionTitle('03', 'Temuan inspeksi', 'Catat kondisi yang ditemukan di lapangan'),
                _findingsSection(item),
                const SizedBox(height: 20),
                _sectionTitle('04', 'Ringkasan pekerjaan', 'Periksa sebelum menyimpan progress'),
                _summarySection(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _readOnly
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text(
                          _readyToComplete ? 'Simpan & Selesaikan WO' : 'Simpan Progress',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _hero(WoInsjar item) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
        decoration: BoxDecoration(
          color: ocean,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'WORK ORDER',
                    style: TextStyle(
                      color: Color(0xFFB8DCEF),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                _statusChip(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.kodeWo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${item.ulp}  •  ${item.kodeUlp}  •  ${item.tanggal}',
              style: const TextStyle(color: Color(0xFFD5E8F3), fontSize: 12),
            ),
          ],
        ),
      );

  Widget _statusChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _readOnly ? const Color(0xFFD1FAE5) : const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _status,
          style: TextStyle(
            color: _readOnly ? const Color(0xFF047857) : const Color(0xFF92400E),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _sectionTitle(String number, String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                color: ocean,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _surface({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: child,
      );

  Widget _areaSection(WoInsjar item) => _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Penyulang'),
            _fieldValue(item.penyulang),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _fieldPair('Section awal', item.sectionAwal)),
                const SizedBox(width: 12),
                Expanded(child: _fieldPair('Section akhir', item.sectionAkhir)),
              ],
            ),
            const SizedBox(height: 14),
            _fieldLabel('Section pekerjaan'),
            _fieldValue(item.section),
          ],
        ),
      );

  Widget _coordinateSection() => _surface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _coordinateRow(
              title: 'Titik awal pekerjaan',
              fix: _awal,
              loading: _gettingAwal,
              start: true,
              accuracy: _awalSearchAccuracy,
            ),
            const Divider(height: 1),
            _coordinateRow(
              title: 'Titik akhir pekerjaan',
              fix: _akhir,
              loading: _gettingAkhir,
              start: false,
              accuracy: _akhirSearchAccuracy,
            ),
          ],
        ),
      );

  Widget _coordinateRow({
    required String title,
    required LocationFix? fix,
    required bool loading,
    required bool start,
    required double? accuracy,
  }) {
    final locked = !start && _awal == null;
    final detail = loading
        ? accuracy == null
            ? 'Menunggu sampel GPS...'
            : 'Akurasi terbaik ${accuracy.toStringAsFixed(1)} m'
        : fix == null
            ? locked
                ? 'Ambil titik awal terlebih dahulu'
                : 'Belum direkam'
            : 'Akurasi ${fix.accuracyLabel}';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: locked ? .55 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: navy, fontWeight: FontWeight.w900),
                  ),
                ),
                if (_readOnly || locked)
                  const Icon(Icons.lock_rounded, size: 17, color: muted),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fix?.coordinate ?? '-',
              style: const TextStyle(color: ocean, fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              style: TextStyle(
                color: fix?.locked == true ? const Color(0xFF047857) : muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!_readOnly) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: loading || _saving || locked ? null : () => _getCoordinate(start),
                  icon: loading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(loading ? 'Mencari titik...' : 'Ambil koordinat perangkat'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _findingsSection(WoInsjar item) => _surface(
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 390,
          child: TemuanTab(
            key: ValueKey('temuan-${item.kodeWo}'),
            wo: item,
            sesi: widget.sesi,
            canAddTemuan: _awal != null,
          ),
        ),
      );

  Widget _summarySection() => _surface(
        child: Column(
          children: [
            _summaryRow('Realisasi kmS', '${_kms.toStringAsFixed(3)} km'),
            const Divider(height: 22),
            _summaryRow('Waktu mulai', _mulai == null ? '-' : WoInsjar.stampLengkap(_mulai!)),
            const Divider(height: 22),
            _summaryRow('Waktu selesai', _selesai == null ? '-' : WoInsjar.stampLengkap(_selesai!)),
            const Divider(height: 22),
            _summaryRow('Durasi pekerjaan', _duration),
            const Divider(height: 22),
            _summaryRow('Status WO', _status),
            if (_readOnly) ...[
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 17, color: Color(0xFF047857)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WO selesai. Data hanya dapat dilihat.',
                      style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800)),
      );

  Widget _fieldValue(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(value.isEmpty ? '-' : value, style: const TextStyle(color: navy, fontWeight: FontWeight.w700)),
      );

  Widget _fieldPair(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_fieldLabel(label), _fieldValue(value)],
      );

  Widget _summaryRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
}
