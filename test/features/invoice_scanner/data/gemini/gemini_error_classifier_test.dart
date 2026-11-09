import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/gemini_debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/gemini_error_classifier.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

ClassifiedError server(String message) =>
    classifyGeminiError(ServerException(message));

void main() {
  group('network and timeouts', () {
    test('socket, http and timeout errors', () {
      expect(
        classifyGeminiError(const SocketException('x')).kind,
        InvoiceErrorKind.network,
      );
      expect(
        classifyGeminiError(const HttpException('x')).kind,
        InvoiceErrorKind.network,
      );
      expect(
        classifyGeminiError(TimeoutException('x')).kind,
        InvoiceErrorKind.timeout,
      );
    });
  });

  group('server messages', () {
    test('quota and rate limits', () {
      for (final String m in <String>[
        '429 Too Many Requests',
        'Resource has been exhausted (e.g. check quota).',
        'RESOURCE_EXHAUSTED',
        'rate limit hit',
      ]) {
        expect(server(m).kind, InvoiceErrorKind.quotaExceeded, reason: m);
      }
    });

    test('authentication and App Check rejections', () {
      for (final String m in <String>[
        'Firebase App Check token is invalid.',
        'Error 403: forbidden',
        'UNAUTHENTICATED: request has no credentials',
        'PERMISSION_DENIED',
      ]) {
        expect(server(m).kind, InvoiceErrorKind.appCheckFailed, reason: m);
      }
    });

    test('a missing model triggers fallback, not an error kind', () {
      final ClassifiedError c = server(
        'models/foo-1 is not found for API version v1 (404)',
      );
      expect(c.modelNotFound, isTrue);
      expect(c.debugCode, GeminiDebugCodes.modelUnavailable);
      expect(server('404 resource not found').modelNotFound, isFalse);
    });

    test('server-side failures are transient', () {
      for (final String m in <String>[
        '500 Internal error',
        '503 The model is overloaded',
        'Service unavailable',
        'Deadline exceeded',
        '504',
      ]) {
        final ClassifiedError c = server(m);
        expect(c.kind, InvoiceErrorKind.timeout, reason: m);
        expect(c.kind.isTransient, isTrue);
      }
    });

    test('status numbers inside other numbers are not matched', () {
      expect(server('request id 15031 failed').kind, InvoiceErrorKind.unknown);
      expect(server('something else').debugCode, GeminiDebugCodes.serverError);
    });

    test('quota wins over a 5xx word in the same message', () {
      expect(
        server('429 service unavailable').kind,
        InvoiceErrorKind.quotaExceeded,
      );
    });
  });

  group('everything else', () {
    test('unknown errors map to unknown/unexpected', () {
      for (final Object e in <Object>[
        StateError('x'),
        ArgumentError('x'),
        const FormatException('x'),
      ]) {
        final ClassifiedError c = classifyGeminiError(e);
        expect(c.kind, InvoiceErrorKind.unknown);
        expect(c.debugCode, DebugCodes.unexpected);
      }
    });

    test('debug codes never contain message text', () {
      const String secret = 'vendor-ACME-total-1234.50';
      final RegExp vocabulary = RegExp(r'^[a-z0-9_]+$');
      for (final Object e in <Object>[
        ServerException('429 $secret'),
        ServerException('503 $secret'),
        ServerException('403 $secret'),
        ServerException('model $secret not found 404'),
        ServerException(secret),
        StateError(secret),
        TimeoutException(secret),
        const SocketException(secret),
      ]) {
        final ClassifiedError c = classifyGeminiError(e);
        expect(c.debugCode, matches(vocabulary));
        expect(c.debugCode, isNot(contains('acme')));
        expect(c.debugCode, isNot(contains('1234')));
      }
    });
  });
}
