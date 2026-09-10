import 'package:flutter/material.dart';

import '../../models/har_execution.dart';
import '../../models/wo_insdu.dart';
import '../../models/wo_insjar.dart';
import '../../models/wo_row.dart';
import '../../services/network_status_service.dart';
import '../../services/wo_insdu_repository.dart';
import '../../services/wo_insjar_repository.dart';
import '../../services/wo_row_repository.dart';
import '../../theme/kopitiam_theme.dart';
import 'welcome_coffee_mark.dart';
import 'wo_summary_card.dart';

typedef NetworkProbe = Future<bool> Function();

class WelcomeCard extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final NetworkProbe? networkProbe;

  const WelcomeCard({super.key, required this.sesi, this.networkProbe});

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard>
    with WidgetsBindingObserver {
  bool? _online;
  bool _checking = false;
  bool _loading = false;
  int _total = 0;
  int _waiting = 0;
  int _progress = 0;
  int _done = 0;

  String get _identity =>
      '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''} '
              '${widget.sesi['username'] ?? ''}'
          .toLowerCase();
  bool get _isInsdu =>
      _identity.contains('inspeksi gardu') || _identity.contains('insdu');
  bool get _isRow => !_isInsdu && _identity.contains('row');
  bool get _showSummary => HarExecution.allowedTypes(widget.sesi).isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNetwork();
    _loadSummary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNetwork();
      _loadSummary();
    }
  }

  Future<void> _checkNetwork() async {
    if (_checking) return;
    _checking = true;
    try {
      final probe = widget.networkProbe ?? NetworkStatusService.isOnline;
      final online = await probe();
      if (mounted && online != _online) setState(() => _online = online);
    } finally {
      _checking = false;
    }
  }

  Future<void> _loadSummary() async {
    if (!_showSummary || _loading) return;
    _loading = true;
    try {
      final values = <int>[0, 0, 0, 0];
      if (_isInsdu) {
        final items = await WoInsduRepository().semua();
        values[0] = items.length;
        values[1] = items.where((i) => WoInsdu.normalisasiStatus(i.statusWo) == WoInsdu.statusMulai).length;
        values[2] = items.where((i) => WoInsdu.normalisasiStatus(i.statusWo) == WoInsdu.statusDalam).length;
        values[3] = items.where((i) => WoInsdu.normalisasiStatus(i.statusWo) == WoInsdu.statusSelesai).length;
      } else if (_isRow) {
        final items = await WoRowRepository().semua();
        values[0] = items.length;
        values[1] = items.where((i) => WoRow.normalisasiStatus(i.statusWo) == WoRow.statusPenugasan).length;
        values[2] = items.where((i) => WoRow.normalisasiStatus(i.statusWo) == WoRow.statusProgress).length;
        values[3] = items.where((i) => WoRow.normalisasiStatus(i.statusWo) == WoRow.statusSelesai).length;
      } else {
        final items = await WoInsjarRepository().semua();
        values[0] = items.length;
        values[1] = items.where((i) => WoInsjar.normalisasiStatus(i.statusWo) == WoInsjar.statusMulai).length;
        values[2] = items.where((i) => WoInsjar.normalisasiStatus(i.statusWo) == WoInsjar.statusDalam).length;
        values[3] = items.where((i) => WoInsjar.normalisasiStatus(i.statusWo) == WoInsjar.statusSelesai).length;
      }
      if (mounted) {
        setState(() {
          _total = values[0];
          _waiting = values[1];
          _progress = values[2];
          _done = values[3];
        });
      }
    } finally {
      _loading = false;
    }
  }

  String get _dateText {
    final now = DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final team = '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? '-'}';
    final ulp = '${widget.sesi['ulp'] ?? '-'}';
    final bidang = '${widget.sesi['bidang'] ?? widget.sesi['Bidang'] ?? '-'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _welcome(team, ulp, bidang),
        if (_showSummary) ...[
          const SizedBox(height: 16),
          if (_loading && _total == 0)
            const LinearProgressIndicator()
          else if (_isRow)
            WoSummaryCard.row(total: _total, penugasan: _waiting, progress: _progress, selesai: _done)
          else
            WoSummaryCard.insjar(total: _total, menunggu: _waiting, sedang: _progress, selesai: _done),
        ],
      ],
    );
  }

  Widget _welcome(String team, String ulp, String bidang) {
    final online = _online == true ? 'ONLINE' : _online == false ? 'OFFLINE' : 'CEK...';
    final dot = _online == true ? KopitiamColors.success : _online == false ? KopitiamColors.danger : KopitiamColors.muted;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF176DA8), Color(0xFF004D8C), Color(0xFF004279)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A79B2)),
        boxShadow: const [BoxShadow(color: Color(0x33071F33), blurRadius: 30, offset: Offset(0, 16))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateText, style: const TextStyle(color: KopitiamColors.yellow, fontSize: 11, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Semangat Pagi,', style: TextStyle(color: KopitiamColors.surface, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(team, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 25, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              InkWell(
                onTap: _checking ? null : _checkNetwork,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(color: KopitiamColors.navy, borderRadius: BorderRadius.circular(100), border: Border.all(color: KopitiamColors.surface)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 7), Text(online, style: const TextStyle(color: KopitiamColors.surface, fontSize: 10, fontWeight: FontWeight.w900))]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xA6FBFDFE), height: 1),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 52),
                child: Row(children: [Expanded(child: _info('UNIT KERJA', ulp)), const SizedBox(width: 18), Expanded(child: _info('BIDANG', bidang))]),
              ),
              const WelcomeCoffeeMark(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: KopitiamColors.yellow, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      );
}
