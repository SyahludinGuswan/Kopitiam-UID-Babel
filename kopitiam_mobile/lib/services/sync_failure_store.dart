import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncFailureState {
  final String status;
  final int retryCycle;
  final DateTime firstFailedAt;
  final DateTime lastAttemptAt;
  final DateTime? nextAttemptAt;
  final String error;
  final String snapshotDigest;

  const SyncFailureState({
    required this.status,
    required this.retryCycle,
    required this.firstFailedAt,
    required this.lastAttemptAt,
    required this.nextAttemptAt,
    required this.error,
    required this.snapshotDigest,
  });

  bool get manualActionRequired => status == 'manual-action-required';
  bool due(DateTime now) => !manualActionRequired &&
      (nextAttemptAt == null || !nextAttemptAt!.isAfter(now));
  bool matchesSnapshot(String digest) =>
      snapshotDigest.isNotEmpty && snapshotDigest == digest;

  Map<String, dynamic> toJson() => {
        'status': status,
        'retryCycle': retryCycle,
        'firstFailedAt': firstFailedAt.toUtc().toIso8601String(),
        'lastAttemptAt': lastAttemptAt.toUtc().toIso8601String(),
        'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
        'error': error,
        'snapshotDigest': snapshotDigest,
      };

  static SyncFailureState? fromJson(Object? value) {
    if (value is! Map) return null;
    final first = DateTime.tryParse('${value['firstFailedAt'] ?? ''}');
    final last = DateTime.tryParse('${value['lastAttemptAt'] ?? ''}');
    if (first == null || last == null) return null;
    final nextValue = '${value['nextAttemptAt'] ?? ''}';
    return SyncFailureState(
      status: '${value['status'] ?? 'retryable-failed'}',
      retryCycle: (value['retryCycle'] as num?)?.toInt() ?? 0,
      firstFailedAt: first,
      lastAttemptAt: last,
      nextAttemptAt: nextValue.isEmpty ? null : DateTime.tryParse(nextValue),
      error: '${value['error'] ?? ''}',
      snapshotDigest: '${value['snapshotDigest'] ?? ''}',
    );
  }
}

class SyncFailureStore {
  static const _prefix = 'wo_sync_failure_v2_';
  static const retryableFailed = 'retryable-failed';
  static const manualActionRequired = 'manual-action-required';

  static String _part(String value) => Uri.encodeComponent(value.trim().toLowerCase());
  static String _key(String owner, String action, String kodeWo) =>
      '$_prefix${_part(owner)}_${_part(action)}_${_part(kodeWo)}';

  static void _requireOwner(String owner) {
    if (owner.trim().isEmpty) {
      throw StateError('Akun terverifikasi wajib tersedia untuk status sinkron.');
    }
  }

  static Future<SyncFailureState?> read(
    String owner,
    String action,
    String kodeWo,
  ) async {
    _requireOwner(owner);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(owner, action, kodeWo));
    if (raw == null || raw.isEmpty) return null;
    try {
      return SyncFailureState.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(
    String owner,
    String action,
    String kodeWo,
  ) async {
    _requireOwner(owner);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(owner, action, kodeWo));
  }

  static Future<SyncFailureState> recordFailure({
    required String owner,
    required String action,
    required String kodeWo,
    required String error,
    required String snapshotDigest,
    required DateTime now,
    bool retryable = true,
  }) async {
    _requireOwner(owner);
    final old = await read(owner, action, kodeWo);
    final previous = old != null && old.matchesSnapshot(snapshotDigest) ? old : null;
    final first = previous?.firstFailedAt ?? now;
    final cycle = (previous?.retryCycle ?? -1) + 1;
    final age = now.difference(first);
    late final SyncFailureState state;
    if (!retryable || (cycle >= 3 && age >= const Duration(hours: 24))) {
      state = SyncFailureState(
        status: manualActionRequired,
        retryCycle: cycle,
        firstFailedAt: first,
        lastAttemptAt: now,
        nextAttemptAt: null,
        error: error,
        snapshotDigest: snapshotDigest,
      );
    } else {
      final next = cycle == 0
          ? now.add(const Duration(minutes: 15))
          : cycle == 1
              ? now.add(const Duration(hours: 1))
              : first.add(const Duration(hours: 24));
      state = SyncFailureState(
        status: retryableFailed,
        retryCycle: cycle,
        firstFailedAt: first,
        lastAttemptAt: now,
        nextAttemptAt: next.isAfter(now) ? next : now,
        error: error,
        snapshotDigest: snapshotDigest,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(owner, action, kodeWo),
      jsonEncode(state.toJson()),
    );
    return state;
  }
}
