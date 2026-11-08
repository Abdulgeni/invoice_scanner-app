import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/design_system/pressable.dart';
import 'package:invoice_scanner/core/theme/app_colors.dart';
import 'package:invoice_scanner/core/theme/app_theme.dart';
import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/core/theme/app_typography.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

void main() {
  runApp(const InvoiceScannerApp());
}

class InvoiceScannerApp extends StatelessWidget {
  const InvoiceScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _ThemePreview(),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSemanticColors semantic = AppSemanticColors.of(context);
    final AppMoneyStyles money = AppMoneyStyles.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: semantic.heroGradient,
              borderRadius: AppRadii.xlAll,
              boxShadow: AppShadows.soft,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.homeLastInvoiceTotal,
                    style: text.labelLarge?.copyWith(color: semantic.onHero),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '1,284.50',
                    style: money.display.copyWith(color: semantic.onHero),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: semantic.warningContainer,
              borderRadius: AppRadii.mdAll,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Text(
                l10n.warningTotalMismatch('1,284.00', '1,284.50'),
                style: text.bodyMedium?.copyWith(
                  color: semantic.onWarningContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Pressable(
              semanticLabel: l10n.scanInvoiceSemantics,
              onPressed: () {},
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(l10n.scanAction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
