// TEMPORARY. These functional stand-ins let the whole flow run before the
// processing UI (Module 9) and the review UI (Module 10) replace them.
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/error_messages.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

class ExtractingView extends StatelessWidget {
  const ExtractingView({
    required this.firstPagePath,
    required this.onCancel,
    super.key,
  });

  final String? firstPagePath;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? path = firstPagePath;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (path != null)
                  ClipRRect(
                    borderRadius: AppRadii.lgAll,
                    child: Image.file(
                      File(path),
                      height: AppSizes.thumbnail * 2,
                      fit: BoxFit.contain,
                      cacheHeight: (AppSizes.thumbnail * 4).round(),
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.stageReading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextButton(onPressed: onCancel, child: Text(l10n.cancelAction)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExtractionFailureView extends StatelessWidget {
  const ExtractionFailureView({
    required this.state,
    required this.onRetry,
    required this.onRetake,
    required this.onKeep,
    super.key,
  });

  final InvoiceExtractionFailure state;
  final VoidCallback onRetry;
  final VoidCallback onRetake;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    const Size fullWidth = Size.fromHeight(AppSizes.minTouchTarget);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      Icons.error_outline,
                      size: AppSizes.iconXl,
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(l10n.errorTitle, style: text.titleLarge),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    extractionErrorMessage(l10n, state.kind),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (state.canRetry)
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(minimumSize: fullWidth),
                      child: Text(l10n.retryAction),
                    ),
                  if (state.suggestsRetake) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: onRetake,
                      style: OutlinedButton.styleFrom(minimumSize: fullWidth),
                      child: Text(l10n.retakeAction),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onKeep,
                    style: TextButton.styleFrom(minimumSize: fullWidth),
                    child: Text(l10n.keepImageAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
