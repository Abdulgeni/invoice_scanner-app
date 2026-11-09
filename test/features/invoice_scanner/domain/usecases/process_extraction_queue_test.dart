import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/connectivity_monitor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extract_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/process_extraction_queue.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

import '../../../../support/fakes.dart';

class FakeConnectivity implements ConnectivityMonitor {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

/// Records the order of extractions and lets a test script each result.
class ScriptedExtractor implements InvoiceExtractor {
  final List<String> order = <String>[];
  final Map<String, Object> errors = <String, Object>{};
  void Function(String firstPage)? onCall;
  Currency? lastFallback;

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    order.add(imagePaths.first);
    lastFallback = fallbackCurrency;
    onCall?.call(imagePaths.first);
    final Object? error = errors[imagePaths.first];
    if (error != null) throw error;
    return sampleInvoice();
  }
}

/// Returns a stale snapshot, as if another worker claimed the record after
/// the list was read.
class RacyRepository extends FakeInvoiceRepository {
  RacyRepository(this.victim);

  final String victim;

  @override
  Future<List<InvoiceRecord>> listByStatus(Set<InvoiceStatus> statuses) async {
    final List<InvoiceRecord> stale = await super.listByStatus(statuses);
    rows[victim] = rows[victim]!.markExtracting(testT0);
    return stale;
  }
}

String page(String id) => 'managed/${id}_0.jpg';

InvoiceRecord pending(String id, {DateTime? at}) => InvoiceRecord.queued(
  id: id,
  imagePaths: <String>[page(id)],
  now: at ?? testT0,
);

InvoiceRecord failedWith(String id, InvoiceErrorKind kind, {DateTime? at}) =>
    pending(id, at: at).markExtracting(testT0).markFailed(kind, testT0);

