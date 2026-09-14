import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/services/sync_request_coordinator.dart';

void main() {
  test('only one sync request runs at a time', () async {
    var active = 0;
    var maximumActive = 0;
    final releases = <Completer<void>>[];
    final coordinator = SyncRequestCoordinator(
      minimumGap: Duration.zero,
      maximumGap: Duration.zero,
    );

    Future<int> request(int value) async {
      active++;
      maximumActive = max(maximumActive, active);
      final release = Completer<void>();
      releases.add(release);
      await release.future;
      active--;
      return value;
    }

    final first = coordinator.run(() => request(1));
    final second = coordinator.run(() => request(2));
    await Future<void>.delayed(Duration.zero);
    expect(releases.length, 1);
    releases.first.complete();
    expect(await first, 1);
    await Future<void>.delayed(Duration.zero);
    expect(releases.length, 2);
    releases.last.complete();
    expect(await second, 2);
    expect(maximumActive, 1);
  });

  test('next request waits between 8 and 12 seconds', () async {
    var now = DateTime.utc(2026, 9, 14, 5);
    final waits = <Duration>[];
    final coordinator = SyncRequestCoordinator(
      random: Random(7),
      clock: () => now,
      sleeper: (duration) async {
        waits.add(duration);
        now = now.add(duration);
      },
    );

    await coordinator.run(() async => 1);
    await coordinator.run(() async => 2);
    expect(waits, hasLength(1));
    expect(waits.single, greaterThanOrEqualTo(const Duration(seconds: 8)));
    expect(waits.single, lessThanOrEqualTo(const Duration(seconds: 12)));
  });

  test('failed request releases queue for the next sync', () async {
    final coordinator = SyncRequestCoordinator(
      minimumGap: Duration.zero,
      maximumGap: Duration.zero,
    );
    await expectLater(
      coordinator.run<void>(() async => throw StateError('failed')),
      throwsStateError,
    );
    expect(await coordinator.run(() async => 'next'), 'next');
  });
}
