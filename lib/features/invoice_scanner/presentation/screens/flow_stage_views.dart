// TEMPORARY stand-ins kept until Module 10 replaces them with the real
// review and saved screens.
import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

class ReviewingStubView extends StatelessWidget {
  const ReviewingStubView({
    required this.state,
    required this.onSave,
    required this.onDiscard,
    super.key,
  });

  final InvoiceReviewing state;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).toString();
    final int warnings = state.warnings
        .where((ValidationWarning w) => w.severity == WarningSeverity.warning)
        .length;
    final String vendor = (state.invoice.vendorName ?? '').trim().isEmpty
        ? l10n.invoiceUnnamed
        : state.invoice.vendorName!.trim();
    final String total = state.invoice.total == null
        ? l10n.recentNoTotal
        : MoneyFormatter(locale).format(state.invoice.total!);
    const Size fullWidth = Size.fromHeight(AppSizes.minTouchTarget);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(vendor, style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(total, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.warningsCount(warnings), style: text.bodyMedium),
              const Spacer(),
              FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(minimumSize: fullWidth),
                child: Text(l10n.confirmAndSaveAction),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onDiscard,
                style: TextButton.styleFrom(minimumSize: fullWidth),
                child: Text(l10n.discardAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavingView extends StatelessWidget {
  const SavingView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Semantics(liveRegion: true, child: Text(l10n.savingLabel)),
          ],
        ),
      ),
    );
  }
}

class SavedView extends StatelessWidget {
  const SavedView({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    Icons.check_circle_outline,
                    size: AppSizes.iconXl,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.savedTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(onPressed: onDone, child: Text(l10n.doneAction)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
