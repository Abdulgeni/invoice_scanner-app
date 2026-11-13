import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/invoice_detail_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';

late DeleteOutcome outcome;
late int deletes;

InvoiceRecord savedRecord(Invoice invoice) => InvoiceRecord.queued(
      id: 'x',
      imagePaths: <String>['managed/x_0.jpg'],
      now: testT0,
    )
        .markExtracting(testT0)
        .markNeedsReview(invoice, testT0)
        .markSaved(invoice, testT0);

Widget detail(Invoice invoice) => InvoiceDetailScreen(
      record: savedRecord(invoice),
      onDelete: () async {
        deletes++;
        return outcome;
      },
    );

Widget host(Invoice invoice) => Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => detail(invoice)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester, Invoice invoice) async {
  await pumpLocalized(tester, host(invoice));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    outcome = DeleteOutcome.deleted;
    deletes = 0;
  });

  testWidgets('shows the header, line items and totals', (tester) async {
    await open(tester, sampleInvoice());
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('A-1'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('Widget'), findsOneWidget);
    expect(find.text('2 × 5'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Tax'), findsOneWidget);
    expect(find.textContaining('33.00'), findsOneWidget);
  });

  testWidgets('hides what was never read', (tester) async {
    await open(tester, const Invoice(currency: Currency.usd));
    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('Tax'), findsNothing);
    expect(find.text('Invoice number'), findsNothing);
    expect(find.text('No line items were saved.'), findsOneWidget);
    expect(find.text('No total'), findsOneWidget);
    expect(find.text('Unnamed invoice'), findsOneWidget);
  });

  testWidgets('every row is announced as one label', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, sampleInvoice());
    expect(find.bySemanticsLabel(RegExp(r'^Total, ')), findsOneWidget);
    handle.dispose();
  });

  group('deleting', () {
    testWidgets('cancelling keeps everything', (tester) async {
      await open(tester, sampleInvoice());
      await tester.tap(find.byTooltip('Delete this invoice?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(find.byType(InvoiceDetailScreen), findsOneWidget);
    });

    testWidgets('confirming deletes, leaves the screen and says so',
        (tester) async {
      await open(tester, sampleInvoice());
      await tester.tap(find.byTooltip('Delete this invoice?'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.byType(InvoiceDetailScreen), findsNothing);
      expect(find.text('Invoice deleted'), findsOneWidget);
    });

    testWidgets('an invoice that is already gone counts as deleted',
        (tester) async {
      outcome = DeleteOutcome.notFound;
      await open(tester, sampleInvoice());
      await tester.tap(find.byTooltip('Delete this invoice?'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceDetailScreen), findsNothing);
    });

    testWidgets('a failure keeps the screen and reports it', (tester) async {
      outcome = DeleteOutcome.storageUnavailable;
      await open(tester, sampleInvoice());
      await tester.tap(find.byTooltip('Delete this invoice?'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceDetailScreen), findsOneWidget);
      expect(find.text("Couldn't delete. Please try again."), findsOneWidget);
    });
  });

  testWidgets('stays usable at 320 wide with double text size', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await pumpLocalized(tester, detail(sampleInvoice()), textScale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
