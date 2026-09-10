import 'dart:io';

import 'package:flutter/material.dart';

import '../models/temuan_inspeksi.dart';
import '../services/role_provider.dart';
import '../services/temuan_repository.dart';
import 'c4a_route_guard.dart';
import 'temuan_form_screen.dart';

class C4aFindingsHome extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final TemuanRepository? repository;
  const C4aFindingsHome({super.key, required this.sesi, this.repository});
  @override
  State<C4aFindingsHome> createState() => _C4aFindingsHomeState();
}

class _C4aFindingsHomeState extends State<C4aFindingsHome> {
  static const blue = Color(0xFF004D8C);
  static const amber = Color(0xFFFFB800);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const muted = Color(0xFF64748B);
  late final TemuanRepository repo;
  late final C4aSyncService service;
  List<TemuanInspeksi> items = const [];
  bool busy = false;
  String get token => '${widget.sesi['token'] ?? ''}';
  @override
  void initState() { super.initState(); repo = widget.repository ?? TemuanRepository(); service = C4aSyncService(repository: repo, token: token); if (!RoleProvider.hasC4aAccess(widget.sesi)) return; _load(); service.start(onResult: (_) => _load()); }
  @override
  void dispose() { service.dispose(); super.dispose(); }
  Future<void> _load() async { items = await repo.daftarC4a(); if (mounted) setState(() {}); }
  Future<void> _sync() async { if (busy) return; setState(() => busy = true); final result = await repo.sinkronC4a(token); await _load(); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.berhasil} terkirim, ${result.gagal} gagal.'))); setState(() => busy = false); } }
  Future<void> _retry(TemuanInspeksi item) async { setState(() => busy = true); final ok = await repo.kirimUlangC4a(token, item.kodeTemuan); await _load(); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Temuan berhasil dikirim.' : 'Masih gagal, data lokal tetap aman.'))); setState(() => busy = false); } }
  Future<void> _add() async { if (!RoleProvider.hasC4aAccess(widget.sesi)) return; final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TemuanFormScreen.c4a(sesi: widget.sesi, repository: repo))); if (changed == true) { await _load(); await service.flush(onResult: (_) => _load()); } }
  @override
  Widget build(BuildContext context) { if (!RoleProvider.hasC4aAccess(widget.sesi)) return const C4aAccessDeniedScreen(); return Scaffold(appBar: AppBar(backgroundColor: blue, foregroundColor: Colors.white, title: const Text('Temuan C4A'), actions: [TextButton.icon(onPressed: busy ? null : _sync, style: TextButton.styleFrom(foregroundColor: Colors.white), icon: busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload_outlined), label: const Text('Sinkron'))]), body: RefreshIndicator(onRefresh: _load, child: items.isEmpty ? ListView(children: const [SizedBox(height: 180), Icon(Icons.fact_check_outlined, size: 52, color: blue), SizedBox(height: 12), Center(child: Text('Belum ada draft C4A', style: TextStyle(fontWeight: FontWeight.w800))), Center(child: Text('Tekan + untuk mencatat temuan.', style: TextStyle(color: muted)))]) : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: items.map(_card).toList())), floatingActionButton: FloatingActionButton(onPressed: _add, backgroundColor: amber, foregroundColor: Colors.black, child: const Icon(Icons.add))); }
  Widget _card(TemuanInspeksi item) { final failed = item.syncStatus == TemuanInspeksi.statusFailed; final synced = item.syncStatus == TemuanInspeksi.statusSynced; final color = failed ? red : synced ? green : amber; return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(item.kodeTemuan, style: const TextStyle(fontWeight: FontWeight.w800, color: blue))), Icon(synced ? Icons.cloud_done : failed ? Icons.error_outline : Icons.schedule, color: color, size: 18), const SizedBox(width: 5), Text(_statusLabel(item.syncStatus), style: TextStyle(color: color, fontWeight: FontWeight.w700))]), const SizedBox(height: 10), Row(children: [_thumb(item.fotoTemuan), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.temuan, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${item.jenisObject} • ${item.penyulang} • ${item.prioritas}', style: const TextStyle(color: muted))]))]), if (failed) ...[const SizedBox(height: 8), Text(item.syncError, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: red, fontSize: 12)), Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: busy ? null : () => _retry(item), icon: const Icon(Icons.refresh), label: const Text('Kirim ulang')))] ]))); }
  Widget _thumb(String path) => ClipRRect(borderRadius: BorderRadius.circular(10), child: path.isNotEmpty && File(path).existsSync() ? Image.file(File(path), width: 64, height: 64, fit: BoxFit.cover) : Container(width: 64, height: 64, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported_outlined)));
  String _statusLabel(String value) => switch (value) { TemuanInspeksi.statusSynced => 'Terkirim', TemuanInspeksi.statusFailed => 'Gagal', TemuanInspeksi.statusSending => 'Mengirim', TemuanInspeksi.statusDraft => 'Draft', _ => 'Antrean' };
}
