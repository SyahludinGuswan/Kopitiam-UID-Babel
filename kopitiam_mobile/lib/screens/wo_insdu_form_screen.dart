import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/wo_insdu.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
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
  static const ocean = Color(0xFF0A3E74);
  static const navy = Color(0xFF071B30);
  static const gold = Color(0xFFFFAE00);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const page = Color(0xFFF4F7FB);

  static const coverOptions = ['Lengkap', 'Tidak Lengkap', 'Rusak', 'Tidak ada'];
  static const jumperOptions = [
    'A3C',
    'A3CS (Lengkap)',
    'A3CS (Tidak Lengkap)',
    'Protective Sleeve (Lengkap)',
    'Protective Sleeve (Tidak Lengkap)',
  ];

  static const wbpLoad = <String, String>{
    'bebanUtamaRWbp': 'R (A)',
    'bebanUtamaSWbp': 'S (A)',
    'bebanUtamaTWbp': 'T (A)',
    'bebanJurusanNWbp': 'N (A)',
  };
  static const wbpVoltage = <String, String>{
    'teganganRswbp': 'R-S (V)',
    'teganganStwbp': 'S-T (V)',
    'teganganRtwbp': 'R-T (V)',
    'teganganRnwbp': 'R-N (V)',
    'teganganSnwbp': 'S-N (V)',
    'teganganTnwbp': 'T-N (V)',
  };
  static const lwbpLoad = <String, String>{
    'bebanUtamaRLwbp': 'R (A)',
    'bebanUtamaSLwbp': 'S (A)',
    'bebanUtamaTLwbp': 'T (A)',
    'bebanJurusanNLwbp': 'N (A)',
  };
  static const lwbpVoltage = <String, String>{
    'teganganRslwbp': 'R-S (V)',
    'teganganStlwbp': 'S-T (V)',
    'teganganRtlwbp': 'R-T (V)',
    'teganganRnlwbp': 'R-N (V)',
    'teganganSnlwbp': 'S-N (V)',
    'teganganTnlwbp': 'T-N (V)',
  };
  static const conditionLabels = <String, String>{
    'coverFcoAtas': 'Cover FCO Atas',
    'coverFcoBawah': 'Cover FCO Bawah',
    'coverBushingTm': 'Cover Bushing TM',
    'coverBushingTr': 'Cover Bushing TR',
    'coverArrester': 'Cover Arrester',
    'jumperanAtas': 'Jumperan Atas',
    'jumperanBawah': 'Jumperan Bawah',
  };

  final _repo = WoInsduRepository();
  final Map<String, TextEditingController> _fields = {};
  bool _saving = false;
  bool _finish = false;
  bool _gettingWbp = false;
  bool _gettingLwbp = false;
  double? _wbpSearchAccuracy;
  double? _lwbpSearchAccuracy;
  LocationFix? _wbpFix;
  LocationFix? _lwbpFix;
  double? _wbpDistance;
  double? _lwbpDistance;

  WoInsdu get wo => widget.existing;
  bool get readOnly => WoInsdu.normalisasiStatus(wo.statusWo) == WoInsdu.statusSelesai;
  Iterable<String> get _numericKeys => [...wbpLoad.keys, ...wbpVoltage.keys, ...lwbpLoad.keys, ...lwbpVoltage.keys];

  @override
  void initState() {
    super.initState();
    final values = <String, Object?>{
      'jurusanTerpasang': wo.jurusanTerpasang,
      'jurusanTerpakai': wo.jurusanTerpakai,
      'bebanUtamaRWbp': wo.bebanUtamaRWbp,
      'bebanUtamaSWbp': wo.bebanUtamaSWbp,
      'bebanUtamaTWbp': wo.bebanUtamaTWbp,
      'bebanJurusanNWbp': wo.bebanJurusanNWbp,
      'teganganRswbp': wo.teganganRswbp,
      'teganganStwbp': wo.teganganStwbp,
      'teganganRtwbp': wo.teganganRtwbp,
      'teganganRnwbp': wo.teganganRnwbp,
      'teganganSnwbp': wo.teganganSnwbp,
      'teganganTnwbp': wo.teganganTnwbp,
      'bebanUtamaRLwbp': wo.bebanUtamaRLwbp,
      'bebanUtamaSLwbp': wo.bebanUtamaSLwbp,
      'bebanUtamaTLwbp': wo.bebanUtamaTLwbp,
      'bebanJurusanNLwbp': wo.bebanJurusanNLwbp,
      'teganganRslwbp': wo.teganganRslwbp,
      'teganganStlwbp': wo.teganganStlwbp,
      'teganganRtlwbp': wo.teganganRtlwbp,
      'teganganRnlwbp': wo.teganganRnlwbp,
      'teganganSnlwbp': wo.teganganSnlwbp,
      'teganganTnlwbp': wo.teganganTnlwbp,
      'coverFcoAtas': wo.coverFcoAtas,
      'coverFcoBawah': wo.coverFcoBawah,
      'coverBushingTm': wo.coverBushingTm,
      'coverBushingTr': wo.coverBushingTr,
      'coverArrester': wo.coverArrester,
      'jumperanAtas': wo.jumperanAtas,
      'jumperanBawah': wo.jumperanBawah,
    };
    for (final entry in values.entries) {
      final raw = entry.value == null ? '' : '${entry.value}';
      _fields[entry.key] = TextEditingController(
        text: _numericKeys.contains(entry.key) ? raw.replaceAll('.', ',') : raw,
      );
    }
    _wbpFix = _parseFix(wo.koordinatPenginputanWbp);
    _lwbpFix = _parseFix(wo.koordinatPenginputanLwbp);
    _wbpDistance = wo.jarakGarduPetugasWbp;
    _lwbpDistance = wo.jarakGarduPetugasLwbp;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  LocationFix? _parseFix(String value) {
    final parts = value.split(',');
    if (parts.length < 2) return null;
    final latitude = double.tryParse(parts[0].trim());
    final longitude = double.tryParse(parts[1].trim());
    if (latitude == null || longitude == null) return null;
    return LocationFix(
      latitude: latitude,
      longitude: longitude,
      accuracy: 5,
      capturedAt: DateTime.now(),
      samples: 1,
      locked: true,
    );
  }

  List<double>? get _garduCoordinate {
    final source = wo.koordinatGardu.trim().isNotEmpty
        ? wo.koordinatGardu
        : '${wo.lat},${wo.long}';
    final parts = source.split(',');
    if (parts.length < 2) return null;
    final latitude = double.tryParse(parts[0].trim());
    final longitude = double.tryParse(parts[1].trim());
    return latitude == null || longitude == null ? null : [latitude, longitude];
  }

  String? _decimalError(String key) {
    final value = _fields[key]!.text.trim();
    if (value.isEmpty) return null;
    if (value.contains('.')) return 'Gunakan (,) sebagai pemisah';
    return RegExp(r'^\d+(,\d+)?$').hasMatch(value) ? null : 'Masukkan angka yang valid';
  }

  bool get _hasDecimalError => _numericKeys.any((key) => _decimalError(key) != null);
  double? _number(String key) {
    final value = _fields[key]!.text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : double.tryParse(value);
  }
  int? _integer(String key) => int.tryParse(_fields[key]!.text.trim());
  String _text(String key) => _fields[key]!.text.trim();

  Future<void> _captureIfNeeded(bool wbp) async {
    if (readOnly || _saving) return;
    if (wbp ? _wbpFix != null || _gettingWbp : _lwbpFix != null || _gettingLwbp) return;
    setState(() {
      if (wbp) {
        _gettingWbp = true;
        _wbpSearchAccuracy = null;
      } else {
        _gettingLwbp = true;
        _lwbpSearchAccuracy = null;
      }
    });
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, accuracy) {
          if (!mounted) return;
          setState(() {
            if (wbp) {
              _wbpSearchAccuracy = accuracy;
            } else {
              _lwbpSearchAccuracy = accuracy;
            }
          });
        },
      );
      if (!mounted) return;
      final gardu = _garduCoordinate;
      final distance = gardu == null
          ? null
          : Geolocator.distanceBetween(
              gardu[0],
              gardu[1],
              fix.latitude,
              fix.longitude,
            );
      setState(() {
        if (wbp) {
          _wbpFix = fix;
          _wbpDistance = distance;
        } else {
          _lwbpFix = fix;
          _lwbpDistance = distance;
        }
      });
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          if (wbp) {
            _gettingWbp = false;
          } else {
            _gettingLwbp = false;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || readOnly) return;
    if (_hasDecimalError) {
      setState(() {});
      _message('Perbaiki kolom merah. Gunakan (,) sebagai pemisah.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final start = WoInsjar.parseStamp(wo.waktuMulai) ?? now;
      final saved = WoInsdu(
        id: wo.id,
        no: wo.no,
        kodeWo: wo.kodeWo,
        kodeUiw: wo.kodeUiw,
        kodeUp3: wo.kodeUp3,
        kodeUlp: wo.kodeUlp,
        ulp: wo.ulp,
        hari: wo.hari,
        tanggal: wo.tanggal,
        penyulang: wo.penyulang,
        section: wo.section,
        nomorGardu: wo.nomorGardu,
        koordinatGardu: wo.koordinatGardu,
        lat: wo.lat,
        long: wo.long,
        jurusan: wo.jurusan,
        jurusanTerpasang: _integer('jurusanTerpasang'),
        jurusanTerpakai: _integer('jurusanTerpakai'),
        bebanUtamaRWbp: _number('bebanUtamaRWbp'),
        bebanUtamaSWbp: _number('bebanUtamaSWbp'),
        bebanUtamaTWbp: _number('bebanUtamaTWbp'),
        bebanJurusanNWbp: _number('bebanJurusanNWbp'),
        teganganRswbp: _number('teganganRswbp'),
        teganganStwbp: _number('teganganStwbp'),
        teganganRtwbp: _number('teganganRtwbp'),
        teganganRnwbp: _number('teganganRnwbp'),
        teganganSnwbp: _number('teganganSnwbp'),
        teganganTnwbp: _number('teganganTnwbp'),
        bebanUtamaRLwbp: _number('bebanUtamaRLwbp'),
        bebanUtamaSLwbp: _number('bebanUtamaSLwbp'),
        bebanUtamaTLwbp: _number('bebanUtamaTLwbp'),
        bebanJurusanNLwbp: _number('bebanJurusanNLwbp'),
        teganganRslwbp: _number('teganganRslwbp'),
        teganganStlwbp: _number('teganganStlwbp'),
        teganganRtlwbp: _number('teganganRtlwbp'),
        teganganRnlwbp: _number('teganganRnlwbp'),
        teganganSnlwbp: _number('teganganSnlwbp'),
        teganganTnlwbp: _number('teganganTnlwbp'),
        koordinatPenginputanWbp: _wbpFix?.coordinate ?? wo.koordinatPenginputanWbp,
        jarakGarduPetugasWbp: _wbpDistance,
        koordinatPenginputanLwbp: _lwbpFix?.coordinate ?? wo.koordinatPenginputanLwbp,
        jarakGarduPetugasLwbp: _lwbpDistance,
        coverFcoAtas: _text('coverFcoAtas'),
        coverFcoBawah: _text('coverFcoBawah'),
        coverBushingTm: _text('coverBushingTm'),
        coverBushingTr: _text('coverBushingTr'),
        coverArrester: _text('coverArrester'),
        jumperanAtas: _text('jumperanAtas'),
        jumperanBawah: _text('jumperanBawah'),
        waktuMulai: wo.waktuMulai.isEmpty ? WoInsjar.stampLengkap(start) : wo.waktuMulai,
        waktuSelesai: _finish ? WoInsjar.stampLengkap(now) : wo.waktuSelesai,
        durasiPekerjaan: _finish ? WoInsjar.hitungDurasi(start, now) : wo.durasiPekerjaan,
        statusWo: _finish ? WoInsdu.statusSelesai : WoInsdu.statusDalam,
        isDirty: _finish,
      );
      await _repo.simpan(saved, dirty: _finish);
      if (mounted) Navigator.pop(context, true);
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

  WoInsjar get _findingWo => WoInsjar(
        kodeWo: wo.kodeWo,
        kodeUiw: wo.kodeUiw,
        kodeUp3: wo.kodeUp3,
        kodeUlp: wo.kodeUlp,
        ulp: wo.ulp,
        hari: wo.hari,
        tanggal: wo.tanggal,
        penyulang: wo.penyulang,
        section: wo.section,
        statusWo: WoInsjar.statusDalam,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: page,
        appBar: AppBar(
          backgroundColor: ocean,
          foregroundColor: Colors.white,
          title: const Text('Inspeksi Gardu', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Column(
          children: [
            _hero(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _identityCard(),
                  const SizedBox(height: 16),
                  _measurementCard('02', 'Pengukuran WBP', true),
                  const SizedBox(height: 16),
                  _measurementCard('03', 'Pengukuran LWBP', false),
                  const SizedBox(height: 16),
                  _conditionCard(),
                  const SizedBox(height: 16),
                  _findingsCard(),
                  const SizedBox(height: 16),
                  _summaryCard(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: readOnly
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () { _finish = false; _save(); },
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        child: const Text('Simpan Progress'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : () { _finish = true; _save(); },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: gold,
                          foregroundColor: navy,
                        ),
                        child: Text(_saving ? 'Menyimpan...' : 'Selesaikan WO', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
      );

  Widget _hero() => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: ocean, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NOMOR GARDU', style: TextStyle(color: Color(0xFFB8DCEF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 7),
            Text(wo.nomorGardu.isEmpty ? '-' : wo.nomorGardu, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(wo.kodeWo, style: const TextStyle(color: Color(0xFFD5E8F3), fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _identityCard() => _card(
        '01',
        'Identitas Gardu',
        Column(
          children: [
            _readonlyField('Kode WO', wo.kodeWo),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _readonlyField('ULP', wo.ulp)), const SizedBox(width: 12), Expanded(child: _readonlyField('Tanggal', '${wo.hari}, ${wo.tanggal}'))]),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _readonlyField('Penyulang', wo.penyulang)), const SizedBox(width: 12), Expanded(child: _readonlyField('Section', wo.section))]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _integerField('jurusanTerpasang', 'Jurusan Terpasang')),
                const SizedBox(width: 12),
                Expanded(child: _integerField('jurusanTerpakai', 'Jurusan Terpakai')),
              ],
            ),
          ],
        ),
      );

  Widget _measurementCard(String number, String title, bool wbp) {
    final loading = wbp ? _gettingWbp : _gettingLwbp;
    final fix = wbp ? _wbpFix : _lwbpFix;
    final accuracy = wbp ? _wbpSearchAccuracy : _lwbpSearchAccuracy;
    final distance = wbp ? _wbpDistance : _lwbpDistance;
    return _card(
      number,
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _groupTitle('Beban Utama'),
          _numericGrid(wbp ? wbpLoad : lwbpLoad, wbp),
          const SizedBox(height: 18),
          _groupTitle('Tegangan'),
          _numericGrid(wbp ? wbpVoltage : lwbpVoltage, wbp),
          const SizedBox(height: 18),
          _coordinatePanel(fix: fix, loading: loading, accuracy: accuracy, distance: distance),
        ],
      ),
    );
  }

  Widget _coordinatePanel({required LocationFix? fix, required bool loading, required double? accuracy, required double? distance}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(13), border: Border.all(color: line)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: const Color(0xFFE8F1FA), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.gps_fixed_rounded, size: 17, color: ocean),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Koordinat Pengisian', style: TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    loading
                        ? accuracy == null ? 'Mencari koordinat...' : 'Akurasi terbaik ${accuracy.toStringAsFixed(1)} m'
                        : fix?.coordinate ?? 'Tersimpan otomatis saat kolom pengukuran dibuka',
                    style: const TextStyle(color: muted, fontSize: 11.5),
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 5),
                    Text('Jarak ke Gardu ${distance.toStringAsFixed(1)} m', style: const TextStyle(color: ocean, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ],
              ),
            ),
            if (fix != null) const Icon(Icons.lock_rounded, size: 16, color: muted),
          ],
        ),
      );

  Widget _conditionCard() => _card(
        '04',
        'Kondisi Cover & Jumperan',
        Column(
          children: conditionLabels.entries.map((entry) {
            final options = entry.key.startsWith('jumperan') ? jumperOptions : coverOptions;
            final current = _text(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                key: ValueKey('condition-${entry.key}-$current'),
                isExpanded: true,
                initialValue: options.contains(current) ? current : null,
                hint: const Text('Pilih kondisi'),
                items: options.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: readOnly ? null : (value) => setState(() => _fields[entry.key]!.text = value ?? ''),
                decoration: _decoration(entry.value),
              ),
            );
          }).toList(),
        ),
      );

  Widget _findingsCard() => _card(
        '05',
        'Temuan Inspeksi',
        SizedBox(
          height: 390,
          child: TemuanTab(
            key: ValueKey('temuan-${wo.kodeWo}'),
            wo: _findingWo,
            sesi: widget.sesi,
            canAddTemuan: !readOnly,
          ),
        ),
        padding: EdgeInsets.zero,
      );

  Widget _summaryCard() => _card(
        '06',
        'Ringkasan Pekerjaan',
        Column(
          children: [
            _summaryRow('Status WO', WoInsdu.normalisasiStatus(wo.statusWo)),
            const Divider(height: 22),
            _summaryRow('Waktu mulai', wo.waktuMulai),
            const Divider(height: 22),
            _summaryRow('Waktu selesai', wo.waktuSelesai),
            const Divider(height: 22),
            _summaryRow('Durasi pekerjaan', wo.durasiPekerjaan),
            const Divider(height: 22),
            _summaryRow('Koordinat WBP', _wbpFix?.coordinate ?? '-'),
            const Divider(height: 22),
            _summaryRow('Jarak WBP', _wbpDistance == null ? '-' : '${_wbpDistance!.toStringAsFixed(1)} m'),
            const Divider(height: 22),
            _summaryRow('Koordinat LWBP', _lwbpFix?.coordinate ?? '-'),
            const Divider(height: 22),
            _summaryRow('Jarak LWBP', _lwbpDistance == null ? '-' : '${_lwbpDistance!.toStringAsFixed(1)} m'),
          ],
        ),
      );

  Widget _card(String number, String title, Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: padding == EdgeInsets.zero ? const EdgeInsets.all(16) : EdgeInsets.zero,
              child: Row(
                children: [
                  Text(number, style: const TextStyle(color: ocean, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      );

  Widget _readonlyField(String label, String value) => InputDecorator(
        decoration: _decoration(label),
        child: Text(value.trim().isEmpty ? '-' : value, style: const TextStyle(color: navy, fontWeight: FontWeight.w700)),
      );

  Widget _integerField(String key, String label) => TextField(
        controller: _fields[key],
        enabled: !readOnly,
        keyboardType: TextInputType.number,
        decoration: _decoration(label),
      );

  Widget _numericGrid(Map<String, String> entries, bool wbp) => LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entries.entries.map((entry) => SizedBox(
              width: width,
              child: TextField(
                controller: _fields[entry.key],
                enabled: !readOnly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () => _captureIfNeeded(wbp),
                onChanged: (_) => setState(() {}),
                decoration: _decoration(entry.value).copyWith(errorText: _decimalError(entry.key)),
              ),
            )).toList(),
          );
        },
      );

  Widget _groupTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: const TextStyle(color: ocean, fontSize: 13, fontWeight: FontWeight.w900)),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
      );

  Widget _summaryRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: muted, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(value.trim().isEmpty ? '-' : value, textAlign: TextAlign.right, style: const TextStyle(color: navy, fontSize: 12.5, fontWeight: FontWeight.w900))),
        ],
      );
}
