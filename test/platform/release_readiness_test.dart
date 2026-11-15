@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Run before a release: RELEASE_CHECK=true flutter test test/platform
/// Skipped otherwise, because it fails until Firebase is configured.
void main() {
  final bool enabled = Platform.environment['RELEASE_CHECK'] == 'true';
  final Object skip = enabled ? false : 'set RELEASE_CHECK=true to run';

  test('Firebase options are real, not the placeholder', () {
    final String options = File('lib/firebase_options.dart').readAsStringSync();
    expect(options, isNot(contains('Firebase is not configured')));
  }, skip: skip);

  test('the Android Firebase config is present', () {
    expect(File('android/app/google-services.json').existsSync(), isTrue);
  }, skip: skip);

  test('the application id is not the example one', () {
    final File kts = File('android/app/build.gradle.kts');
    final String gradle = kts.existsSync()
        ? kts.readAsStringSync()
        : File('android/app/build.gradle').readAsStringSync();
    expect(gradle, isNot(contains('com.example')));
  }, skip: skip);
}
