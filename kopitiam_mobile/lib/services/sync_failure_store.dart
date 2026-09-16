import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncFailureState {
  final String status;
  final int retryCycle;
  final DateTime firstFailedAt;
  final DateTime lastAttemptAt;
  final DateTime? nextAttemptAt;
  final String error;

  const SyncFailureState({
    required this.status,
    required this.retryCycle,
    required this.firstFailedAt,
    required this.lastAttemptAt,
    required this.nextAttemptAt,
    required this.error,
  });

  bool get manualActionRequired => status == 'manual-action-required';
  bool due(DateTime now) => !manualActionRequired &&
      (nextAttemptAt == null || !nextAttemptAt!.isAfter(now));

  Map<String, dynamic> toJson() => {
        'status': status,
        'retryCycle': retryCycle,
        'firstFailedAt': firstFailedAt.toUtc().toIso8601String(),
        'lastAttemptAt': lastAttemptAt.toUtc().toIso8601String(),
        'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
        'error': error,
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
    );
  }
}

class SyncFailureStore {
  static const _prefix = 'wo_sync_failure_v1_';
  static const retryableFailed = 'retryable-failed';
  static const manualActionRequired = 'manual-action-required';

  static String _key(String action, String kodeWo) =>
      '$_prefix${Uri.encodeComponent(action)}_${Uri.encodeComponent(kodeWo)}';

  static Future<SyncFailureState?> read(String action, String kodeWo) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(action, kodeWo));
    if (raw == null || raw.isEmpty) return null;
    try {
      return SyncFailureState.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String action, String kodeWo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(action, kodeWo));
  }

  static Future<SyncFailureState> recordFailure({
    required String action,
    required String kodeWo,
    required String error,
    required DateTime now,
    bool retryable = true,
  }) async {
    final previous = await read(action, kodeWo);
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
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(action, kodeWo), jsonEncode(state.toJson()));
    return state;
  }
}
