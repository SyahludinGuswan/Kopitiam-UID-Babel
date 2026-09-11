import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'work_order_start_dialog.dart';
import 'work_order_status_chip.dart';

class WorkOrderPhoto {
  final String label;
  final String source;
  const WorkOrderPhoto(this.label, this.source);
}

class BrandedWorkOrderCard extends StatelessWidget {
  static const ink = Color(0xFF071F33);
  static const logoBlue = Color(0xFF004D8C);
  static const yellow = Color(0xFFF6D03F);
  static const surface = Color(0xFFFBFDFE);
  static const line = Color(0xFFDCE8EC);
  static const muted = Color(0xFF667D86);
  static const locationSurface = Color(0xFFE0F5F8);
  static const findingSurface = Color(0xFFFFF8E7);

  final String code;
  final String typeLabel;
  final String status;
  final String finding;
  final String feeder;
  final String section;
  final String date;
  final String coordinate;
  final List<WorkOrderPhoto> photos;
  final bool waiting;
  final bool finished;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  const BrandedWorkOrderCard({
    super.key,
    required this.code,
    required this.typeLabel,
    required this.status,
    required this.finding,
    required this.feeder,
    required this.section,
    required this.date,
    required this.coordinate,
    required this.photos,
    required this.waiting,
    required this.finished,
    required this.onStart,
    required this.onOpen,
  });

  Future<void> _openLocation(BuildContext context) async {
    if (coordinate.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi Work Order belum tersedia.')),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(coordinate.trim())}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps tidak dapat dibuka.')),
      );
    }
  }

  Future<void> _start(BuildContext context) async {
    final confirmed = await showWorkOrderStartDialog(
      context,
      code: code,
      module: typeLabel,
      title: finding.trim().isEmpty ? feeder : finding,
      detail: [feeder, section]
          .where((value) => value.trim().isNotEmpty)
          .join(' • '),
    );
    if (confirmed) onStart();
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18063B5C),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: WorkOrderStatusChip(
                          status: status,
                          waiting: waiting,
                          finished: finished,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _locationButton(context),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _details(),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _primaryAction(context),
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var index = 0; index < photos.length; index++) ...[
                          if (index > 0) const SizedBox(width: 8),
                          Expanded(child: _photo(context, photos[index])),
                        ],
                      ],
                    ),
                  ],
                  _dateRow(),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _header() => Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF176DA8), logoBlue, Color(0xFF004279)],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: surface,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0x99D6A93A)),
              ),
              child: Text(
                typeLabel,
                style: const TextStyle(
                  color: yellow,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _locationButton(BuildContext context) => Material(
        color: locationSurface,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          onTap: () => _openLocation(context),
          borderRadius: BorderRadius.circular(100),
          child: const SizedBox(
            height: 36,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: logoBlue),
                  SizedBox(width: 5),
                  Text(
                    'Lokasi',
                    style: TextStyle(
                      color: logoBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _details() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: findingSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8CF91)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TEMUAN',
                  style: TextStyle(
                    color: Color(0xFF8B6100),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  finding.trim().isEmpty ? 'Temuan belum tersedia' : finding,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feeder.trim().isEmpty ? 'Penyulang belum tersedia' : feeder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            section.trim().isEmpty ? 'Section belum tersedia' : section,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
      );

  Widget _primaryAction(BuildContext context) => SizedBox(
        height: 48,
        child: waiting
            ? ElevatedButton(
                onPressed: () => _start(context),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: yellow,
                  foregroundColor: ink,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Mulai',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              )
            : OutlinedButton(
                onPressed: onOpen,
                style: OutlinedButton.styleFrom(
                  foregroundColor: logoBlue,
                  side: const BorderSide(color: logoBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  finished ? 'Lihat' : 'Lanjutkan',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
      );

  Widget _photo(BuildContext context, WorkOrderPhoto photo) => Material(
        color: const Color(0xFFEAF2F4),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showPhoto(context, photo),
          child: AspectRatio(
            aspectRatio: 2.15,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(photo.source),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    color: const Color(0xD907344B),
                    child: Text(
                      photo.label,
                      style: const TextStyle(
                        color: surface,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _dateRow() => Column(
        children: [
          const SizedBox(height: 14),
          const Divider(height: 1, color: line),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 15, color: muted),
              const SizedBox(width: 7),
              const Text(
                'Tanggal WO',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  date.trim().isEmpty ? 'Belum tersedia' : date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _image(String source) {
    final path = source.trim();
    if (path.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported_outlined, color: muted),
      );
    }
    final file = File(path);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    final uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: muted),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.image_not_supported_outlined, color: muted),
    );
  }

  Future<void> _showPhoto(
    BuildContext context,
    WorkOrderPhoto photo,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: ink,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      photo.label,
                      style: const TextStyle(
                        color: surface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    color: surface,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _image(photo.source),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
