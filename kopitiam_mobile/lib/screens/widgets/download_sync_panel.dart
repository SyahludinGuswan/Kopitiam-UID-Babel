import 'package:flutter/material.dart';

import '../../theme/kopitiam_theme.dart';

typedef SyncPanelAction = Future<void> Function();

enum _Action { download, sync }

class DownloadSyncPanel extends StatefulWidget {
  final int totalReady;
  final int syncQueue;
  final SyncPanelAction onDownload;
  final SyncPanelAction onSync;

  const DownloadSyncPanel({
    super.key,
    required this.totalReady,
    required this.syncQueue,
    required this.onDownload,
    required this.onSync,
  });

  @override
  State<DownloadSyncPanel> createState() => _DownloadSyncPanelState();
}

class _DownloadSyncPanelState extends State<DownloadSyncPanel>
    with TickerProviderStateMixin {
  late final AnimationController _download;
  late final AnimationController _sync;
  _Action? _busy;
  _Action? _done;

  @override
  void initState() {
    super.initState();
    _download = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _sync = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _download.dispose();
    _sync.dispose();
    super.dispose();
  }

  Future<void> _run(_Action action) async {
    if (_busy != null) return;
    setState(() {
      _busy = action;
      _done = null;
    });
    final controller = action == _Action.download ? _download : _sync;
    controller.repeat();
    try {
      if (action == _Action.download) {
        await widget.onDownload();
      } else {
        await widget.onSync();
      }
      if (!mounted) return;
      controller.stop();
      controller.reset();
      setState(() {
        _busy = null;
        _done = action;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) setState(() => _done = null);
    } finally {
      controller.stop();
      controller.reset();
      if (mounted && _busy == action) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('download-sync-panel'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KopitiamColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: KopitiamColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x17071F33),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _HeaderIcon(),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data perangkat dan server',
                          style: TextStyle(
                            color: KopitiamColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Perbarui Work Order kapan saja',
                          style: TextStyle(
                            color: KopitiamColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      action: _Action.download,
                      label: 'Download WO',
                      caption: 'Ambil penugasan baru',
                      background: KopitiamColors.yellow,
                      foreground: KopitiamColors.ink,
                      busy: _busy == _Action.download,
                      done: _done == _Action.download,
                      controller: _download,
                      enabled: _busy == null,
                      onTap: () => _run(_Action.download),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _ActionTile(
                      action: _Action.sync,
                      label: 'Sinkron WO',
                      caption: 'Kirim progres kerja',
                      background: KopitiamColors.navy,
                      foreground: KopitiamColors.surface,
                      busy: _busy == _Action.sync,
                      done: _done == _Action.sync,
                      controller: _sync,
                      enabled: _busy == null,
                      onTap: () => _run(_Action.sync),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: KopitiamColors.cyanSoft,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _Counter(
                        label: 'Total WO Ready',
                        value: '${widget.totalReady} data',
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _Counter(
                        label: 'Antrean sinkron',
                        value: '${widget.syncQueue} data',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: KopitiamColors.cyanSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.storage_rounded,
          color: KopitiamColors.ocean,
          size: 22,
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final _Action action;
  final String label;
  final String caption;
  final Color background;
  final Color foreground;
  final bool busy;
  final bool done;
  final bool enabled;
  final Animation<double> controller;
  final VoidCallback onTap;

  const _ActionTile({
    required this.action,
    required this.label,
    required this.caption,
    required this.background,
    required this.foreground,
    required this.busy,
    required this.done,
    required this.enabled,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        label: '$label. $caption',
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            opacity: enabled || busy ? 1 : .46,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              height: 112,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: done ? KopitiamColors.successSoft : background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: _icon()),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    busy
                        ? (action == _Action.download
                            ? 'Mengunduh WO'
                            : 'Menyinkronkan WO')
                        : done
                            ? (action == _Action.download
                                ? 'Download selesai'
                                : 'Sinkron selesai')
                            : label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: KopitiamColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    busy
                        ? (action == _Action.download
                            ? 'Mengambil data terbaru...'
                            : 'Mengirim progres...')
                        : caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: KopitiamColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _icon() {
    if (done) {
      return const Icon(
        Icons.check_rounded,
        color: KopitiamColors.success,
        size: 24,
      );
    }
    if (action == _Action.download && busy) {
      return AnimatedBuilder(
        animation: controller,
        builder: (_, child) {
          final phase = controller.value;
          final opacity = phase < .18
              ? phase / .18
              : phase > .82
                  ? (1 - phase) / .18
                  : 1.0;
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, -7 + phase * 14),
              child: child,
            ),
          );
        },
        child: Icon(Icons.download_rounded, color: foreground, size: 23),
      );
    }
    if (action == _Action.sync && busy) {
      return RotationTransition(
        turns: controller,
        child: Icon(Icons.sync_rounded, color: foreground, size: 23),
      );
    }
    return Icon(
      action == _Action.download ? Icons.download_rounded : Icons.sync_rounded,
      color: foreground,
      size: 23,
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final String value;
  const _Counter({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: KopitiamColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: KopitiamColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}
