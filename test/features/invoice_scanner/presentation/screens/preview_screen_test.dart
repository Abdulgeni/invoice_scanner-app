import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/preview_screen.dart';

import '../../../../support/pump_app.dart';

void main() {
  late int read, retake, discard;

  Widget preview(List<String> paths) => PreviewScreen(
    pagePaths: paths,
    onRead: () => read++,
    onRetake: () => retake++,
    onDiscard: () => discard++,
  );

  setUp(() {
    read = 0;
    retake = 0;
    discard = 0;
  });

  testWidgets('the three actions fire their callbacks', (tester) async {
    await pumpLocalized(tester, preview(<String>['a.jpg']));
    await tester.pump();

    await tester.tap(find.text('Read invoice'));
    await tester.tap(find.text('Retake'));
    await tester.tap(find.byTooltip('Discard'));
    expect((read, retake, discard), (1, 1, 1));
  });

  testWidgets('a single page shows no counter or dots', (tester) async {
    await pumpLocalized(tester, preview(<String>['a.jpg']));
    await tester.pump();
    expect(find.textContaining('Page 1 of'), findsNothing);
  });

  testWidgets('multiple pages show a counter that follows the swipe', (
    tester,
  ) async {
    await pumpLocalized(tester, preview(<String>['a.jpg', 'b.jpg', 'c.jpg']));
    await tester.pump();
    expect(find.text('Page 1 of 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Page 2 of 3'), findsOneWidget);
  });

  testWidgets('the current page carries an image semantics label', (
    tester,
  ) async {
    // Verify the semantics label through the Semantics widget the page
    // builds, not through find.bySemanticsLabel: PageView merges its
    // children's semantics into the scroll node, so the widget-level
    // finder does not see the label even when it is set correctly.
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpLocalized(tester, preview(<String>['a.jpg', 'b.jpg']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Iterable<Semantics> labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where(
          (Semantics s) =>
              (s.properties.label ?? '').startsWith('Invoice page'),
        );
    expect(
      labels,
      isNotEmpty,
      reason: 'no Semantics widget with an "Invoice page N of M" label',
    );
    expect(labels.first.properties.label, 'Invoice page 1 of 2');
    expect(labels.first.properties.image, isTrue);

    handle.dispose();
  });

  testWidgets('the action buttons meet the 48dp touch target', (tester) async {
    await pumpLocalized(tester, preview(<String>['a.jpg']));
    await tester.pump();
    for (final Finder f in <Finder>[
      find.widgetWithText(FilledButton, 'Read invoice'),
      find.widgetWithText(OutlinedButton, 'Retake'),
      find.byType(IconButton),
    ]) {
      expect(tester.getSize(f.first).height, greaterThanOrEqualTo(48));
    }
  });
}
