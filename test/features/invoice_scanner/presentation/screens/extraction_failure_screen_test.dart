import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/extraction_failure_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/captured_page_stack.dart';

import '../../../../support/pump_app.dart';

late int retries, retakes, keeps, discards;

InvoiceExtractionFailure failureState(
  InvoiceErrorKind kind, {
  required bool canRetry,
  required bool retake,
}) {
  return InvoiceExtractionFailure(
    recordId: 'a',
    pagePaths: const <String>['managed/a_0.jpg'],
    source: ScanSource.camera,
    kind: kind,
    canRetry: canRetry,
    suggestsRetake: retake,
  );
}

Widget screen(InvoiceExtractionFailure state) => ExtractionFailureScreen(
  state: state,
  onRetry: () => retries++,
  onRetake: () => retakes++,
  onKeep: () => keeps++,
  onDiscard: () => discards++,
);

void main() {
  setUp(() {
    retries = 0;
    retakes = 0;
    keeps = 0;
    discards = 0;
  });

  const List<(InvoiceErrorKind, bool, bool, String)> cases =
      <(InvoiceErrorKind, bool, bool, String)>[
        (InvoiceErrorKind.network, true, false, "You're offline"),
        (InvoiceErrorKind.timeout, true, false, 'That took too long'),
        (InvoiceErrorKind.quotaExceeded, true, false, 'Scanning limit reached'),
        (InvoiceErrorKind.appCheckFailed, false, false, 'Update needed'),
        (InvoiceErrorKind.safetyBlock, false, true, "This image can't be used"),
        (InvoiceErrorKind.emptyResponse, true, true, 'Nothing to read here'),
        (
          InvoiceErrorKind.malformedJson,
          true,
          false,
          "We couldn't make sense of it",
        ),
        (
          InvoiceErrorKind.notAnInvoice,
          false,
          true,
          "This doesn't look like an invoice",
        ),
        (InvoiceErrorKind.unknown, true, false, 'Something went wrong'),
      ];

  for (final (InvoiceErrorKind kind, bool canRetry, bool retake, String title)
      in cases) {
    testWidgets('${kind.name}: its own title and the right actions', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        screen(failureState(kind, canRetry: canRetry, retake: retake)),
      );
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text('Try again'), canRetry ? findsOneWidget : findsNothing);
      expect(find.text('Retake'), retake ? findsOneWidget : findsNothing);
      expect(find.text('Keep image'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      if (retake) {
        expect(find.widgetWithText(FilledButton, 'Retake'), findsOneWidget);
        if (canRetry) {
          expect(
            find.widgetWithText(OutlinedButton, 'Try again'),
            findsOneWidget,
          );
        }
      } else if (canRetry) {
        expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      }
    });
  }

  testWidgets('every action calls back', (tester) async {
    await pumpLocalized(
      tester,
      screen(
        failureState(
          InvoiceErrorKind.emptyResponse,
          canRetry: true,
          retake: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retake'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retake'));
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.ensureVisible(find.text('Keep image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep image'));
    await tester.ensureVisible(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    expect((retries, retakes, keeps, discards), (1, 1, 1, 1));
  });

  testWidgets('the captured page stays visible behind the card', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      screen(
        failureState(InvoiceErrorKind.timeout, canRetry: true, retake: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CapturedPageStack), findsOneWidget);
  });

  testWidgets('every button meets the 48dp touch target', (tester) async {
    await pumpLocalized(
      tester,
      screen(
        failureState(
          InvoiceErrorKind.emptyResponse,
          canRetry: true,
          retake: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final Finder f in <Finder>[
      find.byType(FilledButton),
      find.byType(OutlinedButton),
      find.widgetWithText(TextButton, 'Keep image'),
      find.widgetWithText(TextButton, 'Discard'),
    ]) {
      expect(tester.getSize(f.first).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('stays usable on a small screen at double text size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);

    await pumpLocalized(
      tester,
      screen(
        failureState(
          InvoiceErrorKind.emptyResponse,
          canRetry: true,
          retake: true,
        ),
      ),
      textScale: 2,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Discard'), 100);
    await tester.ensureVisible(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    expect(discards, 1);
  });
}
