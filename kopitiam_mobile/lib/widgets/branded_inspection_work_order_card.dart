import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'work_order_start_dialog.dart';
import 'work_order_status_chip.dart';

class BrandedInspectionWorkOrderCard extends StatelessWidget {
  final String code;
  final String typeLabel;
  final String status;
  final String title;
  final String subtitle;
  final String section;
  final String date;
  final String mapUrl;
  final String locationLabel;
  final bool waiting;
  final bool finished;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  const BrandedInspectionWorkOrderCard({
    super.key,
    required this.code,
    required this.typeLabel,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.date,
    required this.mapUrl,
    required this.locationLabel,
    required this.waiting,
    required this.finished,
    required this.onStart,
    required this.onOpen,
  });

  Future<void> _start(BuildContext context) async {
    final confirmed = await showWorkOrderStartDialog(
      context,
      code: code,
      module: typeLabel,
      title: title,
      detail: [subtitle, section]
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
          color: const Color(0xFFFBFDFE),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE8EC)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18063B5C),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF176DA8),
                    Color(0xFF004D8C),
                    Color(0xFF004279),
                  ],
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
                        color: Color(0xFFFBFDFE),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    typeLabel,
                    style: const TextStyle(
                      color: Color(0xFFF6D03F),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: WorkOrderStatusChip(
                          status: status,
                          waiting: waiting,
                          finished: finished,
                        ),
                      ),
                      if (mapUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(mapUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.location_on_outlined, size: 15),
                          label: Text(locationLabel),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (section.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      section,
                      style: const TextStyle(
                        color: Color(0xFF667D86),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 9),
                  Text(
                    'Tanggal WO  $date',
                    style: const TextStyle(
                      color: Color(0xFF667D86),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: waiting
                        ? ElevatedButton(
                            onPressed: () => _start(context),
                            child: const Text('Mulai'),
                          )
                        : OutlinedButton(
                            onPressed: onOpen,
                            child: Text(finished ? 'Lihat' : 'Lanjutkan'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
