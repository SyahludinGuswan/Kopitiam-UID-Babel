import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/wo_insdu.dart';
import 'start_work_order_dialog.dart';

class WoInsduCard extends StatelessWidget {
  static const navy = Color(0xFF071B30);
  static const blue = Color(0xFF004D8C);
  static const amber = Color(0xFFFFB800);
  static const green = Color(0xFF16834B);
  static const muted = Color(0xFF667D86);
  static const surface = Color(0xFFFBFDFE);
  static const line = Color(0xFFDCE8EC);
  static const gold = Color(0xFFD6A93A);
  static const yellow = Color(0xFFF6D03F);

  final WoInsdu wo;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  const WoInsduCard({
    super.key,
    required this.wo,
    required this.onStart,
    required this.onOpen,
  });

  String get _coordinate {
    if (wo.koordinatGardu.trim().isNotEmpty) return wo.koordinatGardu.trim();
    if (wo.lat.trim().isNotEmpty && wo.long.trim().isNotEmpty) {
      return '${wo.lat.trim()}, ${wo.long.trim()}';
    }
    return '';
  }

  Future<void> _maps(BuildContext context) async {
    if (_coordinate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat Gardu belum tersedia.')),
      );
      return;
    }
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${Uri.encodeComponent(_coordinate)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = WoInsdu.normalisasiStatus(wo.statusWo);
    final waiting = status == WoInsdu.statusMulai;
    final done = status == WoInsdu.statusSelesai;

    final chipBackground = waiting
        ? const Color(0xFFFFF3D8)
        : done
            ? const Color(0xFFE1F5EC)
            : const Color(0xFFE8F4FC);
    final chipForeground = waiting
        ? const Color(0xFF8B6100)
        : done
            ? green
            : const Color(0xFF176DA8);
    final chipText = waiting
        ? 'Belum dikerjakan'
        : done
            ? 'Selesai'
            : 'Dalam Pengerjaan';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24063B5C),
            blurRadius: 26,
            offset: Offset(0, 11),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 56,
            right: 56,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    gold,
                    yellow,
                    gold,
                    Colors.transparent,
                  ],
                ),
                boxShadow: [BoxShadow(color: Color(0x55D6A93A), blurRadius: 10)],
              ),
              child: SizedBox(height: 3),
            ),
          ),
          const Positioned(
            right: -48,
            top: -71,
            child: IgnorePointer(child: _GoldOrbit()),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF176DA8), blue, Color(0xFF004279)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        wo.kodeWo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: surface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Text(
                      'INSPEKSI GARDU',
                      style: TextStyle(
                        color: yellow,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: chipBackground,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                done ? Icons.check_circle_rounded : Icons.circle,
                                size: done ? 13 : 7,
                                color: chipForeground,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                chipText,
                                style: TextStyle(
                                  color: chipForeground,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => _maps(context),
                          icon: const Icon(Icons.location_on_outlined, size: 17),
                          label: const Text('Lokasi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: blue,
                            minimumSize: const Size(44, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            side: const BorderSide(color: line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wo.nomorGardu.isEmpty
                                    ? 'Gardu belum ditentukan'
                                    : wo.nomorGardu,
                                style: const TextStyle(
                                  color: navy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${wo.penyulang} • ${wo.section}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        waiting
                            ? ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await confirmStartWorkOrder(
                                    context,
                                    code: wo.kodeWo,
                                    title: 'pekerjaan Inspeksi Gardu',
                                  );
                                  if (confirmed) onStart();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: yellow,
                                  foregroundColor: navy,
                                  minimumSize: const Size(44, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Mulai'),
                              )
                            : OutlinedButton(
                                onPressed: onOpen,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: done ? green : blue,
                                  minimumSize: const Size(44, 40),
                                  side: BorderSide(color: done ? green : blue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(done ? 'Lihat' : 'Lanjut'),
                              ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 11),
                    Text(
                      'Tanggal WO  ${wo.tanggal}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoldOrbit extends StatelessWidget {
  const _GoldOrbit();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(painter: _GoldOrbitPainter()),
      );
}

class _GoldOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0x47D6A93A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 74, paint);
    paint.color = const Color(0x28FFD84D);
    canvas.drawCircle(center, 52, paint);
  }

  @override
  bool shouldRepaint(covariant _GoldOrbitPainter oldDelegate) => false;
}
