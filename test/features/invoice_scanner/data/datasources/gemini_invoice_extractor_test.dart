import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/datasources/gemini_invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/gemini_debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/model_invoker.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/model_name_resolver.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

const String okJson =
    '{"isInvoiceOrReceipt": true, "vendorName": "Acme", '
    '"invoiceNumber": "A-1", "invoiceDate": "2026-11-01", "currency": "USD", '
    '"lineItems": [{"description": "Widget", "quantity": "2", '
    '"unitPrice": "5.00", "lineTotal": "10.00"}], '
    '"subtotal": "10.00", "tax": "1.00", "total": "11.00"}';
const GeminiRawResult okResult = GeminiRawResult(text: okJson);

typedef Step = Future<GeminiRawResult> Function();

class FakeInvoker {
  final List<Step> steps = <Step>[];
  final List<String> modelsSeen = <String>[];
  final List<List<String>> pagesSeen = <List<String>>[];

  int get calls => modelsSeen.length;

  Future<GeminiRawResult> call({
    required String modelName,
    required List<Uint8List> jpegPages,
  }) {
    modelsSeen.add(modelName);
    pagesSeen.add(jpegPages.map((Uint8List b) => utf8.decode(b)).toList());
    final Step step = steps.length > 1 ? steps.removeAt(0) : steps.first;
    return step();
  }
}

Matcher failure(InvoiceErrorKind kind, [String? code]) {
  return throwsA(
    isA<InvoiceFailure>()
        .having((InvoiceFailure f) => f.kind, 'kind', kind)
        .having(
          (InvoiceFailure f) => f.debugCode,
          'debugCode',
          code ?? anything,
        ),
  );
}

