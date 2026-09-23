import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release build fails closed without signing configuration', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('isReleaseTask'));
    expect(gradle, contains('Release signing Kopitiam belum dikonfigurasi'));
    expect(gradle, contains('requiredReleaseSigningProperty'));
    expect(gradle, contains('isMinifyEnabled = true'));
    expect(gradle, contains('isShrinkResources = true'));
    expect(gradle, isNot(contains('storePassword = "')));
    expect(gradle, isNot(contains('keyPassword = "')));
  });

  test('Android backup and cleartext transport remain disabled', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });

  test('Flutter CI validates source, tests, and signing material before artifacts', () {
    final workflow = File('../.github/workflows/flutter-ci.yml').readAsStringSync();
    expect(workflow, contains('node ci/check-android-signing.cjs'));
    expect(workflow, contains('flutter analyze'));
    expect(workflow, contains('flutter test'));
    expect(workflow, contains('flutter build apk --debug'));
  });
}
