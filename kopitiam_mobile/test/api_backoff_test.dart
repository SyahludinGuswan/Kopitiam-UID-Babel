import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/services/api_backoff.dart';

void main() {
  test('only SERVER_BUSY is retried and retry count is bounded', () {
    expect(ApiBackoff.shouldRetry({'success': false, 'kode': 'SERVER_BUSY'}, 0), isTrue);
    expect(ApiBackoff.shouldRetry({'success': false, 'kode': 'SERVER_BUSY'}, 3), isFalse);
    expect(ApiBackoff.shouldRetry({'success': false, 'kode': 'WO_INVALID'}, 0), isFalse);
    expect(ApiBackoff.shouldRetry({'success': true}, 0), isFalse);
  });

  test('backoff uses 2, 4, 8 seconds plus bounded jitter', () {
    expect(ApiBackoff.delayFor(retryCount: 0, jitterMilliseconds: 250), const Duration(milliseconds: 2250));
    expect(ApiBackoff.delayFor(retryCount: 1), const Duration(seconds: 4));
    expect(ApiBackoff.delayFor(retryCount: 2), const Duration(seconds: 8));
  });

  test('server retry hint wins but is capped at 60 seconds', () {
    expect(ApiBackoff.delayFor(retryCount: 0, retryAfterSeconds: 17), const Duration(seconds: 17));
    expect(ApiBackoff.delayFor(retryCount: 0, retryAfterSeconds: 999), const Duration(seconds: 60));
  });
}
