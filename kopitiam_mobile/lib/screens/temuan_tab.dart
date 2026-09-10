import 'dart:io';

import 'package:flutter/material.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../services/device_session_service.dart';
import '../services/local_auth_service.dart';
import '../services/temuan_repository.dart';
import 'login_screen.dart';
import 'wo_temuan_form_screen.dart';

class TemuanTab extends StatefulWidget {
  final WoInsjar wo;
  final Map<String, dynamic> sesi;
  final bool canAddTemuan;

  const TemuanTab({
    super.key,
    required this.wo,
    required this.sesi,
    this.canAddTemuan = true,
  });

  @override
  State<TemuanTab> createState() => _TemuanTabState();
}

class _TemuanTabState extends State<TemuanTab>
    with AutomaticKeepAliveClientMixin {
  static const blue = Color(0xFF004D8C);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFB800);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const green = Color(0xFF16A34A);

  final repo = TemuanRepository();
  List<TemuanInspeksi> items = [];
  bool busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _load(remote: true);
  }

  @override
  void didUpdateWidget(covariant TemuanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wo.kodeWo != widget.wo.kodeWo) {
      items = [];
      _load();
      _load(remote: true);
    }
  }

  Future<void> _load({bool remote = false}) async {
    if (!remote) {
      items = await repo.untukWo(widget.wo.kodeWo);
      if (mounted) setState(() {});
      return;
    }
    await repo.unduh('${widget.sesi['token'] ?? ''}', widget.wo.kodeWo);
    items = await repo.untukWo(widget.wo.kodeWo);
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    if (!widget.canAddTemuan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ambil Koordinat Awal WO terlebih dahulu sebelum menambah temuan.',
          ),
        ),
      );
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoTemuanFormScreen(
          wo: widget.wo,
          sesi: widget.sesi,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _sync() async {
    setState(() => busy = true);
    try {
      await repo.sinkron('${widget.sesi['token'] ?? ''}');
      await _load();
      if (mounted) _showSyncSuccess();
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().replaceFirst('StateError: ', '');
      final isSession =
          text.toLowerCase().contains('sesi tidak valid') ||
          text.toLowerCase().contains('sudah berakhir') ||
          text.contains('[SESSION_');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: const Color(0xFFDC2626),
          action: isSession
              ? SnackBarAction(
                  label: 'Login Ulang',
                  textColor: Colors.white,
                  onPressed: _logoutSession,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showSyncSuccess() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black26,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 1), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded, color: green, size: 48),
                SizedBox(height: 14),
                Text(
                  'Sinkronisasi Selesai',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Seluruh temuan berhasil dikirim ke server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logoutSession() async {
    await DeviceSessionService.clear();
    await LocalAuthService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            Row(
              children: [
                Text(
                  '${items.length} Temuan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: navy,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: busy ? null : _sync,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Sinkron'),
                ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 48, color: blue),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada temuan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Tambahkan temuan hasil inspeksi.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              )
            else
              ...items.map(_card),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: _add,
            backgroundColor: amber,
            foregroundColor: navy,
            icon: const Icon(Icons.add),
            label: const Text(
              'Temuan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(TemuanInspeksi item) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.kodeTemuan,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: blue,
                    ),
                  ),
                ),
                Text(
                  item.prioritas,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(item.fotoTemuan),
                const SizedBox(width: 8),
                _thumb(item.fotoLingkungan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.temuan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.tier} • ${item.segmen}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  item.dirty
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_outlined,
                  size: 13,
                  color: item.dirty ? amber : green,
                ),
                const SizedBox(width: 4),
                Text(
                  item.dirty ? 'Belum sinkron' : 'Tersinkron',
                  style: TextStyle(
                    fontSize: 10,
                    color: item.dirty ? amber : green,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  void _showImage(String path) {
    showDialog<void>(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Hero(
                    tag: path,
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                ),
              ),
              const Positioned(
                top: 48,
                right: 16,
                child: Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(String path) {
    final exists = path.isNotEmpty && File(path).existsSync();
    final image = exists
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          )
        : Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: line),
            ),
            child: const Icon(
              Icons.photo_camera_back_rounded,
              color: blue,
              size: 24,
            ),
          );
    if (!exists) return image;
    return GestureDetector(
      onTap: () => _showImage(path),
      child: Hero(tag: path, child: image),
    );
  }
}
