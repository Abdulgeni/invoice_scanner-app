import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';

/// Where unexpected errors go. Implementations receive the error's TYPE NAME
/// and its stack trace only. The error's message is never passed on,
/// because a message from a third-party library could contain invoice text.
abstract interface class CrashReporter {
  void record({
    required String errorType,
    required StackTrace stack,
    required bool fatal,
  });
}

/// Default sink: drops everything. Swap in a real reporter (for example
/// Crashlytics) later; the contract above is what keeps it private.
final class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  void record({
    required String errorType,
    required StackTrace stack,
    required bool fatal,
  }) {}
}

/// Routes framework errors and uncaught async errors to [reporter].
///
/// - Framework errors are reported as non-fatal and, in debug builds, also
///   printed as usual ([presentInDebug]).
/// - Uncaught async errors are reported as fatal and marked handled so a
///   single failed task does not kill the app.
///
/// Returns a function that restores the previous handlers (for tests).
void Function() installErrorHandlers(
  CrashReporter reporter, {
  bool presentInDebug = kDebugMode,
  PlatformDispatcher? dispatcher,
}) {
  final PlatformDispatcher platform = dispatcher ?? PlatformDispatcher.instance;
  final FlutterExceptionHandler? previousFlutter = FlutterError.onError;
  final ErrorCallback? previousPlatform = platform.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    reporter.record(
      errorType: details.exception.runtimeType.toString(),
      stack: details.stack ?? StackTrace.empty,
      fatal: false,
    );
    if (presentInDebug) FlutterError.presentError(details);
  };
  platform.onError = (Object error, StackTrace stack) {
    reporter.record(
      errorType: error.runtimeType.toString(),
      stack: stack,
      fatal: true,
    );
    return true;
  };

  return () {
    FlutterError.onError = previousFlutter;
    platform.onError = previousPlatform;
  };
}
