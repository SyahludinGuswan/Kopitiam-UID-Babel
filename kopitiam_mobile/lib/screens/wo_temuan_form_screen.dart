import 'package:flutter/material.dart';

import '../models/wo_insjar.dart';
import 'temuan_form_screen.dart';

/// Compatibility entry point for the imported PR60 Temuan flow.
/// The full form can be swapped in without changing TemuanTab navigation.
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
        wo: wo,
        sesi: sesi,
      );
}
