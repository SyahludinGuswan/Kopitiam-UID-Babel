import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/startup_screen.dart';
import 'services/api_service.dart';
import 'services/device_session_service.dart';
import 'services/local_auth_service.dart';
import 'services/mock_location_guard_service.dart';
import 'services/session_bootstrap_service.dart';
import 'theme/kopitiam_theme.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void main() => runApp(const KopitiamApp());

class KopitiamApp extends StatelessWidget {
  const KopitiamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Kopitiam',
        debugShowCheckedModeBanner: false,
        theme: KopitiamTheme.light,
        home: const StartupScreen(),
        builder: (context, child) => _SessionGuard(child: child!),
      );
}

class _SessionGuard extends StatefulWidget {
  final Widget child;

  const _SessionGuard({required this.child});

  @override
  State<_SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<_SessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  bool _mockLocationBlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _securityCheck(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _securityCheck());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _securityCheck();
  }

  Future<void> _securityCheck() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final mockResult = await MockLocationGuardService.check();
      if (mockResult == MockLocationCheck.mocked) {
        await _forceLogoutForMockLocation();
        return;
      }
      if (_mockLocationBlocked &&
          mockResult == MockLocationCheck.trusted &&
          mounted) {
        setState(() => _mockLocationBlocked = false);
      }
      await _enforceOfflineExpiry();
    } finally {
      _checking = false;
    }
  }

  Future<void> _forceLogoutForMockLocation() async {
    final token = await DeviceSessionService.token();
    try {
      await ApiService.logoutPerangkat(token: token);
    } catch (_) {}
    await SessionBootstrapService.clearSession();
    if (!mounted) return;
    setState(() => _mockLocationBlocked = true);
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _enforceOfflineExpiry() async {
    if (!await LocalAuthService.storedOfflineSessionExpired()) {
      return;
    }
    await SessionBootstrapService.clearSession();
    if (!mounted) return;
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          AbsorbPointer(
            absorbing: _mockLocationBlocked,
            child: widget.child,
          ),
          if (_mockLocationBlocked)
            Positioned(
              left: 20,
              right: 20,
              top: MediaQuery.paddingOf(context).top + 72,
              child: _MockLocationWarning(onRetry: _securityCheck),
            ),
        ],
      );
}

class _MockLocationWarning extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _MockLocationWarning({required this.onRetry});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
          decoration: BoxDecoration(
            color: KopitiamColors.dangerSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7AAB0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26071F33),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gps_off_rounded,
                    color: KopitiamColors.danger,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi tiruan terdeteksi',
                          style: TextStyle(
                            color: KopitiamColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Sesi dihentikan. Matikan aplikasi pengubah lokasi sebelum masuk kembali.',
                          style: TextStyle(
                            color: KopitiamColors.muted,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Periksa ulang'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KopitiamColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
