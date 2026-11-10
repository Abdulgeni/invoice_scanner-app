import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/capture_invoice.dart';

import '../../../../support/fakes.dart';

void main() {
  late FakeDocumentScanner scanner;
  late FakeImageStore store;
  late FakeImagePreprocessor preprocessor;
  late FakeInvoiceRepository repo;
  late CancellationToken cancel;
  late CaptureInvoice capture;

  setUp(() {
    scanner = FakeDocumentScanner();
    store = FakeImageStore();
    preprocessor = FakeImagePreprocessor(store);
    repo = FakeInvoiceRepository();
    cancel = CancellationToken();
    int n = 0;
    capture = CaptureInvoice(
      scanner: scanner,
      preprocessor: preprocessor,
      repository: repo,
      imageStore: store,
      clock: fixedClock(testT0),
      newId: () => 'id-${++n}',
    );
  });

  Future<CaptureResult> run({ScanSource source = ScanSource.camera}) =>
      capture(source: source, cancel: cancel);

  test('captures one page into a pending record', () async {
    final CaptureResult result = await run(source: ScanSource.gallery);
    expect(result, isA<CaptureSucceeded>());
    final InvoiceRecord record = (result as CaptureSucceeded).record;
    expect(record.id, 'id-1');
    expect(record.status, InvoiceStatus.pendingExtraction);
    expect(record.imagePaths, <String>['managed/id-1_0.jpg']);
    expect(record.createdAt, testT0);
    expect(repo.rows['id-1'], record);
    expect(scanner.lastSource, ScanSource.gallery);
  });

  test('asks the scanner for one page above the cap', () async {
    await run();
    expect(scanner.lastMaxPages, 6);
  });

  test('accepts exactly 5 pages and keeps their order', () async {
    scanner.result = <String>['s/1', 's/2', 's/3', 's/4', 's/5'];
    final CaptureResult result = await run();
    final InvoiceRecord record = (result as CaptureSucceeded).record;
    expect(record.imagePaths, <String>[
      for (int i = 0; i < 5; i++) 'managed/id-1_$i.jpg',
    ]);
  });

  test('rejects 6 pages without processing or storing anything', () async {
    scanner.result = <String>['s/1', 's/2', 's/3', 's/4', 's/5', 's/6'];
    final CaptureResult result = await run();
    expect(result, isA<CaptureTooManyPages>());
    expect((result as CaptureTooManyPages).maxPages, 5);
    expect(preprocessor.calls, 0);
    expect(repo.rows, isEmpty);
  });

  test('user cancellation inside the scanner is not an error', () async {
    scanner.result = null;
    expect(await run(), isA<CaptureCancelled>());
    scanner.result = <String>[];
    expect(await run(), isA<CaptureCancelled>());
    expect(repo.rows, isEmpty);
  });

  test('a token cancelled up front never opens the scanner', () async {
    cancel.cancel();
    expect(await run(), isA<CaptureCancelled>());
    expect(scanner.calls, 0);
  });

  test('scanner failures keep their debug code', () async {
    scanner.error = const InvoiceFailure(
      InvoiceErrorKind.unknown,
      debugCode: DebugCodes.cameraPermissionDenied,
    );
    final CaptureResult result = await run();
    expect(result, isA<CaptureFailed>());
    expect(
      (result as CaptureFailed).failure.debugCode,
      DebugCodes.cameraPermissionDenied,
    );
  });

  test('unexpected exceptions map to unknown without their message', () async {
    scanner.error = const FormatException('invoice text 1234');
    final CaptureFailed failed = await run() as CaptureFailed;
    expect(failed.failure.kind, InvoiceErrorKind.unknown);
    expect(failed.failure.debugCode, DebugCodes.unexpected);
    expect(failed.failure.toString(), isNot(contains('1234')));
  });

  test('a compression failure stores nothing', () async {
    preprocessor.error = const InvoiceFailure(
      InvoiceErrorKind.unknown,
      debugCode: DebugCodes.decodeFailed,
    );
    final CaptureFailed failed = await run() as CaptureFailed;
    expect(failed.failure.debugCode, DebugCodes.decodeFailed);
    expect(repo.rows, isEmpty);
  });

  test('cancellation reported by the preprocessor is a cancel', () async {
    preprocessor.error = const CancelledException();
    expect(await run(), isA<CaptureCancelled>());
    expect(repo.rows, isEmpty);
  });

  test('cancelling after compression deletes the compressed files', () async {
    preprocessor.afterCompress = cancel.cancel;
    expect(await run(), isA<CaptureCancelled>());
    expect(store.files, isEmpty);
    expect(repo.rows, isEmpty);
  });

  test('a failed insert deletes the compressed files', () async {
    repo.failInsert = true;
    final CaptureFailed failed = await run() as CaptureFailed;
    expect(failed.failure.debugCode, 'db');
    expect(store.files, isEmpty);
  });

  test(
    'a duplicate id fails without deleting the existing row files',
    () async {
      repo.rows['id-1'] = InvoiceRecord.queued(
        id: 'id-1',
        imagePaths: <String>['managed/id-1_0.jpg'],
        now: testT0,
      );
      final CaptureFailed failed = await run() as CaptureFailed;
      expect(failed.failure.debugCode, DebugCodes.duplicateId);
      expect(store.files, contains('managed/id-1_0.jpg'));
      expect(store.deleted, isEmpty);
    },
  );

  test('deletes the scanner source files after a successful capture', () async {
    scanner.result = <String>['scan/1.jpg', 'scan/2.jpg'];
    store.files.addAll(<String>['scan/1.jpg', 'scan/2.jpg']);
    expect(await run(), isA<CaptureSucceeded>());
    expect(store.files, <String>{'managed/id-1_0.jpg', 'managed/id-1_1.jpg'});
  });

  test(
    'deletes the scanner source files when rejecting too many pages',
    () async {
      final List<String> six = <String>[
        for (int i = 1; i <= 6; i++) 'scan/$i.jpg',
      ];
      scanner.result = six;
      store.files.addAll(six);
      expect(await run(), isA<CaptureTooManyPages>());
      expect(store.files, isEmpty);
    },
  );

  test('onPagesAccepted receives the scanner pages in order', () async {
    scanner.result = <String>['scan/1.jpg', 'scan/2.jpg'];
    List<String>? received;
    await capture(
      source: ScanSource.camera,
      cancel: cancel,
      onPagesAccepted: (List<String> pages) => received = pages,
    );
    expect(received, <String>['scan/1.jpg', 'scan/2.jpg']);
  });
}