void main() {
  late FakeInvoiceRepository repo;
  late FakeImageStore store;
  late ScriptedExtractor extractor;
  late FakeConnectivity connectivity;
  late RecordingAnalytics analytics;

  ProcessExtractionQueue build({
    FakeInvoiceRepository? repository,
    int maxAutoAttempts = 5,
  }) {
    final FakeInvoiceRepository r = repository ?? repo;
    return ProcessExtractionQueue(
      repository: r,
      extract: ExtractInvoice(
        repository: r,
        extractor: extractor,
        imageStore: store,
        analytics: analytics,
        clock: fixedClock(testT0.add(const Duration(seconds: 5))),
      ),
      connectivity: connectivity,
      fallbackCurrency: () => Currency.eur,
      maxAutoAttempts: maxAutoAttempts,
    );
  }

  void add(InvoiceRecord r) {
    repo.rows[r.id] = r;
    store.files.addAll(r.imagePaths);
  }

  Future<QueuePassSummary> run(
    ProcessExtractionQueue q, [
    CancellationToken? stop,
  ]) => q.runOnce(stop: stop ?? CancellationToken());

  setUp(() {
    repo = FakeInvoiceRepository();
    store = FakeImageStore();
    extractor = ScriptedExtractor();
    connectivity = FakeConnectivity();
    analytics = RecordingAnalytics();
  });

  test(
    'resumes pending and failed(network), oldest first, one at a time',
    () async {
      add(pending('late', at: testT0.add(const Duration(minutes: 2))));
      add(
        failedWith(
          'net',
          InvoiceErrorKind.network,
          at: testT0.add(const Duration(minutes: 1)),
        ),
      );
      add(pending('early'));

      final QueuePassSummary summary = await run(build());

      expect(extractor.order, <String>[
        page('early'),
        page('net'),
        page('late'),
      ]);
      expect(
        summary,
        const QueuePassSummary(
          processed: 3,
          succeeded: 3,
          failed: 0,
          skipped: 0,
          stopReason: QueueStopReason.completed,
        ),
      );
      for (final String id in <String>['early', 'net', 'late']) {
        expect(repo.rows[id]!.status, InvoiceStatus.needsReview, reason: id);
      }
      expect(extractor.lastFallback, Currency.eur);
    },
  );

  test('leaves everything else alone', () async {
    add(failedWith('timeout', InvoiceErrorKind.timeout));
    add(failedWith('quota', InvoiceErrorKind.quotaExceeded));
    add(failedWith('cancelled', InvoiceErrorKind.cancelled));
    add(failedWith('blocked', InvoiceErrorKind.safetyBlock));
    add(
      pending(
        'r',
      ).markExtracting(testT0).markNeedsReview(sampleInvoice(), testT0),
    );
    add(pending('gone').markDeleted(testT0));

    final QueuePassSummary summary = await run(build());
    expect(summary.processed, 0);
    expect(extractor.order, isEmpty);
  });

  test('stops giving up on a record after the attempt limit', () async {
    InvoiceRecord worn = pending('worn');
    for (int i = 0; i < 5; i++) {
      worn = worn
          .markExtracting(testT0)
          .markFailed(InvoiceErrorKind.network, testT0);
    }
    add(worn);
    expect(worn.attemptCount, 5);
    expect((await run(build())).processed, 0);
    expect((await run(build(maxAutoAttempts: 6))).processed, 1);
  });

  group('stopping', () {
    test('offline at the start attempts nothing', () async {
      add(pending('a'));
      connectivity.online = false;
      final QueuePassSummary summary = await run(build());
      expect(summary.stopReason, QueueStopReason.offline);
      expect(summary.processed, 0);
      expect(extractor.order, isEmpty);
    });

    test('going offline mid-pass stops before the next record', () async {
      add(pending('a'));
      add(pending('b', at: testT0.add(const Duration(minutes: 1))));
      extractor.onCall = (String _) => connectivity.online = false;
      final QueuePassSummary summary = await run(build());
      expect(summary.stopReason, QueueStopReason.offline);
      expect(summary.succeeded, 1);
      expect(repo.rows['b']!.status, InvoiceStatus.pendingExtraction);
    });

    test(
      'a network failure ends the pass and keeps the record eligible',
      () async {
        add(pending('a'));
        add(pending('b', at: testT0.add(const Duration(minutes: 1))));
        extractor.errors[page('a')] = const InvoiceFailure(
          InvoiceErrorKind.network,
        );
        final QueuePassSummary summary = await run(build());
        expect(summary.stopReason, QueueStopReason.offline);
        expect(summary.failed, 1);
        expect(repo.rows['a']!.failureKind, InvoiceErrorKind.network);
        expect(repo.rows['b']!.status, InvoiceStatus.pendingExtraction);
      },
    );

    test('quota and App Check rejections stop the pass as blocked', () async {
      for (final InvoiceErrorKind kind in <InvoiceErrorKind>[
        InvoiceErrorKind.quotaExceeded,
        InvoiceErrorKind.appCheckFailed,
      ]) {
        repo.rows.clear();
        extractor.order.clear();
        add(pending('a'));
        add(pending('b', at: testT0.add(const Duration(minutes: 1))));
        extractor.errors[page('a')] = InvoiceFailure(kind);
        final QueuePassSummary summary = await run(build());
        expect(summary.stopReason, QueueStopReason.blocked, reason: kind.name);
        expect(extractor.order, <String>[page('a')], reason: kind.name);
      }
    });

    test('any other failure moves on to the next record', () async {
      add(pending('a'));
      add(pending('b', at: testT0.add(const Duration(minutes: 1))));
      extractor.errors[page('a')] = const InvoiceFailure(
        InvoiceErrorKind.malformedJson,
      );
      final QueuePassSummary summary = await run(build());
      expect(summary.stopReason, QueueStopReason.completed);
      expect(summary.failed, 1);
      expect(summary.succeeded, 1);
    });

    test('the stop token is honored between records, never mid-call', () async {
      add(pending('a'));
      add(pending('b', at: testT0.add(const Duration(minutes: 1))));
      final CancellationToken stop = CancellationToken();
      extractor.onCall = (String _) => stop.cancel();
      final QueuePassSummary summary = await run(build(), stop);
      expect(summary.stopReason, QueueStopReason.stopped);
      expect(summary.succeeded, 1, reason: 'the in-flight call finished');
      expect(repo.rows['a']!.status, InvoiceStatus.needsReview);
      expect(repo.rows['b']!.status, InvoiceStatus.pendingExtraction);
    });
  });

  test('a record claimed by someone else is skipped, not failed', () async {
    final RacyRepository racy = RacyRepository('a');
    racy.rows['a'] = pending('a');
    store.files.add(page('a'));
    final QueuePassSummary summary = await run(build(repository: racy));
    expect(summary.skipped, 1);
    expect(summary.failed, 0);
    expect(extractor.order, isEmpty);
  });
}
