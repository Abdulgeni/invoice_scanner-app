import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';

import 'package:invoice_scanner/features/invoice_scanner/data/gemini/gemini_debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

final class ClassifiedError {
  const ClassifiedError(
    this.kind,
    this.debugCode, {
    this.modelNotFound = false,
  });

  final InvoiceErrorKind kind;

  /// Always a [GeminiDebugCodes] or [DebugCodes] value, never message text.
  final String debugCode;

  /// The requested model does not exist (or no longer does). The caller
  /// should try another candidate instead of surfacing an error.
  final bool modelNotFound;
}

/// Maps anything thrown by the model call to one taxonomy kind.
///
/// `ServerException` carries only a message string, so server errors are
/// classified by searching that text for status words and codes. The text is
/// inspected here and never stored, logged, or copied into a result.
ClassifiedError classifyGeminiError(Object error) {
  if (error is TimeoutException) {
    return const ClassifiedError(
      InvoiceErrorKind.timeout,
      GeminiDebugCodes.timeout,
    );
  }
  if (error is IOException) {
    return const ClassifiedError(
      InvoiceErrorKind.network,
      GeminiDebugCodes.ioError,
    );
  }
  if (error is QuotaExceeded) {
    return const ClassifiedError(
      InvoiceErrorKind.quotaExceeded,
      GeminiDebugCodes.quota,
    );
  }
  if (error is InvalidApiKey) {
    return const ClassifiedError(
      InvoiceErrorKind.unknown,
      GeminiDebugCodes.configInvalidKey,
    );
  }
  if (error is ServiceApiNotEnabled) {
    return const ClassifiedError(
      InvoiceErrorKind.unknown,
      GeminiDebugCodes.configApiDisabled,
    );
  }
  if (error is UnsupportedUserLocation) {
    return const ClassifiedError(
      InvoiceErrorKind.unknown,
      GeminiDebugCodes.unsupportedLocation,
    );
  }
  if (error is FirebaseAISdkException) {
    return const ClassifiedError(
      InvoiceErrorKind.unknown,
      GeminiDebugCodes.sdkError,
    );
  }
  if (error is ServerException) return _classifyServerMessage(error.message);
  if (error is FirebaseAIException) {
    return const ClassifiedError(
      InvoiceErrorKind.unknown,
      GeminiDebugCodes.aiError,
    );
  }
  // package:http's ClientException (a network-level failure) is not a direct
  // dependency, so it is recognized by name.
  if (error.runtimeType.toString() == 'ClientException') {
    return const ClassifiedError(
      InvoiceErrorKind.network,
      GeminiDebugCodes.clientError,
    );
  }
  return const ClassifiedError(InvoiceErrorKind.unknown, DebugCodes.unexpected);
}

final RegExp _status429 = RegExp(r'\b429\b');
final RegExp _statusAuth = RegExp(r'\b(401|403)\b');
final RegExp _status404 = RegExp(r'\b404\b');
final RegExp _status5xx = RegExp(r'\b(500|502|503|504)\b');

ClassifiedError _classifyServerMessage(String message) {
  final String m = message.toLowerCase();
  bool has(List<String> words) => words.any(m.contains);

  if (_status429.hasMatch(m) ||
      has(<String>[
        'quota',
        'resource_exhausted',
        'resource exhausted',
        'rate limit',
        'too many requests',
      ])) {
    return const ClassifiedError(
      InvoiceErrorKind.quotaExceeded,
      GeminiDebugCodes.quota,
    );
  }
  if (_statusAuth.hasMatch(m) ||
      has(<String>[
        'app check',
        'appcheck',
        'app_check',
        'unauthenticated',
        'permission_denied',
        'permission denied',
      ])) {
    return const ClassifiedError(
      InvoiceErrorKind.appCheckFailed,
      GeminiDebugCodes.authRejected,
    );
  }
  if ((_status404.hasMatch(m) || m.contains('not found')) &&
      m.contains('model')) {
    return const ClassifiedError(
      InvoiceErrorKind.unknown,
      GeminiDebugCodes.modelUnavailable,
      modelNotFound: true,
    );
  }
  if (_status5xx.hasMatch(m) ||
      has(<String>[
        'unavailable',
        'overloaded',
        'internal',
        'deadline',
        'timed out',
        'timeout',
      ])) {
    return const ClassifiedError(
      InvoiceErrorKind.timeout,
      GeminiDebugCodes.serverUnavailable,
    );
  }
  return const ClassifiedError(
    InvoiceErrorKind.unknown,
    GeminiDebugCodes.serverError,
  );
}
