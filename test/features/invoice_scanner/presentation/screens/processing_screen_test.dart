import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/processing_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/captured_page_stack.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/scan_sweep.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/stage_progress.dart';

import '../../../../support/pump_app.dart';

Widget screen({
  ProcessingStage stage = ProcessingStage.reading,
  List<String> pages = const <String>['a.jpg'],
  VoidCallback? onCancel,
}) {
  return ProcessingScreen(stage: stage, pagePaths: pages, onCancel: onCancel);
}

List<double?> segmentValues(WidgetTester tester) => tester
    .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .map((LinearProgressIndicator p) => p.value)
    .toList();

void main() {
  testWidgets('names the stage and the step', (tester) async {
    const Map<ProcessingStage, (String, String)> expected =
        <ProcessingStage, (String, String)>{
          ProcessingStage.optimizing: ('Optimizing image', 'Step 1 of 3'),
          ProcessingStage.reading: ('Reading invoice', 'Step 2 of 3'),
          ProcessingStage.validating: ('Checking totals', 'Step 3 of 3'),
        };
    for (final MapEntry<ProcessingStage, (String, String)> e
        in expected.entries) {
      await pumpLocalized(tester, screen(stage: e.key));
      await tester.pump();
      expect(find.text(e.value.$1), findsOneWidget, reason: e.key.name);
      expect(find.text(e.value.$2), findsOneWidget, reason: e.key.name);
    }
  });

  testWidgets('the stage is announced as one live region', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpLocalized(tester, screen());
    await tester.pump();
    expect(
      find.bySemanticsLabel('Step 2 of 3, Reading invoice'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('segments fill in order (static under reduce-motion)', (
    tester,
  ) async {
    for (final (ProcessingStage stage, List<double> values)
        in <(ProcessingStage, List<double>)>[
          (ProcessingStage.optimizing, <double>[0.5, 0, 0]),
          (ProcessingStage.reading, <double>[1, 0.5, 0]),
          (ProcessingStage.validating, <double>[1, 1, 0.5]),
        ]) {
      await pumpLocalized(tester, screen(stage: stage), reduceMotion: true);
      await tester.pump();
      expect(segmentValues(tester), values, reason: stage.name);
    }
  });

  testWidgets('the active segment shimmers when motion is allowed', (
    tester,
  ) async {
    await pumpLocalized(tester, screen(stage: ProcessingStage.reading));
    await tester.pump();
    expect(segmentValues(tester), <double?>[1, null, 0]);
  });

  testWidgets('the captured pages are always on screen', (tester) async {
    await pumpLocalized(tester, screen(pages: <String>['missing.jpg']));
    await tester.pump();
    expect(find.byType(CapturedPageStack), findsOneWidget);
    // An empty list still shows the paper card rather than nothing.
    await pumpLocalized(tester, screen(pages: const <String>[]));
    await tester.pump();
    expect(find.byType(CapturedPageStack), findsOneWidget);
  });

  testWidgets('a multi-page scan shows its page count', (tester) async {
    await pumpLocalized(tester, screen(pages: <String>['a', 'b', 'c']));
    await tester.pump();
    expect(find.text('3 pages'), findsOneWidget);

    await pumpLocalized(tester, screen(pages: <String>['a']));
    await tester.pump();
    expect(find.text('1 page'), findsNothing);
  });

  testWidgets('Cancel calls back, and is hidden without a handler', (
    tester,
  ) async {
    int cancels = 0;
    await pumpLocalized(tester, screen(onCancel: () => cancels++));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    expect(cancels, 1);

    await pumpLocalized(tester, screen());
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
  });

  group('the sweep', () {
    Finder sweepPaint() => find.descendant(
      of: find.byType(ScanSweep),
      matching: find.byType(CustomPaint),
    );

    testWidgets('draws while motion is allowed', (tester) async {
      await pumpLocalized(tester, screen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(sweepPaint(), findsOneWidget);
    });

    testWidgets('draws nothing and nothing animates under reduce-motion', (
      tester,
    ) async {
      await pumpLocalized(tester, screen(), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(sweepPaint(), findsNothing);
    });
  });
}
