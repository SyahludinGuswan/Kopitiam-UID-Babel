import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopitiam_mobile/services/sync_failure_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fallback schedules 15 minutes, then 1 hour, then 24-hour checkpoint', () async {
    final start = DateTime.utc(2026, 9, 16, 1);
    final first = await SyncFailureStore.recordFailure(
      action: 'syncWoRow', kodeWo: 'WO-1', error: 'timeout', now: start,
    );
    expect(first.status, SyncFailureStore.retryableFailed);
    expect(first.nextAttemptAt, start.add(const Duration(minutes: 15)));

    final second = await SyncFailureStore.recordFailure(
      action: 'syncWoRow', kodeWo: 'WO-1', error: 'timeout', now: start.add(const Duration(minutes: 15)),
    );
    expect(second.nextAttemptAt, start.add(const Duration(minutes: 75)));

    final third = await SyncFailureStore.recordFailure(
      action: 'syncWoRow', kodeWo: 'WO-1', error: 'timeout', now: start.add(const Duration(minutes: 75)),
    );
    expect(third.nextAttemptAt, start.add(const Duration(hours: 24)));
  });

  test('failure after 24 hours requires manual action', () async {
    final start = DateTime.utc(2026, 9, 16, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'wo_sync_failure_v1_syncWoRow_WO-1',
      jsonEncode({
        'status': 'retryable-failed',
        'retryCycle': 2,
        'firstFailedAt': start.toIso8601String(),
        'lastAttemptAt': start.toIso8601String(),
        'nextAttemptAt': start.add(const Duration(hours: 24)).toIso8601String(),
        'error': 'timeout',
      }),
    );
    final state = await SyncFailureStore.recordFailure(
      action: 'syncWoRow', kodeWo: 'WO-1', error: 'still failing', now: start.add(const Duration(hours: 24)),
    );
    expect(state.status, SyncFailureStore.manualActionRequired);
    expect(state.nextAttemptAt, isNull);
  });

  test('non-retryable validation failure requests manual action immediately', () async {
    final state = await SyncFailureStore.recordFailure(
      action: 'syncWoHarJar',
      kodeWo: 'WO-2',
      error: 'folder mismatch',
      now: DateTime.utc(2026, 9, 16),
      retryable: false,
    );
    expect(state.status, SyncFailureStore.manualActionRequired);
  });
}
