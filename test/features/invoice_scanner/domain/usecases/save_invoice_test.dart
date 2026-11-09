import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_diff.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/save_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';

import '../../../../support/fakes.dart';

void main() {
  const String id = 'id-1';
  const String page = 'managed/id-1_0.jpg';
  final DateTime now = testT0.add(const Duration(minutes: 5));

  late FakeInvoiceRepository repo;
  late FakeImageStore store;
  late RecordingAnalytics analytics;
  late SaveInvoice save;

  InvoiceRecord review() => InvoiceRecord.queued(
    id: id,
    imagePaths: <String>[page],
    now: testT0,
  ).markExtracting(testT0).markNeedsReview(sampleInvoice(), testT0);

  setUp(() {
    repo = FakeInvoiceRepository();
    store = FakeImageStore()..files.add(page);
    analytics = RecordingAnalytics();
    repo.rows[id] = review();
    save = SaveInvoice(
      repository: repo,
      imageStore: store,
      analytics: analytics,
      clock: fixedClock(now),
    );
  });

  group('SaveInvoice', () {
    test('commits, then deletes images and scanner temp files', () async {
      final Invoice confirmed = sampleInvoice();
      final SaveOutcome outcome = await save(
        recordId: id,
        confirmed: confirmed,
      );
      expect(outcome, isA<SaveSucceeded>());
      final InvoiceRecord record = (outcome as SaveSucceeded).record;
      expect(record.status, InvoiceStatus.saved);
      expect(record.invoice, confirmed);
      expect(record.imagePaths, isEmpty);
      expect(record.extractedInvoice, isNull);
      expect(record.savedAt, now);
      expect(repo.rows[id], record);
      expect(store.deleted, <String>[page]);
      expect(store.files, isEmpty);
      expect(store.cleanScannerTempCalls, 1);
    });

    test('no edits report zero corrections', () async {
      await save(recordId: id, confirmed: sampleInvoice());
      expect(analytics.corrections, isEmpty);
      expect(analytics.saves, <int>[0]);
    });

    test('reports one event per corrected field kind', () async {
      final Invoice base = sampleInvoice();
      final Invoice confirmed = base.copyWith(
        vendorName: () => 'Beta Ltd',
        total: () => usd(4000),
        lineItems: <InvoiceLineItem>[
          base.lineItems[0].copyWith(description: () => 'Widget XL'),
          base.lineItems[1].copyWith(lineTotal: () => usd(1)),
        ],
      );
      await save(recordId: id, confirmed: confirmed);
      expect(analytics.corrections.toSet(), <InvoiceField>{
        InvoiceField.vendorName,
        InvoiceField.total,
        InvoiceField.lineDescription,
        InvoiceField.lineTotal,
      });
      expect(analytics.corrections, hasLength(4));
      expect(analytics.saves, <int>[4]);
    });

    test('never blocks on validation: an empty invoice saves', () async {
      final SaveOutcome outcome = await save(
        recordId: id,
        confirmed: const Invoice(currency: Currency.usd),
      );
      expect(outcome, isA<SaveSucceeded>());
    });

    test('a record that is not in review is blocked and untouched', () async {
      repo.rows[id] = InvoiceRecord.queued(
        id: id,
        imagePaths: <String>[page],
        now: testT0,
      );
      final SaveBlocked blocked =
          await save(recordId: id, confirmed: sampleInvoice()) as SaveBlocked;
      expect(blocked.reason, SaveBlockReason.notInReview);
      expect(store.deleted, isEmpty);
      expect(analytics.saves, isEmpty);
    });

    test('saving twice is blocked the second time', () async {
      await save(recordId: id, confirmed: sampleInvoice());
      final SaveBlocked blocked =
          await save(recordId: id, confirmed: sampleInvoice()) as SaveBlocked;
      expect(blocked.reason, SaveBlockReason.notInReview);
      expect(analytics.saves, hasLength(1));
    });

    test('a missing record is reported', () async {
      repo.rows.clear();
      final SaveBlocked blocked =
          await save(recordId: id, confirmed: sampleInvoice()) as SaveBlocked;
      expect(blocked.reason, SaveBlockReason.notFound);
    });

    test('a storage failure keeps the files and the record', () async {
      repo.failMutateCalls.add(1);
      final SaveBlocked blocked =
          await save(recordId: id, confirmed: sampleInvoice()) as SaveBlocked;
      expect(blocked.reason, SaveBlockReason.storageUnavailable);
      expect(store.files, contains(page));
      expect(store.deleted, isEmpty);
      expect(repo.rows[id]!.status, InvoiceStatus.needsReview);
    });
  });

  group('changedInvoiceFields', () {
    final Invoice base = sampleInvoice();

    test('identical invoices have no changes', () {
      expect(changedInvoiceFields(base, sampleInvoice()), isEmpty);
    });

    test('whitespace and null-versus-empty text are not corrections', () {
      expect(
        changedInvoiceFields(
          base.copyWith(vendorName: () => 'Acme'),
          base.copyWith(vendorName: () => '  Acme '),
        ),
        isEmpty,
      );
      expect(
        changedInvoiceFields(
          base.copyWith(invoiceNumber: () => null),
          base.copyWith(invoiceNumber: () => ''),
        ),
        isEmpty,
      );
    });

    test('header and amount fields', () {
      final Invoice edited = base.copyWith(
        invoiceNumber: () => 'B-2',
        invoiceDate: () => DateTime.utc(2026, 10, 1),
        subtotal: () => usd(1),
        tax: () => null,
      );
      expect(changedInvoiceFields(base, edited), <InvoiceField>{
        InvoiceField.invoiceNumber,
        InvoiceField.invoiceDate,
        InvoiceField.subtotal,
        InvoiceField.tax,
      });
    });

    test('changing currency is reported as currency', () {
      expect(
        changedInvoiceFields(base, base.withCurrency(Currency.eur)),
        contains(InvoiceField.currency),
      );
    });

    test('added or removed lines count once as lineItems', () {
      final Invoice added = base.copyWith(
        lineItems: <InvoiceLineItem>[
          ...base.lineItems,
          const InvoiceLineItem(id: 'l3'),
          const InvoiceLineItem(id: 'l4'),
        ],
      );
      expect(changedInvoiceFields(base, added), <InvoiceField>{
        InvoiceField.lineItems,
      });
      final Invoice removed = base.copyWith(
        lineItems: <InvoiceLineItem>[base.lineItems.first],
      );
      expect(changedInvoiceFields(base, removed), <InvoiceField>{
        InvoiceField.lineItems,
      });
    });

    test('reordering lines is not a change', () {
      final Invoice reordered = base.copyWith(
        lineItems: base.lineItems.reversed.toList(),
      );
      expect(changedInvoiceFields(base, reordered), isEmpty);
    });

    test('line field changes are reported per kind', () {
      final Invoice edited = base.copyWith(
        lineItems: <InvoiceLineItem>[
          base.lineItems[0].copyWith(
            quantity: () => DecimalValue.fromInt(3),
            unitPrice: () => null,
          ),
          base.lineItems[1],
        ],
      );
      expect(changedInvoiceFields(base, edited), <InvoiceField>{
        InvoiceField.lineQuantity,
        InvoiceField.lineUnitPrice,
      });
    });
  });
}
