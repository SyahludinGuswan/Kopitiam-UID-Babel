import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final int samples;
  final bool locked;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.samples,
    required this.locked,
  });

  String get coordinate =>
      '${latitude.toStringAsFixed(7)},${longitude.toStringAsFixed(7)}';

  String get accuracyLabel => '${accuracy.toStringAsFixed(1)} m';
}

class GnssStabilityTracker {
  final double maximumAccuracy;
  final double stabilityRadius;
  final int requiredSamples;
  final List<Position> _stable = <Position>[];
  Position? _best;

  GnssStabilityTracker({
    required this.maximumAccuracy,
    required this.stabilityRadius,
    required this.requiredSamples,
  });

  int get stableSamples => _stable.length;
  Position? get best => _best;
  bool get locked => _stable.length >= requiredSamples;

  bool add(Position position) {
    if (position.accuracy > maximumAccuracy) return false;
    if (_stable.isEmpty) {
      _stable.add(position);
      _best = position;
      return locked;
    }

    final anchor = _best!;
    final distance = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      position.latitude,
      position.longitude,
    );
    if (distance > stabilityRadius) {
      _stable
        ..clear()
        ..add(position);
      _best = position;
      return false;
    }

    _stable.add(position);
    if (position.accuracy < _best!.accuracy) _best = position;
    return locked;
  }
}

class HighAccuracyLocationService {
  static const double lockAccuracy = 20;
  static const double stabilityRadius = 10;
  static const int requiredStableSamples = 3;
  static const int maxSamples = 120;
  static const Duration maxDuration = Duration(minutes: 2);
  static const Duration maxPositionAge = Duration(seconds: 10);

  static Future<void> _ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Layanan lokasi perangkat belum aktif.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan aplikasi.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Izin lokasi belum diberikan untuk aplikasi ini.');
    }
  }

  static void _assertTrusted(Position position) {
    if (position.isMocked) {
      throw StateError(
        'Lokasi tiruan terdeteksi. Nonaktifkan Fake GPS atau aplikasi '
        'pengubah lokasi, lalu ambil koordinat ulang.',
      );
    }
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180 ||
        (position.latitude == 0 && position.longitude == 0) ||
        position.accuracy <= 0) {
      throw StateError('Data lokasi perangkat tidak valid.');
    }
    final age = DateTime.now().difference(position.timestamp);
    if (age > maxPositionAge || age < const Duration(minutes: -1)) {
      throw StateError(
        'Data GPS sudah kedaluwarsa atau waktu perangkat tidak valid.',
      );
    }
  }

  static Future<LocationFix> acquire({
    void Function(int sample, double bestAccuracy)? onSample,
  }) async {
    await _ensureReady();

    final tracker = GnssStabilityTracker(
      maximumAccuracy: lockAccuracy,
      stabilityRadius: stabilityRadius,
      requiredSamples: requiredStableSamples,
    );
    var totalSamples = 0;
    Object? securityError;
    final completer = Completer<void>();

    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    void consider(Position position) {
      try {
        _assertTrusted(position);
      } catch (error) {
        securityError = error;
        finish();
        return;
      }
      totalSamples++;
      final locked = tracker.add(position);
      final best = tracker.best;
      if (best != null) onSample?.call(tracker.stableSamples, best.accuracy);
      if (locked || totalSamples >= maxSamples) finish();
    }

    late final StreamSubscription<Position> subscription;
    late final Timer deadline;
    subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
      consider,
      onError: (_) => finish(),
      cancelOnError: false,
    );
    deadline = Timer(maxDuration, finish);

    try {
      await completer.future;
    } finally {
      deadline.cancel();
      await subscription.cancel();
    }

    if (securityError != null) throw securityError!;
    final best = tracker.best;
    if (best == null) {
      throw StateError(
        'GNSS belum mendapat akurasi 20 m. Coba lagi di area terbuka.',
      );
    }
    if (!tracker.locked) {
      throw StateError(
        'Koordinat belum stabil. Dibutuhkan 3 sampel dalam radius 10 m; '
        'coba ulang di area terbuka.',
      );
    }
    _assertTrusted(best);
    return _toFix(best, tracker.stableSamples);
  }

  static LocationFix _toFix(Position position, int samples) {
    _assertTrusted(position);
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
      samples: samples,
      locked: true,
    );
  }

  static double distanceKm(LocationFix start, LocationFix end) {
    return Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ) /
        1000;
  }
}
