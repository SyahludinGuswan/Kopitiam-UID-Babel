import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS declares only the permissions used by the mobile app', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>NSCameraUsageDescription</key>'));
    expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
    expect(plist, contains('<key>NSPhotoLibraryAddUsageDescription</key>'));
    expect(plist, contains('mengambil foto bukti inspeksi'));
    expect(plist, contains('posisi inspeksi'));
    expect(plist, contains('memilih foto bukti inspeksi'));
    expect(plist, contains('menyimpan foto bukti inspeksi'));

    expect(plist, isNot(contains('NSLocationAlwaysUsageDescription')));
    expect(plist, isNot(contains('UIBackgroundModes')));
  });
}
