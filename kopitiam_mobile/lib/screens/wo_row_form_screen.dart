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
  const WoRowFormScreen({super.key, required this.existing, required this.sesi});

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
  final _diameter = TextEditingController();
  late String _status;
  String? _followUp;
  String _afterPhoto = '';
  bool _saving = false;
  bool _takingPhoto = false;

  WoRow get row => widget.existing;
  bool get finished => _status == WoRow.statusSelesai;
  bool get editable => _status == WoRow.statusProgress;
  bool get cutting => _followUp == 'Tebang';
  int? get diameter => double.tryParse(_diameter.text.replaceAll(',', '.'))?.round();
  String get workType => cutting
      ? WoRow.jenisTebanganDariDiameter(diameter)
      : (_followUp ?? '').trim();

  @override
  void initState() {
    super.initState();
    _status = WoRow.normalisasiStatus(row.statusWo);
    _followUp = row.tindakLanjut.isEmpty ? null : row.tindakLanjut;
    _afterPhoto = row.fotoSesudah;
    if (row.ukuranDiameterBatang != null) {
      _diameter.text = '${row.ukuranDiameterBatang}';
    }
  }

  @override
  void dispose() {
    _diameter.dispose();
    super.dispose();
  }

  void message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? const Color(0xFFDC2626) : green,
    ));
  }

  Future<void> takePhoto() async {
    if (!editable || _takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final path = await LandscapeCameraScreen.capture(context, title: 'Foto Sesudah');
      if (path == null || path.isEmpty) return;
      final now = DateTime.now();
      final watermarked = await PhotoWatermarkService.render(
        sourcePath: path,
        item: TemuanInspeksi(
          kodeTemuan: row.kodeTemuan,
          kodeWo: row.kodeWo,
          temuan: row.temuan,
          jenisObject: row.jenisObject,
          koordinat: row.koordinat,
          ulp: row.ulp,
          penyulang: row.penyulang,
          section: row.section,
          segmen: row.segmen,
          hari: row.hari.isEmpty ? WoInsjar.hariIndonesia[now.weekday - 1] : row.hari,
          tanggal: row.tanggal.isEmpty ? WoInsjar.formatTanggal(now) : row.tanggal,
          waktuInput: row.waktuInput.isEmpty ? WoInsjar.stampLengkap(now) : row.waktuInput,
        ),
        photoLabel: 'Foto Sesudah',
      );
      if (mounted) setState(() => _afterPhoto = watermarked);
    } catch (error) {
      if (mounted) message('$error', error: true);
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> save() async {
    if (!editable || _saving) return;
    if (_followUp == null || _followUp!.isEmpty) {
      return message('Pilih Tindak Lanjut terlebih dahulu.');
    }
    if (cutting && diameter == null) {
      return message('Isi Ukuran Diameter Batang (cm) bernilai angka.');
    }
    if (_afterPhoto.isEmpty) return message('Foto Sesudah wajib diambil.');
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await _repo.simpan(row.copyWith(
        tindakLanjut: _followUp,
        ukuranDiameterBatang: cutting ? diameter : null,
        jenisTebangan: workType,
        fotoSesudah: _afterPhoto,
        statusWo: WoRow.statusSelesai,
        userInput: '${widget.sesi['username'] ?? ''}',
        waktuInput: row.waktuInput.isEmpty ? WoInsjar.stampLengkap(now) : row.waktuInput,
        waktuRealisasi: WoInsjar.stampLengkap(now),
        isDirty: true,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) message('$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void openMaps() {
    if (row.koordinat.trim().isEmpty) return message('Koordinat temuan belum tersedia.');
    launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(row.koordinat.trim())}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: const Text('Tindak Lanjut ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          backgroundColor: navy,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            hero(),
            const SizedBox(height: 18),
            section('01', 'WO', woBody()),
            const SizedBox(height: 18),
            section('02', 'Pekerjaan', workBody()),
            const SizedBox(height: 18),
            section('03', 'Eviden Sesudah', evidenceBody()),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: editable && !_saving ? save : null,
              style: FilledButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white),
              child: Text(_saving
                  ? 'Menyimpan...'
                  : finished
                      ? 'ROW Selesai'
                      : editable
                          ? 'Simpan Realisasi'
                          : 'Menunggu pekerjaan dimulai'),
            ),
          ),
        ),
      );

  Widget hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [blueMid, blue, navy], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x26004D8C), blurRadius: 22, offset: Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('WORK ORDER ROW', style: TextStyle(color: Color(0xFFD7EAF5), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
            statusChip(),
          ]),
          const SizedBox(height: 14),
          Text(row.kodeWo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(row.kodeTemuan, style: const TextStyle(color: Color(0xFFD7EAF5), fontSize: 13)),
          const SizedBox(height: 12),
          const Divider(color: Color(0x44FFFFFF), height: 1),
          const SizedBox(height: 11),
          Text('${row.ulp} • ${row.kodeUlp}', style: const TextStyle(color: Color(0xFFD7EAF5), fontSize: 12)),
        ]),
      );

  Widget statusChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: finished ? green : Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(_status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Widget section(String number, String title, Widget child) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
          boxShadow: const [BoxShadow(color: Color(0x10071B30), blurRadius: 20, offset: Offset(0, 7))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: navy, border: Border(top: BorderSide(color: amber, width: 3))),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: paleGold, shape: BoxShape.circle),
                child: Text(number, style: const TextStyle(color: Color(0xFF765400), fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ]),
      );

  Widget woBody() => Column(children: [
        pair('Tanggal', row.tanggal, 'Penyulang', row.penyulang),
        const SizedBox(height: 11),
        pair('Section', row.section, 'Segmen', row.segmen),
        const SizedBox(height: 11),
        pair('Jenis Object', row.jenisObject, 'Tier', row.tier),
        const SizedBox(height: 11),
        pair('Prioritas', row.prioritas, 'Jenis Pohon', row.jenisPohon),
        if (row.jarak != null || row.tinggiPohon != null) ...[
          const SizedBox(height: 11),
          pair('Jarak Jaringan', row.jarak == null ? '-' : '${row.jarak} m', 'Tinggi Pohon', row.tinggiPohon == null ? '-' : '${row.tinggiPohon} m'),
        ],
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: paleGold, borderRadius: BorderRadius.circular(12)),
          child: datum('Temuan', row.temuan),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: openMaps,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE8F1FA), borderRadius: BorderRadius.circular(11)),
            child: Row(children: [
              const Icon(Icons.map_rounded, color: blue, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text(row.koordinat.isEmpty ? 'Koordinat belum tersedia' : row.koordinat, style: const TextStyle(color: blue, fontSize: 12, fontWeight: FontWeight.w700))),
              const Icon(Icons.arrow_forward_rounded, color: blue, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: sourcePhoto('Foto Temuan', row.fotoTemuan, row.linkFoto)),
          const SizedBox(width: 10),
          Expanded(child: sourcePhoto('Foto Sekitar', row.fotoLingkungan, row.linkLingkungan)),
        ]),
      ]);

  Widget pair(String a, String av, String b, String bv) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: datum(a, av)),
        const SizedBox(width: 12),
        Expanded(child: datum(b, bv)),
      ]);

  Widget datum(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
        const SizedBox(height: 2),
        Text(value.trim().isEmpty ? '-' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]);

  Widget sourcePhoto(String label, String local, String remote) {
    final available = local.trim().isNotEmpty || remote.trim().isNotEmpty;
    return Container(
      height: 82,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFF4F8FA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB8CBD3))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.image_outlined, color: blue),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        Text(available ? 'Tersedia' : 'Belum tersedia', style: const TextStyle(fontSize: 10, color: muted)),
      ]),
    );
  }

  Widget workBody() => Column(children: [
        DropdownButtonFormField<String>(
          value: WoRow.tindakLanjutOptions.contains(_followUp) ? _followUp : null,
          hint: const Text('--Pilih Tindak Lanjut--'),
          items: WoRow.tindakLanjutOptions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
          onChanged: editable ? (value) => setState(() => _followUp = value) : null,
          decoration: inputDecoration('Tindak Lanjut *'),
        ),
        if (cutting) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _diameter,
            enabled: editable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: inputDecoration('Ukuran Diameter Batang (cm) *'),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: paleGold, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Text('Jenis Pekerjaan', style: TextStyle(fontSize: 12, color: muted)),
            const Spacer(),
            Text(workType.isEmpty ? '-' : workType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]);

  Widget evidenceBody() {
    final exists = _afterPhoto.isNotEmpty && File(_afterPhoto).existsSync();
    return GestureDetector(
      onTap: editable ? takePhoto : (exists ? () {} : null),
      child: Container(
        height: 170,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: finished ? const Color(0xFFE6F5EE) : const Color(0xFFF4F8FA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: exists ? blue : const Color(0xFF9CB9C4)),
        ),
        child: exists
            ? Image.file(File(_afterPhoto), width: double.infinity, fit: BoxFit.cover)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(editable ? Icons.camera_alt_outlined : Icons.lock_outline_rounded, size: 34, color: blue),
                const SizedBox(height: 8),
                Text(
                  _takingPhoto
                      ? 'Membuka kamera...'
                      : editable
                          ? 'Ambil Foto Sesudah'
                          : 'Foto belum dapat diambil',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  editable ? 'Gunakan orientasi lanskap' : 'Pekerjaan dimulai dari card WO utama',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ]),
      ),
    );
  }

  InputDecoration inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: blue, width: 1.5)),
      );
}
