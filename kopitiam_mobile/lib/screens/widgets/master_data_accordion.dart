import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../services/api_service.dart';
import '../../services/master_data_comparison.dart';
import '../../services/sqlite_service.dart';
import '../../theme/kopitiam_theme.dart';

abstract final class MasterSyncStatus {
  static const pending = 'pending';
  static const syncing = 'syncing';
  static const synced = 'synced';
  static const failed = 'failed';
}

class MasterDatasetState {
  final String key;
  final String label;
  final String status;
  final String error;
  const MasterDatasetState({
    required this.key,
    required this.label,
    this.status = MasterSyncStatus.pending,
    this.error = '',
  });
  MasterDatasetState copyWith({String? status, String? error}) =>
      MasterDatasetState(key: key, label: label,
        status: status ?? this.status, error: error ?? this.error);
}

typedef GeneralMasterFetcher = Future<Map<String, dynamic>> Function(String token);
typedef GarduMasterFetcher = Future<Map<String, dynamic>> Function(String token);

class MasterDataAccordion extends StatefulWidget {
  final String token;
  final GeneralMasterFetcher? fetchGeneral;
  final GarduMasterFetcher? fetchGardu;
  final Database? database;
  const MasterDataAccordion({
    super.key, required this.token, this.fetchGeneral, this.fetchGardu,
    this.database,
  });
  @override
  State<MasterDataAccordion> createState() => _MasterDataAccordionState();
}

class _MasterDataAccordionState extends State<MasterDataAccordion> {
  static const definitions = <MapEntry<String, String>>[
    MapEntry('User_App_Mobile', 'Master User & Akses'),
    MapEntry('Master_Penyulang', 'Master Penyulang'),
    MapEntry('Master_Keypoint', 'Master Keypoint'),
    MapEntry('Master_Temuan', 'Master Temuan'),
    MapEntry('Jenis Pohon', 'Master Jenis Pohon'),
    MapEntry('Master_Material', 'Master Material'),
    MapEntry('Master_Pekerjaan_Har', 'Master Pekerjaan Har'),
    MapEntry('Master_Gardu', 'Master Gardu'),
  ];
  static const _modeKey = 'master_update_mode';
  late List<MasterDatasetState> datasets = definitions.map((entry) =>
      MasterDatasetState(key: entry.key, label: entry.value)).toList();
  final selected = <String>{};
  final _everSynced = <String>{};
  final _needsUpdate = <String>{};
  final _verified = <String>{};
  final _checkErrors = <String, String>{};
  bool expanded = false;
  bool busy = false;
  bool _checking = false;
  bool _initializing = true;
  bool _updateMode = false;
  double progress = 0;
  String progressLabel = '';
  String? _error;
  DateTime? _lastCheck;

