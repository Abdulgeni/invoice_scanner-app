import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/theme/app_theme.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

Future<void> pumpLocalized(
  WidgetTester tester,
  Widget home, {
  bool reduceMotion = false,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      builder: (BuildContext context, Widget? child) {
        if (!reduceMotion) return child!;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        );
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
