import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/capture_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extract_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/save_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/update_review_draft.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';

import '../../../../support/fakes.dart';

typedef B = InvoiceScannerBloc;
typedef S = InvoiceScannerState;

late FakeInvoiceRepository repo;
late FakeImageStore store;
late FakeDocumentScanner scanner;
late FakeImagePreprocessor pre;
late FakeInvoiceExtractor extractor;
late RecordingAnalytics analytics;
late int idCounter;
late void Function()? onSleep;

final DateTime now = testT0.add(const Duration(seconds: 30));

B makeBloc({
  Duration draftDebounce = const Duration(milliseconds: 20),
  Duration settleTimeout = const Duration(seconds: 3),
}) {
  final clock = fixedClock(now);
  return B(
    captureInvoice: CaptureInvoice(
      scanner: scanner,
      preprocessor: pre,
      repository: repo,
      imageStore: store,
      clock: clock,
      newId: () => 'id-${++idCounter}',
    ),
    extractInvoice: ExtractInvoice(
      repository: repo,
      extractor: extractor,
      imageStore: store,
      analytics: analytics,
      clock: clock,
    ),
    saveInvoice: SaveInvoice(
      repository: repo,
      imageStore: store,
      analytics: analytics,
      clock: clock,
    ),
    deleteInvoice:
        DeleteInvoice(repository: repo, imageStore: store, clock: clock),
    updateReviewDraft: UpdateReviewDraft(repository: repo, clock: clock),
    loadRecord: repo.get,
    clock: clock,
    fallbackCurrency: () => Currency.usd,
    draftDebounce: draftDebounce,
    settlePollInterval: const Duration(milliseconds: 10),
    settleTimeout: settleTimeout,
    sleep: (Duration d) async => onSleep?.call(),
  );
}

Future<void> pump() => pumpEventQueue(times: 400);

Future<void> shortWait() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

Money usd(int m) => Money.tryFromMinorUnits(m, Currency.usd)!;

Matcher capturing(ScanSource s) =>
    isA<InvoiceCapturing>().having((x) => x.source, 'source', s);
final Matcher preprocessing = isA<InvoicePreprocessing>();
final Matcher initial = isA<InvoiceScannerInitial>();
Matcher imageReady(String id) =>
    isA<InvoiceImageReady>().having((x) => x.recordId, 'recordId', id);
final Matcher extracting = isA<InvoiceExtracting>();
Matcher reviewing({bool Function(InvoiceReviewing)? where}) =>
    isA<InvoiceReviewing>().having(
      (x) => where == null ? true : where(x),
      'matches',
      isTrue,
    );

Matcher failure(InvoiceErrorKind kind, {bool? canRetry, bool? retake}) {
  return isA<InvoiceExtractionFailure>()
      .having((x) => x.kind, 'kind', kind)
      .having((x) => x.canRetry, 'canRetry', canRetry ?? anything)
      .having((x) => x.suggestsRetake, 'suggestsRetake', retake ?? anything);
}

Matcher captureFailure(CaptureFailureReason r) =>
    isA<InvoiceCaptureFailure>().having((x) => x.reason, 'reason', r);

Future<void> toPreview(B b) async {
  b.add(const ScanRequested(ScanSource.camera));
  await pump();
}

Future<void> toReview(B b) async {
  await toPreview(b);
  b.add(const ExtractRequested());
  await pump();
}

