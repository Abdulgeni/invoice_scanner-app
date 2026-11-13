import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/home_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';

InvoiceRecord saved(String id, String vendor, int total) {
  final Invoice invoice = sampleInvoice(
    vendor: vendor,
  ).copyWith(total: () => usd(total));
  return InvoiceRecord.queued(
        id: id,
        imagePaths: <String>['managed/${id}_0.jpg'],
        now: testT0,
      )
      .markExtracting(testT0)
      .markNeedsReview(invoice, testT0)
      .markSaved(invoice, testT0);
}

void main() {
  late int scans, imports, tips;
  late List<String> opened;

  Widget home(Stream<List<InvoiceRecord>> stream, {bool tappable = false}) {
    return HomeScreen(
      watchRecent: () => stream,
      onScan: () => scans++,
      onImport: () => imports++,
      onShowTips: () => tips++,
      onOpenInvoice: tappable ? (InvoiceRecord r) => opened.add(r.id) : null,
    );
  }

  setUp(() {
    scans = 0;
    imports = 0;
    tips = 0;
    opened = <String>[];
  });

  testWidgets('shows the hero actions and an empty state', (tester) async {
    await pumpLocalized(
      tester,
      home(Stream<List<InvoiceRecord>>.value(const <InvoiceRecord>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan an invoice'), findsOneWidget);
    expect(find.text('Invoices you save will appear here.'), findsOneWidget);

    await tester.tap(find.text('Scan invoice'));
    await tester.tap(find.text('Import from gallery'));
    await tester.tap(find.byTooltip('Scanning tips'));
    expect((scans, imports, tips), (1, 1, 1));
  });

  testWidgets('lists recent invoices, at most five', (tester) async {
    final List<InvoiceRecord> records = <InvoiceRecord>[
      for (int i = 0; i < 7; i++) saved('r$i', 'Vendor $i', 1000 + i),
    ];
    await pumpLocalized(
      tester,
      home(Stream<List<InvoiceRecord>>.value(records)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vendor 0'), findsOneWidget);
    expect(find.text('Vendor 4'), findsOneWidget);
    expect(find.text('Vendor 5'), findsNothing);
    expect(find.textContaining('10.00'), findsOneWidget);
  });

  testWidgets('a missing vendor, date or total gets readable fallbacks', (
    tester,
  ) async {
    const Invoice bare = Invoice(currency: Currency.usd);
    final InvoiceRecord record =
        InvoiceRecord.queued(
              id: 'x',
              imagePaths: <String>['managed/x_0.jpg'],
              now: testT0,
            )
            .markExtracting(testT0)
            .markNeedsReview(bare, testT0)
            .markSaved(bare, testT0);
    await pumpLocalized(
      tester,
      home(Stream<List<InvoiceRecord>>.value(<InvoiceRecord>[record])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unnamed invoice'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
    expect(find.text('No total'), findsOneWidget);
  });

  testWidgets('recent invoices open only when a handler is given', (
    tester,
  ) async {
    final List<InvoiceRecord> records = <InvoiceRecord>[
      saved('r0', 'Acme', 500),
    ];
    await pumpLocalized(
      tester,
      home(Stream<List<InvoiceRecord>>.value(records), tappable: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme'));
    expect(opened, <String>['r0']);
  });

  testWidgets('every control meets the 48dp touch target', (tester) async {
    await pumpLocalized(
      tester,
      home(Stream<List<InvoiceRecord>>.value(const <InvoiceRecord>[])),
    );
    await tester.pumpAndSettle();
    for (final Finder f in <Finder>[
      find.widgetWithText(FilledButton, 'Scan invoice'),
      find.widgetWithText(TextButton, 'Import from gallery'),
      find.byType(IconButton),
    ]) {
      final Size size = tester.getSize(f.first);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('with reduce-motion the content is there immediately', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      home(Stream<List<InvoiceRecord>>.value(const <InvoiceRecord>[])),
      reduceMotion: true,
    );
    expect(find.text('Scan an invoice'), findsOneWidget);
  });

  testWidgets('each mount creates a fresh recent-invoices stream', (
    tester,
  ) async {
    int created = 0;
    Widget build() => HomeScreen(
      watchRecent: () {
        created++;
        return const Stream<List<InvoiceRecord>>.empty();
      },
      onScan: () {},
      onImport: () {},
      onShowTips: () {},
    );
    await pumpLocalized(tester, build());
    await tester.pumpAndSettle();
    await pumpLocalized(tester, const SizedBox());
    await pumpLocalized(tester, build());
    await tester.pumpAndSettle();
    expect(created, 2);
  });
}
