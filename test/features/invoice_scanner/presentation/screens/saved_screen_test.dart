import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/saved_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';

void main() {
  late List<MethodCall> platformCalls;
  late int done, again;

  setUp(() {
    done = 0;
    again = 0;
    platformCalls = <MethodCall>[];
  });

  void mockPlatform(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  Widget screen(Invoice? invoice) => SavedScreen(
    invoice: invoice,
    onDone: () => done++,
    onScanAnother: () => again++,
  );

  testWidgets('shows what was saved and offers the next step', (tester) async {
    mockPlatform(tester);
    await pumpLocalized(tester, screen(sampleInvoice()));
    await tester.pumpAndSettle();

    expect(find.text('Invoice saved'), findsOneWidget);
    expect(find.textContaining('Acme'), findsOneWidget);
    expect(find.textContaining('33.00'), findsOneWidget);

    await tester.tap(find.text('Scan another'));
    await tester.tap(find.text('Done'));
    expect((again, done), (1, 1));
  });

  testWidgets('works when only the id is known', (tester) async {
    mockPlatform(tester);
    await pumpLocalized(tester, screen(null));
    await tester.pumpAndSettle();
    expect(find.text('Invoice saved'), findsOneWidget);
  });

  testWidgets('gives exactly one medium haptic tap', (tester) async {
    mockPlatform(tester);
    await pumpLocalized(tester, screen(sampleInvoice()));
    await tester.pumpAndSettle();
    final Iterable<MethodCall> taps = platformCalls.where(
      (MethodCall c) => c.method == 'HapticFeedback.vibrate',
    );
    expect(taps, hasLength(1));
    expect(taps.single.arguments, 'HapticFeedbackType.mediumImpact');
  });

  testWidgets(
    'the check animation settles, and is instant under reduce-motion',
    (tester) async {
      mockPlatform(tester);
      await pumpLocalized(tester, screen(sampleInvoice()));
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);

      await pumpLocalized(tester, screen(sampleInvoice()), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every button meets the 48dp touch target', (tester) async {
    mockPlatform(tester);
    await pumpLocalized(tester, screen(sampleInvoice()));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Scan another')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Done')).height,
      greaterThanOrEqualTo(48),
    );
  });
}
