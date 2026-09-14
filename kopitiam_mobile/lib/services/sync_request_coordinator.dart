import 'dart:async';
import 'dart:math';

typedef SyncSleeper = Future<void> Function(Duration duration);
typedef SyncClock = DateTime Function();

class SyncRequestCoordinator {
  final Duration minimumGap;
  final Duration maximumGap;
  final Random random;
  final SyncSleeper sleeper;
  final SyncClock clock;

  Future<void> _tail = Future<void>.value();
  DateTime? _lastCompletedAt;

  SyncRequestCoordinator({
    this.minimumGap = const Duration(seconds: 8),
    this.maximumGap = const Duration(seconds: 12),
    Random? random,
    SyncSleeper? sleeper,
    SyncClock? clock,
  })  : assert(!maximumGap.isNegative),
        assert(!minimumGap.isNegative),
        assert(maximumGap >= minimumGap),
        random = random ?? Random.secure(),
        sleeper = sleeper ?? Future<void>.delayed,
        clock = clock ?? DateTime.now;

  Duration nextGap() {
    final range = maximumGap.inMilliseconds - minimumGap.inMilliseconds;
    if (range <= 0) return minimumGap;
    return Duration(
      milliseconds: minimumGap.inMilliseconds + random.nextInt(range + 1),
    );
  }

  Future<T> run<T>(Future<T> Function() request) async {
    final turn = Completer<void>();
    final previous = _tail;
    _tail = turn.future;
    await previous.catchError((_) {});

    try {
      final last = _lastCompletedAt;
      if (last != null) {
        final target = last.add(nextGap());
        final wait = target.difference(clock());
        if (wait.isNegative == false && wait > Duration.zero) {
          await sleeper(wait);
        }
      }
      return await request();
    } finally {
      _lastCompletedAt = clock();
      if (!turn.isCompleted) turn.complete();
    }
  }
}
