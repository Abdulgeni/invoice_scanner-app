import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extract_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

import '../../../../support/fakes.dart';

void main() {
  const String id = 'id-1';
  const String page = 'managed/id-1_0.jpg';
  final DateTime now = testT0.add(const Duration(seconds: 30));

  late FakeInvoiceRepository repo;
  late FakeImageStore store;
  late FakeInvoiceExtractor extractor;
  late RecordingAnalytics analytics;
  late CancellationToken cancel;
  late ExtractInvoice extract;

  setUp(() {
    repo = FakeInvoiceRepository();
    store = FakeImageStore()..files.add(page);
    extractor = FakeInvoiceExtractor();
    analytics = RecordingAnalytics();
    cancel = CancellationToken();
    repo.rows[id] = InvoiceRecord.queued(
      id: id,
      imagePaths: <String>[page],
      now: testT0,
    );
    extract = ExtractInvoice(
      repository: repo,
      extractor: extractor,
      imageStore: store,
      analytics: analytics,
      clock: fixedClock(now),
    );
  });

  Future<ExtractionOutcome> run() =>
      extract(recordId: id, fallbackCurrency: Currency.usd, cancel: cancel);

  test('success moves the record to review and keeps a snapshot', () async {
    final Invoice invoice = sampleInvoice();
    extractor.result = invoice;
    final ExtractionOutcome outcome = await run();
    expect(outcome, isA<ExtractionSucceeded>());
    final InvoiceRecord record = (outcome as ExtractionSucceeded).record;
    expect(record.status, InvoiceStatus.needsReview);
    expect(record.invoice, invoice);
    expect(record.extractedInvoice, invoice);
    expect(record.attemptCount, 1);
    expect(repo.rows[id], record);
    expect(extractor.lastPaths, <String>[page]);
    expect(extractor.lastFallback, Currency.usd);
    expect(analytics.extractions, <(Duration, int, InvoiceErrorKind?)>[
      (const Duration(seconds: 30), 1, null),
    ]);
  });

  for (final InvoiceErrorKind kind in InvoiceErrorKind.values.where(
    (InvoiceErrorKind k) => k != InvoiceErrorKind.cancelled,
  )) {
    test('maps a ${kind.name} failure onto the record and analytics', () async {
      extractor.error = InvoiceFailure(kind, debugCode: 'x');
      final ExtractionOutcome outcome = await run();
      expect(outcome, isA<ExtractionFailed>());
      final ExtractionFailed failed = outcome as ExtractionFailed;
      expect(failed.kind, kind);
      expect(failed.debugCode, 'x');
      expect(failed.record.status, InvoiceStatus.failed);
      expect(repo.rows[id]!.failureKind, kind);
      expect(analytics.extractions, <(Duration, int, InvoiceErrorKind?)>[
        (const Duration(seconds: 30), 1, kind),
      ]);
    });
  }

  test('unexpected exceptions map to unknown without their message', () async {
    extractor.error = const FormatException('secret invoice text');
    final ExtractionFailed failed = await run() as ExtractionFailed;
    expect(failed.kind, InvoiceErrorKind.unknown);
    expect(failed.debugCode, DebugCodes.unexpected);
    expect(failed.debugCode, isNot(contains('secret')));
  });

  test(
    'a cancellation thrown by the extractor ends as failed(cancelled)',
    () async {
      extractor.error = const CancelledException();
      final ExtractionFailed failed = await run() as ExtractionFailed;
      expect(failed.kind, InvoiceErrorKind.cancelled);
      expect(failed.record.status, InvoiceStatus.failed);
      expect(analytics.extractions, isEmpty);
    },
  );

  test(
    'cancelling mid-flight stops waiting and ignores the late result',
    () async {
      extractor.gate = Completer<Invoice>();
      final Future<ExtractionOutcome> pending = run();
      await pumpEventQueue();
      expect(extractor.calls, 1);

      cancel.cancel();
      final ExtractionFailed failed = await pending as ExtractionFailed;
      expect(failed.kind, InvoiceErrorKind.cancelled);
      expect(repo.rows[id]!.status, InvoiceStatus.failed);
      expect(repo.rows[id]!.failureKind, InvoiceErrorKind.cancelled);
      expect(analytics.extractions, isEmpty);

      extractor.gate!.complete(sampleInvoice());
      await pumpEventQueue();
      expect(repo.rows[id]!.status, InvoiceStatus.failed);
      expect(repo.rows[id]!.invoice, isNull);
    },
  );

  test('a token cancelled up front never calls the model', () async {
    cancel.cancel();
    final ExtractionFailed failed = await run() as ExtractionFailed;
    expect(failed.kind, InvoiceErrorKind.cancelled);
    expect(extractor.calls, 0);
  });

  test(
    'missing images fail as unknown with a debug code, no model call',
    () async {
      store.files.clear();
      final ExtractionFailed failed = await run() as ExtractionFailed;
      expect(failed.kind, InvoiceErrorKind.unknown);
      expect(failed.debugCode, DebugCodes.imagesMissing);
      expect(failed.record.status, InvoiceStatus.failed);
      expect(extractor.calls, 0);
    },
  );

  group('skips', () {
    test('a missing record', () async {
      repo.rows.clear();
      final ExtractionSkipped skipped = await run() as ExtractionSkipped;
      expect(skipped.reason, ExtractionSkipReason.notFound);
    });

    test('a record that is already in review', () async {
      repo.rows[id] = repo.rows[id]!
          .markExtracting(testT0)
          .markNeedsReview(sampleInvoice(), testT0);
      final ExtractionSkipped skipped = await run() as ExtractionSkipped;
      expect(skipped.reason, ExtractionSkipReason.notExtractable);
      expect(extractor.calls, 0);
    });

    test('a deleted record', () async {
      repo.rows[id] = repo.rows[id]!.markDeleted(testT0);
      final ExtractionSkipped skipped = await run() as ExtractionSkipped;
      expect(skipped.reason, ExtractionSkipReason.notExtractable);
      expect(extractor.calls, 0);
    });

    test('a storage failure while claiming', () async {
      repo.failMutateCalls.add(1);
      final ExtractionSkipped skipped = await run() as ExtractionSkipped;
      expect(skipped.reason, ExtractionSkipReason.storageUnavailable);
      expect(extractor.calls, 0);
    });
  });

  test('only one of two concurrent calls extracts', () async {
    extractor.gate = Completer<Invoice>();
    final Future<ExtractionOutcome> first = run();
    await pumpEventQueue();

    final ExtractionSkipped second = await run() as ExtractionSkipped;
    expect(second.reason, ExtractionSkipReason.notExtractable);

    extractor.gate!.complete(sampleInvoice());
    expect(await first, isA<ExtractionSucceeded>());
    expect(extractor.calls, 1);
  });

  test('a failed record can be retried and counts the attempt', () async {
    repo.rows[id] = repo.rows[id]!.markFailed(InvoiceErrorKind.timeout, testT0);
    final ExtractionSucceeded done = await run() as ExtractionSucceeded;
    expect(done.record.attemptCount, 1);
    expect(done.record.failureKind, isNull);
    expect(analytics.extractions.single.$2, 1);
  });

  test(
    'a storage failure while saving the result leaves it extracting',
    () async {
      repo.failMutateCalls.add(2);
      final ExtractionSkipped skipped = await run() as ExtractionSkipped;
      expect(skipped.reason, ExtractionSkipReason.storageUnavailable);
      expect(repo.rows[id]!.status, InvoiceStatus.extracting);
      expect(analytics.extractions, isEmpty);
    },
  );

  test('a record deleted mid-flight is skipped and stays deleted', () async {
    extractor.gate = Completer<Invoice>();
    final Future<ExtractionOutcome> pending = run();
    await pumpEventQueue();

    repo.rows[id] = repo.rows[id]!.markDeleted(now);
    extractor.gate!.complete(sampleInvoice());
    final ExtractionSkipped skipped = await pending as ExtractionSkipped;
    expect(skipped.reason, ExtractionSkipReason.notExtractable);
    expect(repo.rows[id]!.isDeleted, isTrue);
    expect(repo.rows[id]!.invoice, isNull);
    expect(analytics.extractions, isEmpty);
  });
}
