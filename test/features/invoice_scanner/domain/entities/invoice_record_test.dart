import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

final DateTime t0 = DateTime.utc(2026, 11, 8, 10);
final DateTime t1 = DateTime.utc(2026, 11, 8, 10, 1);
final DateTime t2 = DateTime.utc(2026, 11, 8, 10, 2);

const Invoice extracted = Invoice(currency: Currency.usd, vendorName: 'Acme');
const Invoice edited = Invoice(currency: Currency.usd, vendorName: 'Acme Ltd');

InvoiceRecord queued() => InvoiceRecord.queued(
  id: 'id-1',
  imagePaths: <String>['/tmp/a.jpg', '/tmp/b.jpg'],
  now: t0,
);

void main() {
  test('queued starts pending with zero attempts', () {
    final InvoiceRecord r = queued();
    expect(r.status, InvoiceStatus.pendingExtraction);
    expect(r.attemptCount, 0);
    expect(r.createdAt, t0);
    expect(r.updatedAt, t0);
    expect(r.invoice, isNull);
    expect(r.remoteSyncedAt, isNull);
    expect(r.deletedAt, isNull);
    expect(() => r.imagePaths.add('x'), throwsUnsupportedError);
  });

  test('queued asserts UTC time and at least one page', () {
    expect(
      () => InvoiceRecord.queued(
        id: 'x',
        imagePaths: <String>['/a'],
        now: DateTime(2026, 11, 8),
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => InvoiceRecord.queued(id: 'x', imagePaths: <String>[], now: t0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('happy path: pending -> extracting -> needsReview -> saved', () {
    final InvoiceRecord extracting = queued().markExtracting(t1);
    expect(extracting.status, InvoiceStatus.extracting);
    expect(extracting.attemptCount, 1);

    final InvoiceRecord review = extracting.markNeedsReview(extracted, t1);
    expect(review.status, InvoiceStatus.needsReview);
    expect(review.invoice, extracted);

    final InvoiceRecord draft = review.withEditedInvoice(edited, t2);
    expect(draft.invoice, edited);
    expect(draft.status, InvoiceStatus.needsReview);

    final InvoiceRecord saved = draft.markSaved(edited, t2);
    expect(saved.status, InvoiceStatus.saved);
    expect(saved.savedAt, t2);
    expect(saved.imagePaths, isEmpty);
    expect(saved.invoice, edited);
  });

  test('failure and retry path counts attempts and clears the failure', () {
    final InvoiceRecord failed = queued()
        .markExtracting(t1)
        .markFailed(InvoiceErrorKind.timeout, t1);
    expect(failed.status, InvoiceStatus.failed);
    expect(failed.failureKind, InvoiceErrorKind.timeout);

    final InvoiceRecord retry = failed.markExtracting(t2);
    expect(retry.attemptCount, 2);
    expect(retry.failureKind, isNull);
    expect(retry.imagePaths, hasLength(2));
  });

  test('stale extracting record is recovered with markPending', () {
    final InvoiceRecord pending = queued().markExtracting(t1).markPending(t2);
    expect(pending.status, InvoiceStatus.pendingExtraction);
    expect(pending.attemptCount, 1);
  });

  test('offline failure can be set straight from pending', () {
    final InvoiceRecord failed = queued().markFailed(
      InvoiceErrorKind.network,
      t1,
    );
    expect(failed.failureKind, InvoiceErrorKind.network);
    expect(failed.markPending(t2).status, InvoiceStatus.pendingExtraction);
  });

  test('illegal transitions throw StateError', () {
    final InvoiceRecord pending = queued();
    final InvoiceRecord extracting = pending.markExtracting(t1);
    final InvoiceRecord review = extracting.markNeedsReview(extracted, t1);
    final InvoiceRecord saved = review.markSaved(extracted, t2);

    expect(() => pending.markNeedsReview(extracted, t1), throwsStateError);
    expect(() => pending.markSaved(extracted, t1), throwsStateError);
    expect(() => pending.withEditedInvoice(edited, t1), throwsStateError);
    expect(() => extracting.markExtracting(t1), throwsStateError);
    expect(() => extracting.markSaved(extracted, t1), throwsStateError);
    expect(
      () => review.markFailed(InvoiceErrorKind.unknown, t1),
      throwsStateError,
    );
    expect(() => saved.markExtracting(t2), throwsStateError);
    expect(() => saved.markPending(t2), throwsStateError);
    expect(() => saved.markSaved(extracted, t2), throwsStateError);
  });

  test('delete clears paths from any status and is idempotent', () {
    final InvoiceRecord deleted = queued().markExtracting(t1).markDeleted(t1);
    expect(deleted.isDeleted, isTrue);
    expect(deleted.deletedAt, t1);
    expect(deleted.imagePaths, isEmpty);
    expect(deleted.status, InvoiceStatus.extracting);

    final InvoiceRecord again = deleted.markDeleted(t2);
    expect(again.deletedAt, t1);
    expect(again.updatedAt, t2);

    final InvoiceRecord savedThenDeleted = queued()
        .markExtracting(t1)
        .markNeedsReview(extracted, t1)
        .markSaved(extracted, t1)
        .markDeleted(t2);
    expect(savedThenDeleted.invoice, extracted);
    expect(savedThenDeleted.isDeleted, isTrue);
  });

  test('constructor invariants are asserted', () {
    expect(
      () => InvoiceRecord(
        id: 'x',
        status: InvoiceStatus.needsReview,
        imagePaths: const <String>['/a'],
        attemptCount: 1,
        createdAt: t0,
        updatedAt: t0,
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => InvoiceRecord(
        id: 'x',
        status: InvoiceStatus.failed,
        imagePaths: const <String>['/a'],
        attemptCount: 1,
        createdAt: t0,
        updatedAt: t0,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('value equality', () {
    expect(queued(), queued());
    expect(queued(), isNot(queued().markExtracting(t1)));
  });
}
