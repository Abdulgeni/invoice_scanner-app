import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/recover_interrupted_work.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/update_review_draft.dart';

import '../../../../support/fakes.dart';

InvoiceRecord queued(String id) => InvoiceRecord.queued(
  id: id,
  imagePaths: <String>['managed/${id}_0.jpg'],
  now: testT0,
);

InvoiceRecord inReview(String id) =>
    queued(id).markExtracting(testT0).markNeedsReview(sampleInvoice(), testT0);

void main() {
  final DateTime now = testT0.add(const Duration(minutes: 5));
  late FakeInvoiceRepository repo;
  late FakeImageStore store;

  setUp(() {
    repo = FakeInvoiceRepository();
    store = FakeImageStore();
  });

  group('DeleteInvoice', () {
    late DeleteInvoice delete;
    setUp(() {
      delete = DeleteInvoice(
        repository: repo,
        imageStore: store,
        clock: fixedClock(now),
      );
    });

    test(
      'tombstones the row, erases the payload, deletes the images',
      () async {
        repo.rows['a'] = inReview('a');
        store.files.add('managed/a_0.jpg');
        expect(await delete('a'), DeleteOutcome.deleted);
        final InvoiceRecord row = repo.rows['a']!;
        expect(row.isDeleted, isTrue);
        expect(row.invoice, isNull);
        expect(row.extractedInvoice, isNull);
        expect(row.imagePaths, isEmpty);
        expect(store.files, isEmpty);
        expect(store.deleted, <String>['managed/a_0.jpg']);
      },
    );

    test('is idempotent', () async {
      repo.rows['a'] = inReview('a');
      store.files.add('managed/a_0.jpg');
      await delete('a');
      expect(await delete('a'), DeleteOutcome.deleted);
      expect(store.deleted, hasLength(1));
      expect(repo.rows['a']!.deletedAt, now);
    });

    test('reports a missing record', () async {
      expect(await delete('nope'), DeleteOutcome.notFound);
    });

    test('works while an extraction is in flight', () async {
      repo.rows['a'] = queued('a').markExtracting(testT0);
      store.files.add('managed/a_0.jpg');
      expect(await delete('a'), DeleteOutcome.deleted);
      expect(repo.rows['a']!.isDeleted, isTrue);
      expect(store.files, isEmpty);
    });

    test('a storage failure leaves the files alone', () async {
      repo.rows['a'] = inReview('a');
      store.files.add('managed/a_0.jpg');
      repo.failMutateCalls.add(1);
      expect(await delete('a'), DeleteOutcome.storageUnavailable);
      expect(store.files, contains('managed/a_0.jpg'));
      expect(repo.rows['a']!.isDeleted, isFalse);
    });
  });

  group('UpdateReviewDraft', () {
    late UpdateReviewDraft update;
    setUp(() {
      update = UpdateReviewDraft(repository: repo, clock: fixedClock(now));
    });

    test('persists edits and keeps the extraction snapshot', () async {
      repo.rows['a'] = inReview('a');
      final edited = sampleInvoice(vendor: 'Edited');
      expect(await update(recordId: 'a', invoice: edited), isTrue);
      expect(repo.rows['a']!.invoice, edited);
      expect(repo.rows['a']!.extractedInvoice, sampleInvoice());
      expect(repo.rows['a']!.updatedAt, now);
    });

    test(
      'returns false when missing, not in review, or storage fails',
      () async {
        expect(
          await update(recordId: 'nope', invoice: sampleInvoice()),
          isFalse,
        );

        repo.rows['b'] = queued('b');
        expect(await update(recordId: 'b', invoice: sampleInvoice()), isFalse);

        repo.rows['c'] = inReview('c');
        repo.failMutateCalls.add(repo.mutateCalls + 1);
        expect(await update(recordId: 'c', invoice: sampleInvoice()), isFalse);
      },
    );
  });

  group('RecoverInterruptedWork', () {
    late RecoverInterruptedWork recover;
    setUp(() {
      recover = RecoverInterruptedWork(
        repository: repo,
        imageStore: store,
        clock: fixedClock(now),
      );
    });

    test('resets stale extractions and sweeps orphans', () async {
      repo.rows['a'] = queued('a').markExtracting(testT0);
      repo.rows['b'] = queued('b');
      repo.rows['c'] = inReview('c');
      repo.rows['d'] = queued('d').markFailed(InvoiceErrorKind.timeout, testT0);
      repo.rows['e'] = inReview('e').markSaved(sampleInvoice(), testT0);
      repo.rows['f'] = queued('f').markDeleted(testT0);
      store.files.addAll(<String>[
        'managed/a_0.jpg',
        'managed/b_0.jpg',
        'managed/c_0.jpg',
        'managed/d_0.jpg',
        'managed/orphan.jpg',
      ]);

      expect(await recover(), 1);

      expect(repo.rows['a']!.status, InvoiceStatus.pendingExtraction);
      expect(repo.rows['a']!.attemptCount, 1);
      expect(repo.rows['b']!.status, InvoiceStatus.pendingExtraction);
      expect(repo.rows['c']!.status, InvoiceStatus.needsReview);
      expect(repo.rows['d']!.status, InvoiceStatus.failed);
      expect(repo.rows['d']!.failureKind, InvoiceErrorKind.timeout);

      final Set<String> kept = <String>{
        'managed/a_0.jpg',
        'managed/b_0.jpg',
        'managed/c_0.jpg',
        'managed/d_0.jpg',
      };
      expect(store.lastKeep, kept);
      expect(store.files, kept);
      expect(store.cleanScannerTempCalls, 1);
    });

    test('with nothing stale it resets nothing and still cleans up', () async {
      repo.rows['b'] = queued('b');
      store.files.add('managed/b_0.jpg');
      expect(await recover(), 0);
      expect(store.files, <String>{'managed/b_0.jpg'});
      expect(store.cleanScannerTempCalls, 1);
    });

    test('with no live records every managed image is an orphan', () async {
      store.files.add('managed/leftover.jpg');
      expect(await recover(), 0);
      expect(store.lastKeep, isEmpty);
      expect(store.files, isEmpty);
    });
  });
}
