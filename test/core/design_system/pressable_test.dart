import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/design_system/pressable.dart';
import 'package:invoice_scanner/core/theme/app_colors.dart';
import 'package:invoice_scanner/core/theme/app_theme.dart';
import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/core/theme/app_typography.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('is at least 48dp even with a tiny child', (tester) async {
    await tester.pumpWidget(
      _host(
        Pressable(
          semanticLabel: 'Scan invoice',
          onPressed: () {},
          child: const SizedBox(width: 8, height: 8),
        ),
      ),
    );
    final Size size = tester.getSize(find.byType(Pressable));
    expect(size.width, greaterThanOrEqualTo(AppSizes.minTouchTarget));
    expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
  });

  testWidgets('exposes its semantic label and fires onPressed', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int taps = 0;
    await tester.pumpWidget(
      _host(
        Pressable(
          semanticLabel: 'Scan invoice',
          onPressed: () => taps++,
          child: const Text('Scan'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Scan invoice'), findsOneWidget);
    await tester.tap(find.byType(Pressable));
    expect(taps, 1);
    handle.dispose();
  });

  // [M1-ADJUST-2] Replaces the weak counter test with a semantics assertion.
  testWidgets(
    'disabled when onPressed is null (semantics has no enabled flag)',
    (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const Pressable(
            semanticLabel: 'Disabled',
            onPressed: null,
            child: Text('x'),
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(find.byType(Pressable));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.flagsCollection.isButton, isTrue);
      await tester.tap(find.byType(Pressable));
      handle.dispose();
    },
  );

  testWidgets('reduce-motion resolves durations to zero', (tester) async {
    late Duration resolved;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (BuildContext context) {
            resolved = AppMotion.resolve(context, AppMotion.slow);
            return const SizedBox.shrink();
          },
        ),
        disableAnimations: true,
      ),
    );
    expect(resolved, Duration.zero);
  });

  test('both themes carry the custom extensions', () {
    for (final ThemeData t in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      expect(t.extension<AppSemanticColors>(), isNotNull);
      expect(t.extension<AppMoneyStyles>(), isNotNull);
      expect(
        t.extension<AppMoneyStyles>()!.display.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    }
  });
}
