import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/local_auth_service.dart';
import '../services/session_bootstrap_service.dart';
import '../theme/kopitiam_theme.dart';
import 'login_screen.dart';
import 'widgets/master_data_accordion.dart';

class SettingsSessionSection extends StatefulWidget {
  final Map<String, dynamic> session;
  final bool showMasterGardu;
  final bool showMasterAccordion;

  const SettingsSessionSection({
    super.key,
    required this.session,
    this.showMasterGardu = true,
    this.showMasterAccordion = true,
  });

  @override
  State<SettingsSessionSection> createState() => _SettingsSessionSectionState();
}

class _SettingsSessionSectionState extends State<SettingsSessionSection> {
  Timer? _expiryTimer;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _expiryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _enforceOfflineExpiry(),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _enforceOfflineExpiry(),
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _enforceOfflineExpiry() async {
    if (!mounted || !LocalAuthService.offlineSessionExpired(widget.session))
      return;
    await _clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari Kopitiam?'),
        content: const Text('Sesi perangkat dan akses offline akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await ApiService.logoutPerangkat(
        token: '${widget.session['token'] ?? ''}',
      );
    } catch (_) {
      // Sesi lokal tetap harus dihentikan jika perangkat sedang offline.
    } finally {
      await _clear();
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _clear() async {
    await SessionBootstrapService.clearSession();
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.session['offlineLogin'] == true;
    return Column(
      children: [
        if (widget.showMasterAccordion && widget.showMasterGardu)
          MasterDataAccordion(token: '${widget.session['token'] ?? ''}'),
        Card(
          margin: const EdgeInsets.only(top: 14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_rounded,
                      color: Color(0xFF004D8C),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Akun & Sesi',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  offline
                      ? 'Mode offline aktif, maksimal 24 jam sejak verifikasi online.'
                      : 'Keluar akan mencabut token perangkat dan akses offline.',
                  style: const TextStyle(color: KopitiamColors.muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(_loggingOut ? 'Keluar...' : 'Log out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
