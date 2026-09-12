import 'package:flutter/material.dart';

import '../../models/wo_row.dart';
import '../../widgets/branded_work_order_card.dart';

class WoRowCard extends StatelessWidget {
  final WoRow row;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  const WoRowCard({
    super.key,
    required this.row,
    required this.onStart,
    required this.onOpen,
  });

  String get _coordinate {
    if (row.koordinat.trim().isNotEmpty) return row.koordinat.trim();
    if (row.lat.trim().isNotEmpty && row.long.trim().isNotEmpty) {
      return '${row.lat.trim()}, ${row.long.trim()}';
    }
    return '';
  }

  String get _section => [
        if (row.section.trim().isNotEmpty) row.section.trim(),
        if (row.segmen.trim().isNotEmpty) row.segmen.trim(),
      ].join(' • ');

  String _photoSource(String local, String remote) =>
      local.trim().isNotEmpty ? local.trim() : remote.trim();

  @override
  Widget build(BuildContext context) {
    final status = WoRow.normalisasiStatus(row.statusWo);
    return BrandedWorkOrderCard(
      code: row.kodeWo,
      typeLabel: 'ROW',
      status: status,
      finding: row.temuan,
      feeder: row.penyulang,
      section: _section,
      date: row.tanggal,
      coordinate: _coordinate,
      photos: [
        WorkOrderPhoto(
          'Foto Temuan',
          _photoSource(row.fotoTemuan, row.linkFoto),
        ),
        WorkOrderPhoto(
          'Foto Sekitar',
          _photoSource(row.fotoLingkungan, row.linkLingkungan),
        ),
      ],
      waiting: status == WoRow.statusPenugasan,
      finished: status == WoRow.statusSelesai,
      onStart: onStart,
      onOpen: onOpen,
    );
  }
}
