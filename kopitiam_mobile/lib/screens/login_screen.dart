import 'package:flutter/material.dart';

import '../theme/kopitiam_theme.dart';
import 'widgets/login_sheet.dart';
import 'widgets/safety_welcome_dialog.dart';

abstract final class AppColors {
  static const navy950 = KopitiamColors.ink;
  static const navy900 = KopitiamColors.ink;
  static const navy700 = KopitiamColors.navy;
  static const navy100 = KopitiamColors.cyanSoft;
  static const amber600 = KopitiamColors.yellow;
  static const neutral900 = KopitiamColors.ink;
  static const neutral500 = KopitiamColors.muted;
  static const neutral300 = KopitiamColors.line;
  static const red600 = KopitiamColors.danger;
  static const red100 = KopitiamColors.dangerSoft;
  static const plnYellow = KopitiamColors.yellow;
  static const plnRed = KopitiamColors.danger;
  static const safetyOrange = KopitiamColors.warning;
  static const safetyCream = KopitiamColors.warningSoft;
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _showSafetyWelcome(
    BuildContext context,
    Map<String, dynamic> session,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: KopitiamColors.scrim,
      builder: (_) => SafetyWelcomeDialog(session: session),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: KopitiamColors.surface,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned(top: 12, right: 20, child: _PlnBadge()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/branding/kopitiam-logo-master-2048.png',
                        width: 148,
                        height: 148,
                        fit: BoxFit.contain,
                        semanticLabel: 'Logo Kopitiam',
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/logo_app.png',
                          width: 132,
                          height: 132,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Kopi',
                              style: TextStyle(color: KopitiamColors.ink),
                            ),
                            TextSpan(
                              text: 'tiam',
                              style: TextStyle(color: KopitiamColors.gold),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kontrol Pemeliharaan dan Inspeksi Aset Mandiri',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: KopitiamColors.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: KopitiamColors.cyanSoft,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: KopitiamColors.gold,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'PLN UID BABEL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                                color: KopitiamColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 260,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => LoginSheet(
                              onVerified: (session) =>
                                  _showSafetyWelcome(context, session),
                            ),
                          ),
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KopitiamColors.navy,
                            foregroundColor: KopitiamColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: Text(
                  'Kopitiam © 2026 • PLN UID Babel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: KopitiamColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlnBadge extends StatelessWidget {
  const _PlnBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: KopitiamColors.yellow,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26071F33),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.bolt,
          color: KopitiamColors.danger,
          size: 28,
        ),
      );
}
