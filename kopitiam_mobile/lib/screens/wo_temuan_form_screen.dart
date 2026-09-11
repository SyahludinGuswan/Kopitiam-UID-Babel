import 'package:flutter/material.dart';

import '../models/wo_insjar.dart';
import 'temuan_form_screen.dart';

/// Entry point khusus Temuan dari detail WO Inspeksi Jaringan.
///
/// Form visual dan alur validasinya berasal dari implementasi PR 60 di
/// [TemuanFormScreen]. C4A tetap memakai constructor `TemuanFormScreen.c4a`,
/// sehingga kedua alur tidak saling tertukar.
class WoTemuanFormScreen extends StatelessWidget {
  final WoInsjar wo;
  final Map<String, dynamic> sesi;

  const WoTemuanFormScreen({
    super.key,
    required this.wo,
    required this.sesi,
  });

  @override
  Widget build(BuildContext context) => TemuanFormScreen(
        key: ValueKey('pr60-wo-temuan-${wo.kodeWo}'),
        wo: wo,
        sesi: sesi,
      );
}
