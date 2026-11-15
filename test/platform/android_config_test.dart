@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android settings this app's privacy and release behavior
/// depend on. Runs from the project root, as `flutter test` does.
void main() {
  late String manifest;

  setUpAll(() {
    manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  bool declares(String permission) => RegExp(
        '<uses-permission[^>]*android\\.permission\\.$permission',
      ).hasMatch(manifest);

  test('release builds can reach the network', () {
    expect(declares('INTERNET'), isTrue,
        reason: 'debug builds add INTERNET by themselves; release builds do not');
    expect(declares('ACCESS_NETWORK_STATE'), isTrue);
  });

  test('the scanner can use the camera, but gallery import still works '
      'on devices without one', () {
    expect(declares('CAMERA'), isTrue);
    expect(
      RegExp(
        r'<uses-feature[^>]*android\.hardware\.camera"[^>]*android:required="false"',
      ).hasMatch(manifest),
      isTrue,
    );
  });

  test('nothing is backed up off the device', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, isNot(contains('android:allowBackup="true"')));
    expect(manifest, isNot(contains('dataExtractionRules')));
    expect(manifest, isNot(contains('fullBackupContent')));
  });

  test('cleartext traffic is off', () {
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });

  test('minSdk is 24', () {
    final File kts = File('android/app/build.gradle.kts');
    final File groovy = File('android/app/build.gradle');
    final String gradle =
        kts.existsSync() ? kts.readAsStringSync() : groovy.readAsStringSync();
    expect(RegExp(r'minSdk(Version)?\s*=?\s*24\b').hasMatch(gradle), isTrue);
  });
}
