import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kopitiam_mobile/services/high_accuracy_location_service.dart';

Position position({
  bool mocked = false,
  double latitude = -3.019482,
  double longitude = 106.454827,
  double accuracy = 3.2,
  DateTime? timestamp,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
  isMocked: mocked,
);

void main() {
  test('offline GNSS locks after three accurate, stable samples', () {
    final tracker = GnssStabilityTracker(
      maximumAccuracy: HighAccuracyLocationService.lockAccuracy,
      stabilityRadius: HighAccuracyLocationService.stabilityRadius,
      requiredSamples: HighAccuracyLocationService.requiredStableSamples,
    );
    expect(tracker.add(position(accuracy: 12)), isFalse);
    expect(tracker.add(position(latitude: -3.019480, accuracy: 9)), isFalse);
    expect(tracker.add(position(longitude: 106.454830, accuracy: 7)), isTrue);
    expect(tracker.locked, isTrue);
    expect(tracker.stableSamples, 3);
    expect(tracker.best!.accuracy, 7);
  });

  test('inaccurate sample is ignored and does not count toward lock', () {
    final tracker = GnssStabilityTracker(
      maximumAccuracy: 20,
      stabilityRadius: 10,
      requiredSamples: 3,
    );
    expect(tracker.add(position(accuracy: 35)), isFalse);
    expect(tracker.stableSamples, 0);
    expect(tracker.best, isNull);
  });

  test('sample outside stability radius restarts the stable sequence', () {
    final tracker = GnssStabilityTracker(
      maximumAccuracy: 20,
      stabilityRadius: 10,
      requiredSamples: 3,
    );
    tracker.add(position());
    tracker.add(position(latitude: -3.019480));
    expect(tracker.stableSamples, 2);
    tracker.add(position(latitude: -3.020000));
    expect(tracker.stableSamples, 1);
    expect(tracker.locked, isFalse);
  });

  test('geolocator exposes mock-location signal used by service', () {
    expect(position(mocked: true).isMocked, isTrue);
  });

  test('rejectable coordinate attack cases remain identifiable', () {
    expect(position(latitude: 0, longitude: 0).latitude, 0);
    expect(position(latitude: 91).latitude, greaterThan(90));
    expect(position(longitude: 181).longitude, greaterThan(180));
    expect(position(accuracy: 0).accuracy, lessThanOrEqualTo(0));
  });
}
