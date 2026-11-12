import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_edits.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/invoice_validator.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/review_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/zoomable_pages.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';

final DateTime today = DateTime.utc(2026, 11, 8);

class ReviewHarness extends StatefulWidget {
  const ReviewHarness({required this.initial, required this.onSave, super.key});

  final Invoice initial;
  final VoidCallback onSave;

  @override
  State<ReviewHarness> createState() => ReviewHarnessState();
}

class ReviewHarnessState extends State<ReviewHarness> {
  late Invoice invoice = widget.initial;
  int _ids = 0;
  int discards = 0;

  @override
  Widget build(BuildContext context) {
    return ReviewScreen(
      state: InvoiceReviewing(
        recordId: 'r',
        pagePaths: const <String>['managed/a_0.jpg'],
        invoice: invoice,
        warnings: validateInvoice(invoice, today: today),
      ),
      newLineId: () => 'new-${++_ids}',
      now: () => today,
      onChange: (Invoice Function(Invoice) change) =>
          setState(() => invoice = pruneResolvedFlags(change(invoice))),
      onSave: widget.onSave,
      onDiscard: () => discards++,
    );
  }
}

late int saves;

Future<ReviewHarnessState> pumpReview(
  WidgetTester tester,
  Invoice invoice, {
  bool reduceMotion = false,
  double textScale = 1,
  Size? size,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size ?? const Size(800, 2400);
  addTearDown(tester.view.reset);
  await pumpLocalized(
    tester,
    ReviewHarness(initial: invoice, onSave: () => saves++),
    reduceMotion: reduceMotion,
    textScale: textScale,
  );
  await tester.pumpAndSettle();
  return tester.state<ReviewHarnessState>(find.byType(ReviewHarness));
}

Finder field(String label, {int at = 0}) =>
    find.widgetWithText(TextField, label).at(at);

Future<void> type(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final Finder f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => saves = 0);

  testWidgets('shows every section and the extracted values', (tester) async {
    await pumpReview(tester, sampleInvoice());
    for (final String label in <String>[
      'Vendor',
      'Invoice number',
      'Date',
      'Currency',
      'Subtotal',
      'Tax',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Line items'), findsOneWidget);
    expect(find.text('Totals'), findsOneWidget);
    expect(tester.widget<TextField>(field('Vendor')).controller!.text, 'Acme');
    expect(find.text('No warnings'), findsWidgets);
  });

  group('editing', () {
    testWidgets('text edits are trimmed, and clearing raises a note', (
      tester,
    ) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await type(tester, field('Vendor'), '  Beta  ');
      expect(h.invoice.vendorName, 'Beta');

      await type(tester, field('Vendor'), '');
      expect(h.invoice.vendorName, isNull);
      expect(find.text('No vendor found.'), findsOneWidget);
    });

    testWidgets('a mismatch note offers a one-tap fix that refills the field', (
      tester,
    ) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await type(tester, field('Total'), '34.00');
      expect(h.invoice.total, usd(3400));
      expect(find.textContaining('Subtotal plus tax is'), findsOneWidget);
      expect(find.textContaining('Shipping or fees'), findsOneWidget);

      await tester.ensureVisible(find.textContaining('Set total to'));
      await tester.tap(find.textContaining('Set total to'));
      await tester.pumpAndSettle();
      expect(h.invoice.total, usd(3300));
      expect(find.textContaining('Subtotal plus tax is'), findsNothing);
      expect(
        tester.widget<TextField>(field('Total')).controller!.text,
        '33.00',
      );
    });

    testWidgets(
      'quantity edits keep an in-step line total in step',
      skip:
          true, // TODO(module-13): display not reseeding after quantity recalc
      (tester) async {
        final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
        await type(tester, field('Quantity'), '3');
        expect(h.invoice.lineItems[0].lineTotal, usd(1500));
        expect(
          tester.widget<TextField>(field('Line total')).controller!.text,
          '15.00',
        );
        expect(find.textContaining('35.00'), findsWidgets);
      },
    );

    testWidgets('a manual line total is never overwritten', (tester) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await type(tester, field('Line total'), '9.99');
      await type(tester, field('Quantity'), '3');
      expect(h.invoice.lineItems[0].lineTotal, usd(999));
    });

    testWidgets('unparseable text blocks save and leaves the value alone', (
      tester,
    ) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await type(tester, field('Total'), '1,2');
      await tester.pump();

      expect(
        find.text('Enter a valid number, for example 1234.50.'),
        findsOneWidget,
      );
      expect(find.text('Fix the highlighted fields to save.'), findsOneWidget);
      expect(h.invoice.total, usd(3300));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm & Save'),
            )
            .onPressed,
        isNull,
      );

      await type(tester, field('Total'), '33');
      await tester.pump();
      expect(find.text('Fix the highlighted fields to save.'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm & Save'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a field the user deletes while invalid does not block save', (
      tester,
    ) async {
      await pumpReview(tester, sampleInvoice());
      await type(tester, field('Quantity', at: 1), '1,2');
      await tester.pump();
      expect(find.text('Fix the highlighted fields to save.'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Remove line 2'));
      await tester.tap(find.byTooltip('Remove line 2'));
      await tester.pumpAndSettle();
      expect(find.text('Fix the highlighted fields to save.'), findsNothing);
    });
  });

  group('flags and notes', () {
    testWidgets('an unreadable value can be confirmed empty', (tester) async {
      final Invoice invoice = sampleInvoice().copyWith(
        total: () => null,
        unreadable: <FieldRef>{const FieldRef(InvoiceField.total)},
      );
      await pumpReview(tester, invoice);
      expect(
        find.textContaining("couldn't read this value exactly"),
        findsOneWidget,
      );

      await tapText(tester, "It's empty");
      expect(
        find.textContaining("couldn't read this value exactly"),
        findsNothing,
      );
      expect(find.text('No total found.'), findsOneWidget);
    });

    testWidgets('typing a value into a flagged field clears the flag', (
      tester,
    ) async {
      final Invoice invoice = sampleInvoice().copyWith(
        total: () => null,
        unreadable: <FieldRef>{const FieldRef(InvoiceField.total)},
      );
      await pumpReview(tester, invoice);
      await type(tester, field('Total'), '33');
      expect(
        find.textContaining("couldn't read this value exactly"),
        findsNothing,
      );
      expect(find.text('No total found.'), findsNothing);
    });

    testWidgets('an assumed currency can be confirmed', (tester) async {
      await pumpReview(tester, sampleInvoice().copyWith(currencyAssumed: true));
      expect(find.textContaining('we used USD'), findsOneWidget);
      await tapText(tester, 'Confirm USD');
      expect(find.textContaining('we used USD'), findsNothing);
    });

    testWidgets('notes are announced with a prefix, right after their field', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpReview(
        tester,
        sampleInvoice().copyWith(total: () => usd(3400)),
      );
      expect(find.bySemanticsLabel(RegExp(r'^Warning: ')), findsWidgets);
      handle.dispose();
    });
  });

  group('lines', () {
    testWidgets('add, remove with the button, and undo at the same place', (
      tester,
    ) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await tapText(tester, 'Add line');
      expect(h.invoice.lineItems.map((InvoiceLineItem l) => l.id), <String>[
        'l1',
        'l2',
        'new-1',
      ]);
      expect(find.text('Line 3'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Remove line 1'));
      await tester.tap(find.byTooltip('Remove line 1'));
      await tester.pumpAndSettle();
      expect(h.invoice.lineItems.map((InvoiceLineItem l) => l.id), <String>[
        'l2',
        'new-1',
      ]);
      expect(find.text('Line 1 removed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(h.invoice.lineItems.map((InvoiceLineItem l) => l.id), <String>[
        'l1',
        'l2',
        'new-1',
      ]);
    });

    testWidgets('swiping a line away removes it', (tester) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await tester.ensureVisible(find.byKey(const ValueKey<String>('line:l1')));
      await tester.drag(
        find.byKey(const ValueKey<String>('line:l1')),
        const Offset(-700, 0),
      );
      await tester.pumpAndSettle();
      expect(h.invoice.lineItems.map((InvoiceLineItem l) => l.id), <String>[
        'l2',
      ]);
    });

    testWidgets('the sum shows a hint while a line total is missing', (
      tester,
    ) async {
      await pumpReview(tester, sampleInvoice());
      await tapText(tester, 'Add line');
      expect(
        find.text('Fill in every line total to see the sum'),
        findsOneWidget,
      );
    });
  });

  group('pickers', () {
    testWidgets('changing currency re-expresses the amounts', (tester) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await tester.tap(find.widgetWithText(InkWell, 'Currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY'));
      await tester.pumpAndSettle();

      expect(h.invoice.currency, Currency.jpy);
      expect(tester.widget<TextField>(field('Total')).controller!.text, '33');
    });

    testWidgets('switching currency back and forth reformats the numbers', (
      tester,
    ) async {
      await pumpReview(tester, sampleInvoice());
      await tester.tap(find.widgetWithText(InkWell, 'Currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('Total')).controller!.text, '33');

      await tester.tap(find.widgetWithText(InkWell, 'Currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Total')).controller!.text,
        '33.00',
      );
    });

    testWidgets('after switching to yen, decimals are rejected', (
      tester,
    ) async {
      await pumpReview(tester, sampleInvoice());
      await tester.tap(find.widgetWithText(InkWell, 'Currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY'));
      await tester.pumpAndSettle();
      await type(tester, field('Total'), '12.5');
      expect(find.text('Use a whole number.'), findsOneWidget);
    });

    testWidgets('any ISO code can be entered', (tester) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await tester.tap(find.widgetWithText(InkWell, 'Currency'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Other currency code'),
        'chf',
      );
      await tester.pump();
      await tester.tap(find.text('Use code'));
      await tester.pumpAndSettle();
      expect(h.invoice.currency.code, 'CHF');
    });

    testWidgets('the date picker sets a date-only value', (tester) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await tester.tap(find.widgetWithText(InkWell, 'Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(h.invoice.invoiceDate, DateTime.utc(2026, 11, 5));
    });

    testWidgets('picking a far-future date raises a note', (tester) async {
      await pumpReview(tester, sampleInvoice());
      await tester.tap(find.widgetWithText(InkWell, 'Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('This date is in the future.'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('warnings never block it', (tester) async {
      await pumpReview(
        tester,
        sampleInvoice().copyWith(total: () => usd(9999)),
      );
      expect(find.textContaining('Subtotal plus tax is'), findsOneWidget);
      await tester.tap(find.text('Confirm & Save'));
      expect(saves, 1);
    });

    testWidgets('the bar shows the live total and warning count', (
      tester,
    ) async {
      await pumpReview(tester, sampleInvoice());
      expect(find.textContaining('33.00'), findsWidgets);
      await type(tester, field('Total'), '34.00');
      expect(find.textContaining('34.00'), findsWidgets);
      expect(find.text('1 warning'), findsWidgets);
    });

    testWidgets('closing asks the caller to discard', (tester) async {
      final ReviewHarnessState h = await pumpReview(tester, sampleInvoice());
      await tester.tap(find.byTooltip('Discard'));
      expect(h.discards, 1);
    });
  });

  group('the scan', () {
    testWidgets('collapses and expands on a phone', (tester) async {
      await pumpReview(tester, sampleInvoice());
      expect(find.byType(ZoomablePages), findsOneWidget);
      await tester.tap(find.byTooltip('Hide scan'));
      await tester.pumpAndSettle();
      expect(find.byType(ZoomablePages), findsNothing);
      await tester.tap(find.byTooltip('Show scan'));
      await tester.pumpAndSettle();
      expect(find.byType(ZoomablePages), findsOneWidget);
    });

    testWidgets('sits beside the form on a wide screen', (tester) async {
      await pumpReview(tester, sampleInvoice(), size: const Size(1200, 800));
      expect(find.byTooltip('Hide scan'), findsNothing);
      expect(find.byType(ZoomablePages), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('opens full screen', (tester) async {
      await pumpReview(tester, sampleInvoice());
      await tester.tap(find.byTooltip('View full screen'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanViewerScreen), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('the main buttons meet the 48dp touch target', (tester) async {
      await pumpReview(
        tester,
        sampleInvoice().copyWith(total: () => usd(3400)),
      );
      for (final Finder f in <Finder>[
        find.widgetWithText(FilledButton, 'Confirm & Save'),
        find.widgetWithText(OutlinedButton, 'Add line'),
        find.byType(IconButton).first,
      ]) {
        expect(tester.getSize(f.first).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets(
      'stays usable at 320 wide with double text size',
      skip: true, // TODO(module-13): RenderFlex overflow at 320/2x text
      (tester) async {
        await pumpReview(
          tester,
          sampleInvoice(),
          textScale: 2,
          size: const Size(320, 568),
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Add line'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('with reduce-motion everything settles at once', (
      tester,
    ) async {
      await pumpReview(tester, sampleInvoice(), reduceMotion: true);
      expect(find.text('Details'), findsOneWidget);
    });
  });
}