void main() {
  setUp(() {
    repo = FakeInvoiceRepository();
    store = FakeImageStore();
    scanner = FakeDocumentScanner();
    pre = FakeImagePreprocessor(store);
    extractor = FakeInvoiceExtractor();
    analytics = RecordingAnalytics();
    idCounter = 0;
    onSleep = null;
  });

  test('starts in the initial state', () {
    expect(makeBloc().state, const InvoiceScannerInitial());
  });

  group('capture', () {
    blocTest<B, S>(
      'scanner, optimizing, then a preview of the compressed pages',
      build: makeBloc,
      act: (b) async {
        b.add(const ScanRequested(ScanSource.gallery));
        await pump();
      },
      expect: () => <Matcher>[
        capturing(ScanSource.gallery),
        preprocessing,
        isA<InvoiceImageReady>()
            .having((x) => x.recordId, 'recordId', 'id-1')
            .having((x) => x.pagePaths, 'paths',
                <String>['managed/id-1_0.jpg']),
      ],
      verify: (_) {
        expect(repo.rows['id-1']!.status, InvoiceStatus.pendingExtraction);
      },
    );

    blocTest<B, S>(
      'the user closing the scanner returns to the start',
      build: makeBloc,
      setUp: () => scanner.result = null,
      act: (b) async {
        b.add(const ScanRequested(ScanSource.camera));
        await pump();
      },
      expect: () => <Matcher>[capturing(ScanSource.camera), initial],
    );

    blocTest<B, S>(
      'too many pages is reported with the limit',
      build: makeBloc,
      setUp: () => scanner.result = <String>['1', '2', '3', '4', '5', '6'],
      act: (b) async {
        b.add(const ScanRequested(ScanSource.camera));
        await pump();
      },
      expect: () => <Matcher>[
        capturing(ScanSource.camera),
        isA<InvoiceCaptureFailure>()
            .having((x) => x.reason, 'reason',
                CaptureFailureReason.tooManyPages)
            .having((x) => x.maxPages, 'max', 5),
      ],
      verify: (_) => expect(repo.rows, isEmpty),
    );

    for (final (String code, CaptureFailureReason reason)
        in <(String, CaptureFailureReason)>[
      (DebugCodes.cameraPermissionDenied,
          CaptureFailureReason.cameraPermissionDenied),
      (DebugCodes.scannerUnavailable,
          CaptureFailureReason.scannerUnavailable),
      ('something_else', CaptureFailureReason.unknown),
    ]) {
      blocTest<B, S>(
        'scanner failure "$code" maps to ${reason.name}',
        build: makeBloc,
        setUp: () => scanner.error =
            InvoiceFailure(InvoiceErrorKind.unknown, debugCode: code),
        act: (b) async {
          b.add(const ScanRequested(ScanSource.camera));
          await pump();
        },
        expect: () =>
            <Matcher>[capturing(ScanSource.camera), captureFailure(reason)],
      );
    }

    blocTest<B, S>(
      'a capture failure can be left and the scan retried',
      build: makeBloc,
      setUp: () => scanner.error = const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: DebugCodes.scannerUnavailable,
      ),
      act: (b) async {
        b.add(const ScanRequested(ScanSource.camera));
        await pump();
        scanner.error = null;
        b.add(const ScanRequested(ScanSource.camera));
        await pump();
      },
      expect: () => <Matcher>[
        capturing(ScanSource.camera),
        captureFailure(CaptureFailureReason.scannerUnavailable),
        capturing(ScanSource.camera),
        preprocessing,
        imageReady('id-1'),
      ],
    );

    blocTest<B, S>(
      'cancelling while the scanner is open ends at the start',
      build: makeBloc,
      setUp: () => scanner.gate = Completer<List<String>?>(),
      act: (b) async {
        b.add(const ScanRequested(ScanSource.camera));
        await pump();
        b.add(const CancelRequested());
        await pump();
        scanner.gate!.complete(<String>['scan/1.jpg']);
        await pump();
      },
      expect: () => <Matcher>[capturing(ScanSource.camera), initial],
      verify: (_) => expect(repo.rows, isEmpty),
    );

    blocTest<B, S>(
      'cancelling while optimizing removes the compressed files',
      build: makeBloc,
      setUp: () => pre.gate = Completer<void>(),
      act: (b) async {
        b.add(const ScanRequested(ScanSource.camera));
        await pump();
        b.add(const CancelRequested());
        await pump();
        pre.gate!.complete();
        await pump();
      },
      expect: () => <Matcher>[
        capturing(ScanSource.camera),
        preprocessing,
        initial,
      ],
      verify: (_) {
        expect(repo.rows, isEmpty);
        expect(store.files, isEmpty);
      },
    );

    blocTest<B, S>(
      'a capture that finishes after a discard is cleaned up, not shown',
      build: makeBloc,
      setUp: () => scanner.gate = Completer<List<String>?>(),
      act: (b) async {
        b.add(const ScanRequested(ScanSource.camera));
        await pump();
        b.add(const DiscardRequested());
        await pump();
        scanner.gate!.complete(<String>['scan/1.jpg']);
        await pump();
      },
      expect: () => <Matcher>[capturing(ScanSource.camera), initial],
      verify: (_) {
        expect(repo.rows, isEmpty);
        expect(store.files, isEmpty);
      },
    );
  });

  group('extraction', () {
    blocTest<B, S>(
      'reads the pages and opens the review with no warnings',
      build: makeBloc,
      act: (b) async => toReview(b),
      expect: () => <Matcher>[
        capturing(ScanSource.camera),
        preprocessing,
        imageReady('id-1'),
        isA<InvoiceExtracting>().having((x) => x.pagePaths, 'paths',
            <String>['managed/id-1_0.jpg']),
        reviewing(
            where: (r) => r.invoice == sampleInvoice() && r.warnings.isEmpty),
      ],
    );

    for (final (InvoiceErrorKind kind, bool canRetry, bool retake)
        in <(InvoiceErrorKind, bool, bool)>[
      (InvoiceErrorKind.network, true, false),
      (InvoiceErrorKind.timeout, true, false),
      (InvoiceErrorKind.quotaExceeded, true, false),
      (InvoiceErrorKind.appCheckFailed, false, false),
      (InvoiceErrorKind.safetyBlock, false, true),
      (InvoiceErrorKind.emptyResponse, true, true),
      (InvoiceErrorKind.malformedJson, true, false),
      (InvoiceErrorKind.notAnInvoice, false, true),
      (InvoiceErrorKind.unknown, true, false),
    ]) {
      blocTest<B, S>(
        'a ${kind.name} failure becomes a typed failure state',
        build: makeBloc,
        setUp: () => extractor.error = InvoiceFailure(kind, debugCode: 'x'),
        act: (b) async => toReview(b),
        skip: 3,
        expect: () => <Matcher>[
          extracting,
          isA<InvoiceExtractionFailure>()
              .having((x) => x.kind, 'kind', kind)
              .having((x) => x.canRetry, 'canRetry', canRetry)
              .having((x) => x.suggestsRetake, 'suggestsRetake', retake)
              .having((x) => x.debugCode, 'code', 'x'),
        ],
      );
    }

    blocTest<B, S>(
      'missing image files cannot be retried',
      build: makeBloc,
      act: (b) async {
        await toPreview(b);
        store.files.clear();
        b.add(const ExtractRequested());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[
        extracting,
        failure(InvoiceErrorKind.unknown, canRetry: false),
      ],
    );

    blocTest<B, S>(
      'retry after a failure reads again and reaches the review',
      build: makeBloc,
      setUp: () =>
          extractor.error = const InvoiceFailure(InvoiceErrorKind.timeout),
      act: (b) async {
        await toReview(b);
        extractor.error = null;
        b.add(const ExtractRequested());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[
        extracting,
        failure(InvoiceErrorKind.timeout),
        extracting,
        reviewing(),
      ],
      verify: (_) => expect(repo.rows['id-1']!.attemptCount, 2),
    );

    blocTest<B, S>(
      'a non-retryable failure ignores "try again"',
      build: makeBloc,
      setUp: () => extractor.error =
          const InvoiceFailure(InvoiceErrorKind.notAnInvoice),
      act: (b) async {
        await toReview(b);
        b.add(const ExtractRequested());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[
        extracting,
        failure(InvoiceErrorKind.notAnInvoice),
      ],
      verify: (_) => expect(extractor.calls, 1),
    );

    blocTest<B, S>(
      'cancelling the read returns to the preview, still retryable',
      build: makeBloc,
      setUp: () => extractor.gate = Completer<Invoice>(),
      act: (b) async {
        await toPreview(b);
        b.add(const ExtractRequested());
        await pump();
        b.add(const CancelRequested());
        await pump();
        extractor.gate!.complete(sampleInvoice());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[extracting, imageReady('id-1')],
      verify: (_) {
        expect(repo.rows['id-1']!.status, InvoiceStatus.failed);
        expect(repo.rows['id-1']!.failureKind, InvoiceErrorKind.cancelled);
        expect(analytics.extractions, isEmpty);
      },
    );

    blocTest<B, S>(
      'after a cancelled read the preview can scan again',
      build: makeBloc,
      setUp: () => extractor.gate = Completer<Invoice>(),
      act: (b) async {
        await toPreview(b);
        b.add(const ExtractRequested());
        await pump();
        b.add(const CancelRequested());
        await pump();
        extractor.gate = null;
        b.add(const ExtractRequested());
        await pump();
      },
      skip: 3,
      expect: () =>
          <Matcher>[extracting, imageReady('id-1'), extracting, reviewing()],
    );

    blocTest<B, S>(
      'a double tap runs one extraction',
      build: makeBloc,
      setUp: () => extractor.gate = Completer<Invoice>(),
      act: (b) async {
        await toPreview(b);
        b.add(const ExtractRequested());
        b.add(const ExtractRequested());
        await pump();
        extractor.gate!.complete(sampleInvoice());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[extracting, reviewing()],
      verify: (_) => expect(extractor.calls, 1),
    );

    blocTest<B, S>(
      'a record claimed by the offline queue is waited on, not failed',
      build: makeBloc,
      act: (b) async {
        await toPreview(b);
        repo.rows['id-1'] = repo.rows['id-1']!.markExtracting(testT0);
        int polls = 0;
        onSleep = () {
          polls++;
          if (polls == 2) {
            repo.rows['id-1'] =
                repo.rows['id-1']!.markNeedsReview(sampleInvoice(), testT0);
          }
        };
        b.add(const ExtractRequested());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[extracting, reviewing()],
      verify: (_) => expect(extractor.calls, 0),
    );

    blocTest<B, S>(
      'waiting for another worker eventually times out',
      build: () => makeBloc(settleTimeout: const Duration(milliseconds: 30)),
      act: (b) async {
        await toPreview(b);
        repo.rows['id-1'] = repo.rows['id-1']!.markExtracting(testT0);
        b.add(const ExtractRequested());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[
        extracting,
        isA<InvoiceExtractionFailure>()
            .having((x) => x.kind, 'kind', InvoiceErrorKind.timeout)
            .having((x) => x.canRetry, 'canRetry', true)
            .having((x) => x.debugCode, 'code', BlocDebugCodes.settleTimeout),
      ],
    );

    blocTest<B, S>(
      'a record deleted while waiting returns to the start',
      build: makeBloc,
      act: (b) async {
        await toPreview(b);
        repo.rows['id-1'] = repo.rows['id-1']!.markExtracting(testT0);
        onSleep = () =>
            repo.rows['id-1'] = repo.rows['id-1']!.markDeleted(testT0);
        b.add(const ExtractRequested());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[extracting, initial],
    );
  });

  group('leaving a flow', () {
    blocTest<B, S>(
      'discarding mid-read returns to the start and ignores the late result',
      build: makeBloc,
      setUp: () => extractor.gate = Completer<Invoice>(),
      act: (b) async {
        await toPreview(b);
        b.add(const ExtractRequested());
        await pump();
        b.add(const DiscardRequested());
        await pump();
        extractor.gate!.complete(sampleInvoice());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[extracting, initial],
      verify: (_) {
        expect(repo.rows['id-1']!.isDeleted, isTrue);
        expect(repo.rows['id-1']!.invoice, isNull);
        expect(store.files, isEmpty);
      },
    );

    blocTest<B, S>(
      'retake deletes the old record and scans again',
      build: makeBloc,
      act: (b) async {
        await toPreview(b);
        b.add(const RetakeRequested());
        await pump();
      },
      expect: () => <Matcher>[
        capturing(ScanSource.camera),
        preprocessing,
        imageReady('id-1'),
        capturing(ScanSource.camera),
        preprocessing,
        imageReady('id-2'),
      ],
      verify: (_) {
        expect(repo.rows['id-1']!.isDeleted, isTrue);
        expect(repo.rows['id-2']!.status, InvoiceStatus.pendingExtraction);
      },
    );

    blocTest<B, S>(
      'retake is not offered mid-read',
      build: makeBloc,
      setUp: () => extractor.gate = Completer<Invoice>(),
      act: (b) async {
        await toPreview(b);
        b.add(const ExtractRequested());
        await pump();
        b.add(const RetakeRequested());
        await pump();
        extractor.gate!.complete(sampleInvoice());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[extracting, reviewing()],
    );

    blocTest<B, S>(
      '"Keep image" leaves the record and returns to the start',
      build: makeBloc,
      setUp: () => extractor.error =
          const InvoiceFailure(InvoiceErrorKind.notAnInvoice),
      act: (b) async {
        await toReview(b);
        b.add(const KeepImageRequested());
        await pump();
      },
      skip: 3,
      expect: () => <Matcher>[
        extracting,
        failure(InvoiceErrorKind.notAnInvoice),
        initial,
      ],
      verify: (_) {
        expect(repo.rows['id-1']!.status, InvoiceStatus.failed);
        expect(repo.rows['id-1']!.isDeleted, isFalse);
        expect(store.files, isNotEmpty);
      },
    );
  });

  group('opening an existing record', () {
    InvoiceRecord base(String id) => InvoiceRecord.queued(
          id: id,
          imagePaths: <String>['managed/${id}_0.jpg'],
          now: testT0,
        );

    final Map<String, (InvoiceRecord Function(InvoiceRecord), Matcher)> cases =
        <String, (InvoiceRecord Function(InvoiceRecord), Matcher)>{
      'pending shows the preview': (
        (InvoiceRecord r) => r,
        imageReady('x'),
      ),
      'in review shows the review': (
        (InvoiceRecord r) =>
            r.markExtracting(testT0).markNeedsReview(sampleInvoice(), testT0),
        reviewing(where: (s) => s.invoice == sampleInvoice()),
      ),
      'failed shows the failure': (
        (InvoiceRecord r) => r.markFailed(InvoiceErrorKind.timeout, testT0),
        failure(InvoiceErrorKind.timeout, canRetry: true),
      ),
      'cancelled shows the preview': (
        (InvoiceRecord r) => r.markFailed(InvoiceErrorKind.cancelled, testT0),
        imageReady('x'),
      ),
      'saved shows saved': (
        (InvoiceRecord r) => r
            .markExtracting(testT0)
            .markNeedsReview(sampleInvoice(), testT0)
            .markSaved(sampleInvoice(), testT0),
        isA<InvoiceSaved>(),
      ),
      'deleted shows the start': (
        (InvoiceRecord r) => r.markDeleted(testT0),
        initial,
      ),
    };
    cases.forEach(
        (String name, (InvoiceRecord Function(InvoiceRecord), Matcher) c) {
      blocTest<B, S>(
        name,
        build: makeBloc,
        setUp: () => repo.rows['x'] = c.$1(base('x')),
        act: (b) async {
          b.add(const RecordOpened('x'));
          await pump();
        },
        expect: () => <Matcher>[c.$2],
      );
    });

    blocTest<B, S>(
      'an unknown id shows the start',
      build: makeBloc,
      act: (b) async {
        b.add(const RecordOpened('nope'));
        await pump();
      },
      expect: () => <Matcher>[initial],
    );
  });

  group('review', () {
    blocTest<B, S>(
      'an edit revalidates immediately and autosaves after the debounce',
      build: makeBloc,
      act: (b) async {
        await toReview(b);
        b.add(InvoiceEdited(sampleInvoice().copyWith(total: () => usd(3400))));
        await pump();
        await shortWait();
      },
      skip: 5,
      expect: () => <Matcher>[
        reviewing(
          where: (r) =>
              r.invoice.total == usd(3400) &&
              r.warnings.any(
                (ValidationWarning w) => w.code == ValidationCode.totalMismatch,
              ),
        ),
      ],
      verify: (_) {
        expect(repo.rows['id-1']!.invoice!.total, usd(3400));
        expect(repo.rows['id-1']!.extractedInvoice, sampleInvoice());
      },
    );

    blocTest<B, S>(
      'an edit identical to the current invoice changes nothing',
      build: makeBloc,
      act: (b) async {
        await toReview(b);
        b.add(InvoiceEdited(sampleInvoice()));
        await pump();
      },
      skip: 5,
      expect: () => <Matcher>[],
    );

    blocTest<B, S>(
      'entering a value clears its "unreadable" flag',
      build: makeBloc,
      setUp: () => extractor.result = sampleInvoice().copyWith(
        total: () => null,
        unreadable: <FieldRef>{const FieldRef(InvoiceField.total)},
      ),
      act: (b) async {
        await toReview(b);
        b.add(InvoiceEdited(
          (b.state as InvoiceReviewing).invoice.copyWith(total: () => usd(3300)),
        ));
        await pump();
      },
      skip: 4,
      expect: () => <Matcher>[
        reviewing(
          where: (r) => r.warnings.any(
            (ValidationWarning w) => w.code == ValidationCode.unreadableValue,
          ),
        ),
        reviewing(
            where: (r) => r.invoice.unreadable.isEmpty && r.warnings.isEmpty),
      ],
    );

    blocTest<B, S>(
      'dismissing a flag keeps the value empty and removes the warning',
      build: makeBloc,
      setUp: () => extractor.result = sampleInvoice().copyWith(
        tax: () => null,
        subtotal: () => null,
        unreadable: <FieldRef>{const FieldRef(InvoiceField.tax)},
      ),
      act: (b) async {
        await toReview(b);
        b.add(const UnreadableDismissed(FieldRef(InvoiceField.tax)));
        await pump();
      },
      skip: 5,
      expect: () => <Matcher>[
        reviewing(
          where: (r) =>
              r.invoice.tax == null &&
              r.invoice.unreadable.isEmpty &&
              r.warnings.every(
                (ValidationWarning w) =>
                    w.code != ValidationCode.unreadableValue,
              ),
        ),
      ],
    );

    blocTest<B, S>(
      'a one-tap fix clears the mismatch warning',
      build: makeBloc,
      setUp: () =>
          extractor.result = sampleInvoice().copyWith(total: () => usd(3400)),
      act: (b) async {
        await toReview(b);
        b.add(FixApplied(
            SetMoneyFix(const FieldRef(InvoiceField.total), usd(3300))));
        await pump();
      },
      skip: 4,
      expect: () => <Matcher>[
        reviewing(
          where: (r) => r.warnings.any(
            (ValidationWarning w) => w.code == ValidationCode.totalMismatch,
          ),
        ),
        reviewing(
            where: (r) => r.invoice.total == usd(3300) && r.warnings.isEmpty),
      ],
    );

    blocTest<B, S>(
      'pausing the app writes the draft without waiting for the debounce',
      build: () => makeBloc(draftDebounce: const Duration(hours: 1)),
      act: (b) async {
        await toReview(b);
        b.add(InvoiceEdited(sampleInvoice(vendor: 'Edited')));
        await pump();
        expect(repo.rows['id-1']!.invoice!.vendorName, 'Acme');
        b.add(const AppPaused());
        await pump();
      },
      skip: 5,
      expect: () => <Matcher>[
        reviewing(where: (r) => r.invoice.vendorName == 'Edited'),
      ],
      verify: (_) =>
          expect(repo.rows['id-1']!.invoice!.vendorName, 'Edited'),
    );

    blocTest<B, S>(
      'a draft that cannot be written shows a notice',
      build: makeBloc,
      act: (b) async {
        await toReview(b);
        repo.failMutateCalls.add(repo.mutateCalls + 1);
        b.add(InvoiceEdited(sampleInvoice(vendor: 'Edited')));
        await pump();
        await shortWait();
      },
      skip: 5,
      expect: () => <Matcher>[
        reviewing(where: (r) => r.notice == null),
        reviewing(where: (r) => r.notice == ReviewNotice.draftNotSaved),
      ],
    );
  });

  group('saving', () {
    blocTest<B, S>(
      'saves, removes the images, and reports the correction count',
      build: makeBloc,
      act: (b) async {
        await toReview(b);
        b.add(const SaveRequested());
        await pump();
      },
      skip: 5,
      expect: () => <Matcher>[
        isA<InvoiceSaving>(),
        isA<InvoiceSaved>().having((x) => x.recordId, 'id', 'id-1'),
      ],
      verify: (_) {
        expect(repo.rows['id-1']!.status, InvoiceStatus.saved);
        expect(store.files, isEmpty);
        expect(analytics.saves, <int>[0]);
      },
    );

    blocTest<B, S>(
      'warnings never block a save',
      build: makeBloc,
      setUp: () =>
          extractor.result = sampleInvoice().copyWith(total: () => usd(9999)),
      act: (b) async {
        await toReview(b);
        expect((b.state as InvoiceReviewing).warnings, isNotEmpty);
        b.add(const SaveRequested());
        await pump();
      },
      skip: 5,
      expect: () => <Matcher>[isA<InvoiceSaving>(), isA<InvoiceSaved>()],
    );

    blocTest<B, S>(
      'a failed save keeps the user on the review with their edits',
      build: makeBloc,
      act: (b) async {
        await toReview(b);
        b.add(InvoiceEdited(sampleInvoice(vendor: 'Edited')));
        await pump();
        await shortWait();
        repo.failMutateCalls.add(repo.mutateCalls + 1);
        b.add(const SaveRequested());
        await pump();
      },
      skip: 5,
      expect: () => <Matcher>[
        reviewing(where: (r) => r.invoice.vendorName == 'Edited'),
        isA<InvoiceSaving>(),
        reviewing(
          where: (r) =>
              r.invoice.vendorName == 'Edited' &&
              r.notice == ReviewNotice.saveFailed,
        ),
      ],
      verify: (_) =>
          expect(repo.rows['id-1']!.status, InvoiceStatus.needsReview),
    );

    blocTest<B, S>(
      'saving twice saves once',
      build: makeBloc,
      act: (b) async {
        await toReview(b);
        b.add(const SaveRequested());
        b.add(const SaveRequested());
        await pump();
      },
      skip: 5,
      expect: () => <Matcher>[isA<InvoiceSaving>(), isA<InvoiceSaved>()],
      verify: (_) => expect(analytics.saves, hasLength(1)),
    );

    blocTest<B, S>(
      'leaving the saved screen returns to the start',
      build: makeBloc,
      act: (b) async {
        await toReview(b);
        b.add(const SaveRequested());
        await pump();
        b.add(const ResetRequested());
        await pump();
      },
      skip: 5,
      expect: () =>
          <Matcher>[isA<InvoiceSaving>(), isA<InvoiceSaved>(), initial],
    );
  });
}
