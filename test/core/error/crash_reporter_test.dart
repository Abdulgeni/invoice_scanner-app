
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/error/crash_reporter.dart';

class RecordingReporter implements CrashReporter {
  final List<(String, bool)> events = <(String, bool)>[];

  @override
  void record({
    required String errorType,
    required StackTrace stack,
    required bool fatal,
  }) {
    events.add((errorType, fatal));
  }
}

void main() {
  late RecordingReporter reporter;
  late void Function() restore;

  setUp(() {
    reporter = RecordingReporter();
    restore = installErrorHandlers(reporter, presentInDebug: false);
  });

  tearDown(() => restore());

  test('framework errors are recorded by type as non-fatal', () {
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('vendor ACME total 12.50'),
        stack: StackTrace.current,
      ),
    );
    expect(reporter.events, <(String, bool)>[('StateError', false)]);
  });

  test('uncaught async errors are recorded as fatal and handled', () {
    final bool handled = PlatformDispatcher.instance.onError!(
      ArgumentError('vendor ACME total 12.50'),
      StackTrace.current,
    );
    expect(handled, isTrue);
    expect(reporter.events, <(String, bool)>[('ArgumentError', true)]);
  });

  test('message text never reaches the reporter', () {
    FlutterError.onError!(
      FlutterErrorDetails(exception: Exception('ACME 12.50')),
    );
    expect(reporter.events.toString(), isNot(contains('ACME')));
    expect(reporter.events.toString(), isNot(contains('12.50')));
  });

  test('a missing stack trace is tolerated', () {
    FlutterError.onError!(const FlutterErrorDetails(exception: 'a plain string'));
    expect(reporter.events.single, ('String', false));
  });

  test('restoring puts the previous handlers back', () {
    final FlutterExceptionHandler? installed = FlutterError.onError;
    restore();
    expect(FlutterError.onError, isNot(same(installed)));
    restore = installErrorHandlers(reporter, presentInDebug: false);
  });

  test('the no-op reporter accepts everything', () {
    const NoopCrashReporter().record(
      errorType: 'X',
      stack: StackTrace.empty,
      fatal: true,
    );
  });
}
