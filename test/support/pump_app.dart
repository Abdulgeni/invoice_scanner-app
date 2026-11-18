import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/theme/app_theme.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

Future<void> pumpLocalized(
  WidgetTester tester,
  Widget home, {
  bool reduceMotion = false,
  double textScale = 1,
  ThemeData? theme,
  TextDirection? textDirection,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData base = MediaQuery.of(context);
        Widget content = MediaQuery(
          data: base.copyWith(
            disableAnimations: reduceMotion || base.disableAnimations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
        if (textDirection != null) {
          content = Directionality(textDirection: textDirection, child: content);
        }
        return content;
      },
      home: home,
    ),
  );
}

/// Lets transitions finish without waiting on endless animations.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}
