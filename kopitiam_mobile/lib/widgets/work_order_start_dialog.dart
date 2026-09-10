import 'package:flutter/material.dart';

const _ink = Color(0xFF071F33);
const _blue = Color(0xFF004D8C);
const _yellow = Color(0xFFF6D03F);
const _surface = Color(0xFFFBFDFE);
const _muted = Color(0xFF667D86);

Future<bool> showWorkOrderStartDialog(
  BuildContext context, {
  required String code,
  required String module,
  required String title,
  required String detail,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: _surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF176DA8), _blue, Color(0xFF004279)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _yellow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: _ink),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mulai pekerjaan ini?',
                    style: TextStyle(
                      color: _surface,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  color: _surface,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pastikan Work Order yang dipilih sudah benar. Setelah dikonfirmasi, WO akan di mulai untuk dikerjakan',
                  style: TextStyle(color: _muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                Text(
                  module.toUpperCase(),
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(detail, style: const TextStyle(color: _muted, fontSize: 12)),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _yellow,
                          foregroundColor: _ink,
                        ),
                        child: const Text('Ya, mulai'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return result == true;
}
