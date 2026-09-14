import 'dart:math';

class ApiBackoff {
  static const int maxRetries = 3;
  static const Duration maximumDelay = Duration(seconds: 60);

  static bool shouldRetry(Map<String, dynamic> response, int retryCount) =>
      response['success'] != true &&
      response['kode'] == 'SERVER_BUSY' &&
      retryCount < maxRetries;

  static Duration delayFor({
    required int retryCount,
    Object? retryAfterSeconds,
    int jitterMilliseconds = 0,
  }) {
    final serverSeconds = retryAfterSeconds is num
        ? retryAfterSeconds.ceil()
        : int.tryParse('$retryAfterSeconds');
    final exponentialSeconds = 2 << retryCount;
    final seconds = max(serverSeconds ?? 0, exponentialSeconds)
        .clamp(1, maximumDelay.inSeconds);
    return Duration(
      seconds: seconds,
      milliseconds: jitterMilliseconds.clamp(0, 1000),
    );
  }
}
