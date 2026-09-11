import 'package:flutter/material.dart';

import '../../theme/kopitiam_theme.dart';

Future<void> showOperationResultDialog(
  BuildContext context, {
  required bool success,
  required String title,
  required String message,
}) {
  final showMessage = title != 'WO Tersimpan' && message.trim().isNotEmpty;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Hasil operasi',
    barrierColor: const Color(0xB3071F33),
    transitionDuration: const Duration(milliseconds: 360),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.16, 1, 0.3, 1),
        reverseCurve: const Cubic(0.7, 0, 0.84, 0),
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, _, __) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(dialogContext),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                  decoration: BoxDecoration(
                    color: KopitiamColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: success
                          ? const Color(0xFF9BD8BF)
                          : const Color(0xFFE8ADB2),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3D071F33),
                        blurRadius: 32,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: success
                              ? KopitiamColors.successSoft
                              : KopitiamColors.dangerSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: success
                                ? const Color(0xFF9BD8BF)
                                : const Color(0xFFE8ADB2),
                          ),
                        ),
                        child: Icon(
                          success
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          color: success
                              ? KopitiamColors.success
                              : KopitiamColors.danger,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: KopitiamColors.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                      if (showMessage) ...[
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: KopitiamColors.muted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: KopitiamColors.surfaceStrong,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 15,
                              color: KopitiamColors.ocean,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Ketuk layar untuk menutup',
                              style: TextStyle(
                                color: KopitiamColors.ocean,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
