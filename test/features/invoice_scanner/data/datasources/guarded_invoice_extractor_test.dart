import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/datasources/guarded_invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/usage/daily_usage_counter.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

import '../../../../support/fakes.dart';

class RecordingExtractor implements InvoiceExtractor {
  RecordingExtractor(this.log);

  final List<String> log;
  Object? error;

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    log.add('call');
    final Object? e = error;
    if (e != null) throw e;
    return sampleInvoice();
  }
}

Matcher failure(InvoiceErrorKind kind, String code) => throwsA(
  isA<InvoiceFailure>()
      .having((InvoiceFailure f) => f.kind, 'kind', kind)
      .having((InvoiceFailure f) => f.debugCode, 'debugCode', code),
);

void main() {
  late Directory temp;
  late DailyUsageCounter counter;
  late List<String> log;
  late RecordingExtractor inner;
  late Object? authError;
  late CancellationToken cancel;

  InvoiceExtractor build({int cap = 2}) {
    return AuthGatedInvoiceExtractor(
      inner: CappedInvoiceExtractor(inner: inner, counter: counter, cap: cap),
      ensureSignedIn: () async {
        log.add('auth');
        final Object? e = authError;
        if (e != null) throw e;
      },
    );
  }

  Future<Invoice> run(InvoiceExtractor e) => e.extract(
    imagePaths: const <String>['p.jpg'],
    fallbackCurrency: Currency.usd,
    cancel: cancel,
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('guard_test');
    counter = DailyUsageCounter(
      file: File('${temp.path}${Platform.pathSeparator}u.json'),
      clock: () => DateTime.utc(2026, 11, 8, 10),
    );
    log = <String>[];
    inner = RecordingExtractor(log);
    authError = null;
    cancel = CancellationToken();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('signs in first, then calls the model', () async {
    expect(await run(build()), sampleInvoice());
    expect(log, <String>['auth', 'call']);
  });

  test('stops at the daily cap without calling the model', () async {
    final InvoiceExtractor e = build();
    await run(e);
    await run(e);
    log.clear();
    await expectLater(
      run(e),
      failure(InvoiceErrorKind.quotaExceeded, GuardDebugCodes.dailyCap),
    );
    expect(log, <String>['auth']);
    expect(await counter.countToday(), 2);
  });

  test('a failed read still uses a unit of the cap', () async {
    inner.error = const InvoiceFailure(InvoiceErrorKind.malformedJson);
    final InvoiceExtractor e = build();
    await expectLater(run(e), throwsA(isA<InvoiceFailure>()));
    expect(await counter.countToday(), 1);
  });

  test('a network failure gives the unit back', () async {
    inner.error = const InvoiceFailure(InvoiceErrorKind.network);
    final InvoiceExtractor e = build(cap: 1);
    await expectLater(run(e), throwsA(isA<InvoiceFailure>()));
    expect(await counter.countToday(), 0);

    inner.error = null;
    await run(e);
    expect(await counter.countToday(), 1);
  });

  test('a sign-in failure never uses the cap or reaches the model', () async {
    authError = const InvoiceFailure(InvoiceErrorKind.network, debugCode: 'a');
    await expectLater(run(build()), throwsA(isA<InvoiceFailure>()));
    expect(log, <String>['auth']);
    expect(await counter.countToday(), 0);
  });

  test('a cancelled token consumes nothing and calls nothing', () async {
    cancel.cancel();
    await expectLater(run(build()), throwsA(isA<CancelledException>()));
    expect(log, isEmpty);
    expect(await counter.countToday(), 0);
  });

  test('a cap of zero disables the limit', () async {
    final InvoiceExtractor e = build(cap: 0);
    for (int i = 0; i < 5; i++) {
      await run(e);
    }
    expect(log.where((String s) => s == 'call'), hasLength(5));
  });

  test('a network failure with no cap does not touch the counter', () async {
    inner.error = const InvoiceFailure(InvoiceErrorKind.network);
    await expectLater(run(build(cap: 0)), throwsA(isA<InvoiceFailure>()));
    expect(await counter.countToday(), 0);
  });

  test('the unavailable extractor fails with a typed error', () async {
    await expectLater(
      run(const UnavailableInvoiceExtractor()),
      failure(InvoiceErrorKind.unknown, GuardDebugCodes.firebaseUnavailable),
    );
  });
}
