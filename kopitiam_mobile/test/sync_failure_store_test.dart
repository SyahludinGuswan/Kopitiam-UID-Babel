import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopitiam_mobile/services/sync_failure_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fallback schedules 15 minutes, 1 hour, then 24-hour checkpoint', () async {
    final start = DateTime.utc(2026, 9, 16, 1);
    final first = await SyncFailureStore.recordFailure(
      owner: 'user.a', action: 'syncWoRow', kodeWo: 'WO-1',
      error: 'timeout', snapshotDigest: 'digest-a', now: start,
    );
    expect(first.nextAttemptAt, start.add(const Duration(minutes: 15)));
    final second = await SyncFailureStore.recordFailure(
      owner: 'user.a', action: 'syncWoRow', kodeWo: 'WO-1',
      error: 'timeout', snapshotDigest: 'digest-a',
      now: start.add(const Duration(minutes: 15)),
    );
    expect(second.nextAttemptAt, start.add(const Duration(minutes: 75)));
    final third = await SyncFailureStore.recordFailure(
      owner: 'user.a', action: 'syncWoRow', kodeWo: 'WO-1',
      error: 'timeout', snapshotDigest: 'digest-a',
      now: start.add(const Duration(minutes: 75)),
    );
    expect(third.nextAttemptAt, start.add(const Duration(hours: 24)));
  });

  test('failure state is isolated by verified account', () async {
    final now = DateTime.utc(2026, 9, 16);
    await SyncFailureStore.recordFailure(
      owner: 'user.a', action: 'syncWoRow', kodeWo: 'WO-1',
      error: 'timeout', snapshotDigest: 'digest-a', now: now,
    );
    expect(await SyncFailureStore.read('user.a', 'syncWoRow', 'WO-1'), isNotNull);
    expect(await SyncFailureStore.read('user.b', 'syncWoRow', 'WO-1'), isNull);
  });

  test('changed snapshot starts a fresh retry cycle', () async {
    final start = DateTime.utc(2026, 9, 16);
    await SyncFailureStore.recordFailure(
      owner: 'user.a', action: 'syncWoRow', kodeWo: 'WO-1',
      error: 'bad data', snapshotDigest: 'old', now: start,
      retryable: false,
    );
    final reset = await SyncFailureStore.recordFailure(
      owner: 'user.a', action: 'syncWoRow', kodeWo: 'WO-1',
      error: 'timeout', snapshotDigest: 'new',
      now: start.add(const Duration(minutes: 1)),
    );
    expect(reset.status, SyncFailureStore.retryableFailed);
    expect(reset.retryCycle, 0);
  });

  test('explicit clear unlocks manual-action-required state', () async {
    final now = DateTime.utc(2026, 9, 16);
    await SyncFailureStore.recordFailure(
      owner: 'user.a', action: 'syncWoHarJar', kodeWo: 'WO-2',
      error: 'folder mismatch', snapshotDigest: 'digest', now: now,
      retryable: false,
    );
    expect((await SyncFailureStore.read('user.a', 'syncWoHarJar', 'WO-2'))!.manualActionRequired, isTrue);
    await SyncFailureStore.clear('user.a', 'syncWoHarJar', 'WO-2');
    expect(await SyncFailureStore.read('user.a', 'syncWoHarJar', 'WO-2'), isNull);
  });

  test('empty owner fails closed', () async {
    await expectLater(
      SyncFailureStore.read('', 'syncWoRow', 'WO-1'),
      throwsA(isA<StateError>()),
    );
  });
}
