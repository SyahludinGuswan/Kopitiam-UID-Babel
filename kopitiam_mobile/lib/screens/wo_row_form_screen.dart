import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../models/wo_row.dart';
import '../services/photo_watermark_service.dart';
import '../services/wo_row_repository.dart';
import 'landscape_camera_screen.dart';

class WoRowFormScreen extends StatefulWidget {
  final WoRow existing;
  final Map<String, dynamic> sesi;

  const WoRowFormScreen({
    super.key,
    required this.existing,
    required this.sesi,
  });

  @override
  State<WoRowFormScreen> createState() => _WoRowFormScreenState();
}

class _WoRowFormScreenState extends State<WoRowFormScreen> {
  static const blue = Color(0xFF0A3E74);
  static const blueMid = Color(0xFF075B96);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFAE00);
  static const paleGold = Color(0xFFFFF4C7);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const green = Color(0xFF16A34A);

  final _repo = WoRowRepository();
  final _diameterCtrl = TextEditingController();

  late String _status;
  String? _tindakLanjut;
  String _fotoSesudah = '';
  DateTime? _waktuMulai;
  bool _saving = false;
  bool _takingPhoto = false;

  WoRow get _row => widget.existing;
  bool get _readOnly => _status == WoRow.statusSelesai;
  bool get _editable =>
      !_readOnly &&
      WoRow.normalisasiStatus(_status) == WoRow.statusProgress;
  bool get _isTebang => _tindakLanjut == 'Tebang';

  int? get _diameterValue =>
      double.tryParse(_diameterCtrl.text.replaceAll(',', '.'))?.round();

  String get _jenisPekerjaan {
    if (_isTebang) return WoRow.jenisTebanganDariDiameter(_diameterValue);
    return (_tindakLanjut ?? '').trim();
  }

  @override
  void initState() {
    super.initState();
    _status = WoRow.normalisasiStatus(_row.statusWo);
    _tindakLanjut = _row.tindakLanjut.isEmpty ? null : _row.tindakLanjut;
    _fotoSesudah = _row.fotoSesudah;
    if (_row.ukuranDiameterBatang != null) {
      _diameterCtrl.text = '${_row.ukuranDiameterBatang}';
    }
  }

  @override
  void dispose() {
    _diameterCtrl.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    if (_readOnly || _saving) return;
    await _repo.mulaiPekerjaan(_row.kodeWo);
    if (!mounted) return;
    setState(() {
      _status = WoRow.statusProgress;
      _waktuMulai ??= DateTime.now();
    });
  }

  void _lihatFoto() {
    if (_fotoSesudah.isEmpty || !File(_fotoSesudah).existsSync()) return;
    showDialog<void>(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: .9),
          child: Stack(fit: StackFit.expand, children: [
            InteractiveViewer(
              minScale: .5,
              maxScale: 4,
              child: Center(
                child: Image.file(File(_fotoSesudah), fit: BoxFit.contain),
              ),
            ),
            const Positioned(
              top: 48,
              right: 16,
              child: Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ]),
        ),
      ),
    );
  }

  void _onFotoTap() {
    final hasPhoto =
        _fotoSesudah.isNotEmpty && File(_fotoSesudah).existsSync();
    if (!hasPhoto) {
      if (_editable && !_takingPhoto) _ambilFoto();
      return;
    }
    if (!_editable) return _lihatFoto();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Foto Sesudah'),
        content: const Text(
          'Foto telah tersimpan. Verifikasi apakah foto sudah sesuai.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _lihatFoto();
            },
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('Lihat Hasil Foto'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _ambilFoto();
            },
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Ambil Ulang Foto'),
          ),
        ],
      ),
    );
  }

  Future<void> _ambilFoto() async {
    if (!_editable || _takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final value = await LandscapeCameraScreen.capture(
        context,
        title: 'Foto Sesudah',
      );
      if (value == null || value.isEmpty) return;
      final now = DateTime.now();
      final item = TemuanInspeksi(
        kodeTemuan: _row.kodeTemuan,
        kodeWo: _row.kodeWo,
        temuan: _row.temuan,
        jenisObject: _row.jenisObject,
        koordinat: _row.koordinat,
        ulp: _row.ulp,
        penyulang: _row.penyulang,
        section: _row.section,
        segmen: _row.segmen,
        hari: _row.hari.isEmpty
            ? WoInsjar.hariIndonesia[now.weekday - 1]
            : _row.hari,
        tanggal: _row.tanggal.isEmpty
            ? WoInsjar.formatTanggal(now)
            : _row.tanggal,
        waktuInput: _row.waktuInput.isEmpty
            ? WoInsjar.stampLengkap(now)
            : _row.waktuInput,
      );
      final watermarked = await PhotoWatermarkService.render(
        sourcePath: value,
        item: item,
        photoLabel: 'Foto Sesudah',
      );
      if (mounted) setState(() => _fotoSesudah = watermarked);
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _simpanRealisasi() async {
    if (_saving) return;
    if (_tindakLanjut == null || _tindakLanjut!.isEmpty) {
      return _message('Pilih Tindak Lanjut terlebih dahulu.');
    }
    if (_isTebang && _diameterValue == null) {
      return _message('Isi Ukuran Diameter Batang (cm) bernilai angka.');
    }
    if (_fotoSesudah.isEmpty) {
      return _message('Foto Sesudah wajib diambil.');
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await _repo.simpan(_row.copyWith(
        tindakLanjut: _tindakLanjut,
        ukuranDiameterBatang: _isTebang ? _diameterValue : null,
        jenisTebangan: _jenisPekerjaan,
        fotoSesudah: _fotoSesudah,
        statusWo: WoRow.statusSelesai,
        userInput: '${widget.sesi['username'] ?? ''}',
        waktuInput: _waktuMulai != null
            ? WoInsjar.stampLengkap(_waktuMulai!)
            : _row.waktuInput.isNotEmpty
                ? _row.waktuInput
                : WoInsjar.stampLengkap(now),
        waktuRealisasi: WoInsjar.stampLengkap(now),
        isDirty: true,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _message(
          error.toString().replaceFirst('StateError: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _bukaMaps() {
    final coordinate = _row.koordinat.trim();
    if (coordinate.isEmpty) {
      return _message('Koordinat temuan belum tersedia.');
    }
    launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${Uri.encodeComponent(coordinate)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFDC2626) : green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: const Text(
            'Tindak Lanjut ROW',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          backgroundColor: navy,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            _hero(),
            const SizedBox(height: 18),
            _section('01', 'WO', _woBody()),
            const SizedBox(height: 18),
            _section('02', 'Pekerjaan', _workBody()),
            const SizedBox(height: 18),
            _section('03', 'Eviden Sesudah', _evidenceBody()),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _readOnly || _saving ? null : _simpanRealisasi,
              style: FilledButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _saving
                    ? 'Menyimpan...'
                    : _readOnly
                        ? 'ROW Selesai'
                        : 'Simpan Realisasi',
              ),
            ),
          ),
        ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [blueMid, blue, navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26004D8C),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(
              Icons.assignment_turned_in_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'WORK ORDER ROW',
                style: TextStyle(
                  color: Color(0xFFD7EAF5),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            _statusChip(),
          ]),
          const SizedBox(height: 14),
          Text(
            _row.kodeWo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            _row.kodeTemuan,
            style: const TextStyle(color: Color(0xFFD7EAF5), fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0x44FFFFFF), height: 1),
          const SizedBox(height: 11),
          Text(
            '${_row.ulp} • ${_row.kodeUlp}',
            style: const TextStyle(color: Color(0xFFD7EAF5), fontSize: 12),
          ),
          if (!_readOnly && _status == WoRow.statusPenugasan) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _mulai,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Mulai Pekerjaan'),
              ),
            ),
          ],
        ]),
      );

  Widget _statusChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          _status,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _section(String number, String title, Widget child) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10071B30),
              blurRadius: 20,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: navy,
              border: Border(top: BorderSide(color: amber, width: 3)),
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: paleGold,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Color(0xFF765400),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ]),
      );

  Widget _woBody() => Column(children: [
        _pair('Tanggal', _row.tanggal, 'Penyulang', _row.penyulang),
        const SizedBox(height: 11),
        _pair('Section', _row.section, 'Segmen', _row.segmen),
        const SizedBox(height: 11),
        _pair('Jenis Object', _row.jenisObject, 'Tier', _row.tier),
        const SizedBox(height: 11),
        _pair('Prioritas', _row.prioritas, 'Jenis Pohon', _row.jenisPohon),
        if (_row.jarak != null || _row.tinggiPohon != null) ...[
          const SizedBox(height: 11),
          _pair(
            'Jarak Jaringan',
            _row.jarak == null ? '-' : '${_row.jarak} m',
            'Tinggi Pohon',
            _row.tinggiPohon == null ? '-' : '${_row.tinggiPohon} m',
          ),
        ],
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: paleGold,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _datum('Temuan', _row.temuan),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _bukaMaps,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(children: [
              const Icon(Icons.map_rounded, color: blue, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _row.koordinat.isEmpty
                      ? 'Koordinat belum tersedia'
                      : _row.koordinat,
                  style: const TextStyle(
                    color: blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: blue, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _sourcePhoto('Foto Temuan', _row.fotoTemuan, _row.linkFoto)),
          const SizedBox(width: 10),
          Expanded(child: _sourcePhoto('Foto Sekitar', _row.fotoLingkungan, _row.linkLingkungan)),
        ]),
      ]);

  Widget _pair(String leftLabel, String left, String rightLabel, String right) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _datum(leftLabel, left)),
        const SizedBox(width: 12),
        Expanded(child: _datum(rightLabel, right)),
      ]);

  Widget _datum(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      );

  Widget _sourcePhoto(String label, String local, String remote) {
    final available = local.trim().isNotEmpty || remote.trim().isNotEmpty;
    return Container(
      height: 82,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8CBD3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.image_outlined, color: blue),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        Text(
          available ? 'Tersedia' : 'Belum tersedia',
          style: const TextStyle(fontSize: 10, color: muted),
        ),
      ]),
    );
  }

  Widget _workBody() => Column(children: [
        DropdownButtonFormField<String>(
          value: WoRow.tindakLanjutOptions.contains(_tindakLanjut)
              ? _tindakLanjut
              : null,
          hint: const Text('--Pilih Tindak Lanjut--'),
          items: WoRow.tindakLanjutOptions
              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: _editable
              ? (value) => setState(() => _tindakLanjut = value)
              : null,
          decoration: _inputDecoration('Tindak Lanjut *'),
        ),
        if (_isTebang) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _diameterCtrl,
            enabled: _editable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('Ukuran Diameter Batang (cm) *'),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: paleGold,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Text('Jenis Pekerjaan', style: TextStyle(fontSize: 12, color: muted)),
            const Spacer(),
            Text(
              _jenisPekerjaan.isEmpty ? '-' : _jenisPekerjaan,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ]);

  Widget _evidenceBody() {
    final exists = _fotoSesudah.isNotEmpty && File(_fotoSesudah).existsSync();
    return GestureDetector(
      onTap: _onFotoTap,
      child: Container(
        height: 170,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: exists ? blue : const Color(0xFF9CB9C4)),
        ),
        child: exists
            ? Image.file(File(_fotoSesudah), width: double.infinity, fit: BoxFit.cover)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.camera_alt_outlined, size: 34, color: blue),
                const SizedBox(height: 8),
                Text(
                  _takingPhoto ? 'Membuka kamera...' : 'Ambil Foto Sesudah',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gunakan orientasi lanskap',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ]),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      );
}