  bool get _blocked => busy || _checking || _initializing;
  Future<Database> get db async => widget.database ?? SqliteService.instance.database;
  GeneralMasterFetcher get fetchGeneral => widget.fetchGeneral ?? ApiService.getMasterData;
  GarduMasterFetcher get fetchGardu => widget.fetchGardu ?? ApiService.getMasterGardu;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final database = await db;
      final rows = await database.query('sync_metadata');
      final metadata = {for (final row in rows) '${row['key']}': row};
      if (!mounted) return;
      setState(() {
        datasets = datasets.map((item) {
          final row = metadata[item.key];
          if (row == null) return item;
          final success = row['status'] == 'success';
          if (success) _everSynced.add(item.key);
          return item.copyWith(
            status: success ? MasterSyncStatus.synced : MasterSyncStatus.failed,
            error: '${row['error_message'] ?? ''}',
          );
        }).toList();
        _updateMode = metadata[_modeKey]?['status'] == 'success' ||
            _everSynced.length == definitions.length;
        selected.addAll(datasets.where((item) =>
            item.status != MasterSyncStatus.synced).map((item) => item.key));
      });
      await _rememberUpdateMode(database);
    } catch (error) {
      if (mounted) setState(() => _error = 'Status lokal gagal dibaca: $error');
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _rememberUpdateMode(Database database) async {
    if (!_updateMode && _everSynced.length != definitions.length) return;
    _updateMode = true;
    await database.insert('sync_metadata', {
      'key': _modeKey,
      'synced_at': DateTime.now().toUtc().toIso8601String(),
      'row_count': 0, 'status': 'success', 'error_message': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _setStatus(String key, String status, {String error = ''}) {
    final index = datasets.indexWhere((item) => item.key == key);
    if (index < 0 || !mounted) return;
    setState(() => datasets[index] =
        datasets[index].copyWith(status: status, error: error));
  }

  Future<List<Map<String, dynamic>>> _local(String key) async {
    final database = await db;
    final rows = await database.query('master_data_rows',
        where: 'dataset = ?', whereArgs: [key]);
    return rows.where((row) => row['dataset'] == key).map((row) =>
        Map<String, dynamic>.from(jsonDecode('${row['payload_json']}'))).toList();
  }

  Future<Map<String, dynamic>> _general() async {
    final response = await fetchGeneral(widget.token).timeout(const Duration(seconds: 45));
    if (response['success'] != true || response['datasets'] is! Map) {
      throw StateError('${response['message'] ?? 'Master Data tidak valid.'}');
    }
    return Map<String, dynamic>.from(response['datasets']);
  }

  Future<List<Map<String, dynamic>>> _gardu() async {
    final response = await fetchGardu(widget.token).timeout(const Duration(seconds: 45));
    if (response['success'] != true) {
      throw StateError('${response['message'] ?? 'Master Gardu tidak valid.'}');
    }
    return MasterDataComparison.validate(response['rows']);
  }

  Future<void> _compare(String key, Object? remote) async {
    final rows = MasterDataComparison.validate(remote);
    final local = await _local(key);
    if (!mounted) return;
    setState(() {
      _checkErrors.remove(key);
      if (!MasterDataComparison.equal(local, rows)) {
        _needsUpdate.add(key);
        _verified.remove(key);
      } else {
        _needsUpdate.remove(key);
        _verified.add(key);
      }
    });
  }

  void _checkFailed(Iterable<String> keys, Object error) {
    if (!mounted) return;
    setState(() {
      for (final key in keys) {
        _checkErrors[key] = '$error';
        _verified.remove(key);
      }
    });
  }

  Future<void> _checkUpdates() async {
    if (_blocked || _everSynced.isEmpty) return;
    setState(() { _checking = true; _error = null; });
    final general = _everSynced.where((key) => key != 'Master_Gardu').toList();
    try {
      if (general.isNotEmpty) {
        try {
          final payload = await _general();
          for (final key in general) {
            try { await _compare(key, payload[key]); }
            catch (error) { _checkFailed([key], error); }
          }
        } catch (error) { _checkFailed(general, error); }
      }
      if (_everSynced.contains('Master_Gardu')) {
        try { await _compare('Master_Gardu', await _gardu()); }
        catch (error) { _checkFailed(['Master_Gardu'], error); }
      }
      if (mounted) setState(() => _lastCheck = DateTime.now());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _persist(String key, List<Map<String, dynamic>> rows) async {
    final database = await db;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((txn) async {
      await txn.delete('master_data_rows', where: 'dataset = ?', whereArgs: [key]);
      for (var index = 0; index < rows.length; index++) {
        await txn.insert('master_data_rows', {
          'dataset': key, 'row_key': '$index',
          'payload_json': jsonEncode(rows[index]), 'synced_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('sync_metadata', {
        'key': key, 'synced_at': now, 'row_count': rows.length,
        'status': 'success', 'error_message': '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    _everSynced.add(key);
    _needsUpdate.remove(key);
    _checkErrors.remove(key);
    _verified.add(key);
    selected.remove(key);
    _setStatus(key, MasterSyncStatus.synced);
  }

  Future<void> _failed(String key, Object error) async {
    // Do not erase a prior successful sync record or local data on failure.
    if (!_everSynced.contains(key)) {
      final database = await db;
      await database.insert('sync_metadata', {
        'key': key, 'synced_at': DateTime.now().toUtc().toIso8601String(),
        'row_count': 0, 'status': 'failed', 'error_message': '$error',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    _verified.remove(key);
    _setStatus(key, MasterSyncStatus.failed, error: '$error');
  }

  Future<void> _sync(Iterable<String> keys) async {
    if (_blocked) return;
    final targets = keys.where((key) => definitions.any((item) => item.key == key)).toSet();
    if (targets.isEmpty) return;
    setState(() {
      busy = true; expanded = true; progress = 0; _error = null;
      progressLabel = 'Menyiapkan Master Data';
    });
    var completed = 0;
    try {
      Map<String, dynamic> payload = {};
      Object? generalError;
      if (targets.any((key) => key != 'Master_Gardu')) {
        try { payload = await _general(); }
        catch (error) { generalError = error; }
      }
      for (final key in targets) {
        if (!mounted) return;
        _setStatus(key, MasterSyncStatus.syncing);
        setState(() => progressLabel =
            'Memperbarui ${datasets.firstWhere((item) => item.key == key).label}');
        try {
          if (key != 'Master_Gardu' && generalError != null) throw generalError;
          final rows = key == 'Master_Gardu' ? await _gardu() :
              MasterDataComparison.validate(payload[key]);
          // Fetch again at update time: never write a stale comparison snapshot.
          await _persist(key, rows);
        } catch (error) { await _failed(key, error); }
        completed++;
        if (mounted) setState(() => progress = completed / targets.length);
      }
      await _rememberUpdateMode(await db);
    } catch (error) {
      if (mounted) setState(() => _error = 'Pembaruan gagal: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get summaryStatus {
    if (_checking) return 'MEMERIKSA';
    if (busy) return 'PROSES';
    if (_needsUpdate.isNotEmpty) return 'PERLU UPDATE';
    if (datasets.any((item) => item.status == MasterSyncStatus.failed)) return 'GAGAL';
    if (_checkErrors.isNotEmpty) return 'CEK GAGAL';
    if (_verified.length == definitions.length) return 'TERBARU';
    if (_everSynced.length == definitions.length) return 'SINKRON';
    return 'BELUM SINKRON';
  }

  Color _color(String label) {
    if (label == 'GAGAL' || label == 'CEK GAGAL') return KopitiamColors.danger;
    if (label == 'SINKRON' || label == 'TERBARU') return KopitiamColors.success;
    if (label == 'MEMERIKSA' || label == 'PROSES') return KopitiamColors.ocean;
    return KopitiamColors.warning;
  }

  void _toggle() {
    if (_blocked) return;
    setState(() => expanded = !expanded);
    // Automatic read-only comparison on every panel opening.
    if (expanded) _checkUpdates();
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('master-data-accordion'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: KopitiamColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE4D5AC)),
      boxShadow: const [BoxShadow(color: Color(0x17071F33), blurRadius: 28, offset: Offset(0, 12))],
    ),
    child: Stack(children: [
      const Positioned(left: 70, right: 70, top: 0,
        child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          colors: [Colors.transparent, KopitiamColors.gold, Colors.transparent],
        )), child: SizedBox(height: 3))),
      Column(children: [
        InkWell(onTap: _blocked ? null : _toggle,
          child: Padding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(color: KopitiamColors.cyanSoft, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF004D8C), size: 27)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Master Data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Kelola data untuk penggunaan offline', style: TextStyle(color: KopitiamColors.muted, fontSize: 11)),
              ])),
              Column(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: _color(summaryStatus).withValues(alpha: .10), borderRadius: BorderRadius.circular(100)),
                  child: Text(summaryStatus, style: TextStyle(color: _color(summaryStatus), fontSize: 9, fontWeight: FontWeight.w900))),
                const SizedBox(height: 5),
                AnimatedRotation(turns: expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 300), curve: const Cubic(.16, 1, .3, 1),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: KopitiamColors.muted)),
              ]),
            ]))),
        if (_initializing) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.all(18), child: Text(_error!, style: const TextStyle(color: KopitiamColors.danger))),
        AnimatedCrossFade(duration: const Duration(milliseconds: 360),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity), secondChild: _details()),
      ]),
    ]),
  );

  Widget _details() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
    child: Column(children: [
      const Divider(),
      Row(children: [
        Expanded(child: Text(_updateMode ? 'Pilih Master Data untuk diperbarui' : 'Pilih Master Data yang ingin disinkronkan',
          style: const TextStyle(color: KopitiamColors.muted, fontSize: 11))),
        TextButton(onPressed: _blocked ? null : () => setState(() {
          selected..clear()..addAll(datasets.map((item) => item.key));
        }), child: const Text('Pilih semua')),
      ]),
      if (_everSynced.isNotEmpty) Row(children: [
        Expanded(child: Text(_checking ? 'Membandingkan isi lokal dan server...' :
          _checkErrors.isNotEmpty ? 'Pengecekan belum lengkap. Data lokal tetap aman.' :
          _lastCheck == null ? 'Belum dibandingkan dengan server.' :
          'Dicek ${_lastCheck!.hour.toString().padLeft(2, '0')}:${_lastCheck!.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 10, color: KopitiamColors.muted))),
        TextButton(onPressed: _blocked ? null : _checkUpdates, child: const Text('Cek perubahan')),
      ]),
      if (_checking) const LinearProgressIndicator(),
      for (final item in datasets) _datasetRow(item),
      if (busy) Padding(padding: const EdgeInsets.only(top: 14), child: Column(children: [
        Text(progressLabel, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 8), LinearProgressIndicator(value: progress),
        Text('${(progress * 100).round()}%'),
      ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: _blocked || selected.isEmpty ? null : () => _sync(selected),
          child: Text('${_updateMode ? 'Update Terpilih' : 'Sinkron Terpilih'}${selected.isEmpty ? '' : ' (${selected.length})'}', textAlign: TextAlign.center))),
        const SizedBox(width: 9),
        Expanded(child: FilledButton(
          onPressed: _blocked || (_updateMode && selected.isEmpty) ? null :
              () => _sync(_updateMode ? selected : datasets.map((item) => item.key)),
          child: Text(_updateMode ? 'Update Master Data' : 'Sinkron Semua', textAlign: TextAlign.center))),
      ]),
    ]),
  );

  Widget _datasetRow(MasterDatasetState item) {
    final failed = item.status == MasterSyncStatus.failed;
    final label = item.status == MasterSyncStatus.syncing ? 'PROSES' :
        failed ? 'GAGAL' : _needsUpdate.contains(item.key) ? 'PERLU DIPERBARUI' :
        _checkErrors.containsKey(item.key) ? 'CEK GAGAL' :
        _verified.contains(item.key) ? 'TERBARU' :
        item.status == MasterSyncStatus.synced ? 'SINKRON' : 'BELUM SINKRON';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KopitiamColors.line))),
      child: Row(children: [
        Checkbox(value: selected.contains(item.key),
          onChanged: _blocked ? null : (value) => setState(() {
            if (value == true) { selected.add(item.key); } else { selected.remove(item.key); }
          }), visualDensity: VisualDensity.compact),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _color(label), fontSize: 9, fontWeight: FontWeight.w900)),
          if (failed && item.error.isNotEmpty) Text(item.error, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: KopitiamColors.danger)),
        ])),
        if (_needsUpdate.contains(item.key)) const Padding(padding: EdgeInsets.only(left: 6),
          child: Icon(Icons.update_rounded, color: KopitiamColors.warning, size: 18)),
        if (failed) TextButton(onPressed: _blocked ? null : () => _sync([item.key]), child: const Text('Coba Ulang')),
      ]),
    );
  }
}