void main() {
  late FakeInvoker invoker;
  late List<Duration> sleeps;
  late CancellationToken cancel;

  setUp(() {
    invoker = FakeInvoker();
    sleeps = <Duration>[];
    cancel = CancellationToken();
  });

  GeminiInvoiceExtractor build({
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
    ModelNameResolver? models,
    Future<void> Function(Duration)? sleep,
    Future<Uint8List> Function(String)? readFile,
  }) {
    int n = 0;
    return GeminiInvoiceExtractor(
      invoker: invoker.call,
      models: models ?? ModelNameResolver(readRemote: () => null),
      newLineId: () => 'l${++n}',
      readFile:
          readFile ??
          (String path) async => Uint8List.fromList(utf8.encode(path)),
      sleep:
          sleep ??
          (Duration d) async {
            sleeps.add(d);
          },
      attemptTimeout: timeout,
      maxRetries: maxRetries,
    );
  }

  Future<Invoice> run(
    GeminiInvoiceExtractor extractor, {
    List<String> paths = const <String>['p1.jpg'],
    Currency fallback = Currency.usd,
  }) {
    return extractor.extract(
      imagePaths: paths,
      fallbackCurrency: fallback,
      cancel: cancel,
    );
  }

  Future<void> expectBlocked(
    GeminiRawResult raw,
    InvoiceErrorKind kind,
    String code,
  ) async {
    invoker.steps.add(() async => raw);
    await expectLater(run(build()), failure(kind, code));
    expect(invoker.calls, 1, reason: 'must not be retried');
  }

  group('success', () {
    test('sends pages in order and returns the parsed invoice', () async {
      invoker.steps.add(() async => okResult);
      final Invoice invoice = await run(
        build(),
        paths: <String>['a.jpg', 'b.jpg', 'c.jpg'],
      );
      expect(invoice.vendorName, 'Acme');
      expect(invoker.pagesSeen.single, <String>['a.jpg', 'b.jpg', 'c.jpg']);
      expect(invoker.modelsSeen.single, ModelNameResolver.defaultFallbackModel);
    });

    test('the fallback currency is used when the document has none', () async {
      invoker.steps.add(
        () async => const GeminiRawResult(text: '{"isInvoiceOrReceipt": true}'),
      );
      final Invoice invoice = await run(build(), fallback: Currency.jpy);
      expect(invoice.currency, Currency.jpy);
      expect(invoice.currencyAssumed, isTrue);
    });
  });

  group('inputs', () {
    test('zero or too many pages are rejected before any call', () async {
      await expectLater(
        run(build(), paths: const <String>[]),
        failure(InvoiceErrorKind.unknown, GeminiDebugCodes.badPageCount),
      );
      await expectLater(
        run(build(), paths: <String>['1', '2', '3', '4', '5', '6']),
        failure(InvoiceErrorKind.unknown, GeminiDebugCodes.badPageCount),
      );
      expect(invoker.calls, 0);
    });

    test('an unreadable or empty page fails without a call', () async {
      await expectLater(
        run(
          build(
            readFile: (String p) async => throw FileSystemException('x', p),
          ),
        ),
        failure(InvoiceErrorKind.unknown, DebugCodes.ioFailed),
      );
      await expectLater(
        run(build(readFile: (String p) async => Uint8List(0))),
        failure(InvoiceErrorKind.unknown, GeminiDebugCodes.pageEmpty),
      );
      expect(invoker.calls, 0);
    });
  });

  group('retry and timeout', () {
    test('transient failures are retried with exponential backoff', () async {
      invoker.steps.addAll(<Step>[
        () async => throw const SocketException('x'),
        () async => throw const SocketException('y'),
        () async => okResult,
      ]);
      final Invoice invoice = await run(build());
      expect(invoice.vendorName, 'Acme');
      expect(invoker.calls, 3);
      expect(sleeps, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('retries are bounded', () async {
      invoker.steps.add(() async => throw TimeoutException('x'));
      await expectLater(run(build()), failure(InvoiceErrorKind.timeout));
      expect(invoker.calls, 3);
      expect(sleeps, hasLength(2));
    });

    test('non-transient failures are never retried', () async {
      invoker.steps.add(() async => throw ServerException('429 quota'));
      await expectLater(
        run(build()),
        failure(InvoiceErrorKind.quotaExceeded, GeminiDebugCodes.quota),
      );
      expect(invoker.calls, 1);
      expect(sleeps, isEmpty);
    });

    test('each attempt has a timeout', () async {
      invoker.steps.add(() => Completer<GeminiRawResult>().future);
      await expectLater(
        run(build(maxRetries: 0, timeout: const Duration(milliseconds: 50))),
        failure(InvoiceErrorKind.timeout, GeminiDebugCodes.timeout),
      );
    });

    test('an Error from the SDK is mapped, not thrown raw', () async {
      invoker.steps.add(() async => throw StateError('sdk bug'));
      await expectLater(
        run(build()),
        failure(InvoiceErrorKind.unknown, DebugCodes.unexpected),
      );
      expect(invoker.calls, 1);
    });
  });

  group('model fallback', () {
    test('a missing model falls through to the next candidate', () async {
      final ModelNameResolver models = ModelNameResolver(
        readRemote: () => 'bad-model',
      );
      invoker.steps.addAll(<Step>[
        () async =>
            throw ServerException('models/bad-model is not found (404)'),
        () async => okResult,
      ]);
      final GeminiInvoiceExtractor extractor = build(models: models);

      await run(extractor);
      expect(invoker.modelsSeen, <String>[
        'bad-model',
        ModelNameResolver.defaultFallbackModel,
      ]);

      await run(extractor);
      expect(invoker.modelsSeen.last, ModelNameResolver.defaultFallbackModel);
      expect(
        invoker.modelsSeen.where((String m) => m == 'bad-model'),
        hasLength(1),
      );
    });

    test(
      'when every model is missing the error is model_unavailable',
      () async {
        final ModelNameResolver models = ModelNameResolver(
          readRemote: () => 'bad-model',
        );
        invoker.steps.add(
          () async => throw ServerException('model not found 404'),
        );
        await expectLater(
          run(build(models: models)),
          failure(InvoiceErrorKind.unknown, GeminiDebugCodes.modelUnavailable),
        );
        expect(invoker.calls, 2);
      },
    );
  });

  group('interpreting the response', () {
    test('a blocked prompt', () async {
      await expectBlocked(
        const GeminiRawResult(blockReason: 'safety'),
        InvoiceErrorKind.safetyBlock,
        GeminiDebugCodes.promptBlocked,
      );
    });

    test('blocked finish reasons', () async {
      for (final String reason in <String>['safety', 'recitation', 'spii']) {
        invoker.steps.clear();
        invoker.modelsSeen.clear();
        await expectBlocked(
          GeminiRawResult(text: okJson, finishReason: reason),
          InvoiceErrorKind.safetyBlock,
          GeminiDebugCodes.finishBlocked,
        );
      }
    });

    test('empty text', () async {
      await expectBlocked(
        const GeminiRawResult(text: '  '),
        InvoiceErrorKind.emptyResponse,
        GeminiDebugCodes.emptyText,
      );
    });

    test('a truncated response', () async {
      await expectBlocked(
        const GeminiRawResult(text: '{"isInv', finishReason: 'maxTokens'),
        InvoiceErrorKind.malformedJson,
        GeminiDebugCodes.truncated,
      );
    });

    test('invalid JSON', () async {
      await expectBlocked(
        const GeminiRawResult(text: 'Sure! Here is the invoice'),
        InvoiceErrorKind.malformedJson,
        GeminiDebugCodes.badJson,
      );
    });

    test('not an invoice', () async {
      await expectBlocked(
        const GeminiRawResult(text: '{"isInvoiceOrReceipt": false}'),
        InvoiceErrorKind.notAnInvoice,
        GeminiDebugCodes.notInvoice,
      );
    });
  });

  group('cancellation', () {
    test('a token cancelled up front never calls the model', () async {
      invoker.steps.add(() async => okResult);
      cancel.cancel();
      await expectLater(run(build()), throwsA(isA<CancelledException>()));
      expect(invoker.calls, 0);
    });

    test('cancelling during the call stops waiting', () async {
      final Completer<GeminiRawResult> gate = Completer<GeminiRawResult>();
      invoker.steps.add(() => gate.future);
      final Future<Invoice> pending = run(build());
      await pumpEventQueue();
      expect(invoker.calls, 1);

      cancel.cancel();
      await expectLater(pending, throwsA(isA<CancelledException>()));
      gate.complete(okResult);
      await pumpEventQueue();
    });

    test('cancelling during backoff stops the retry', () async {
      invoker.steps.add(() async => throw const SocketException('x'));
      final Future<Invoice> pending = run(
        build(
          sleep: (Duration d) {
            sleeps.add(d);
            return Completer<void>().future;
          },
        ),
      );
      await pumpEventQueue();
      expect(sleeps, <Duration>[const Duration(seconds: 1)]);

      cancel.cancel();
      await expectLater(pending, throwsA(isA<CancelledException>()));
      expect(invoker.calls, 1);
    });
  });
}
