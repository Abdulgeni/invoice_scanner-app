import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/design_system/fade_in_up.dart';
import 'package:invoice_scanner/core/theme/app_colors.dart';
import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/error_presentation.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/captured_page_stack.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

class ExtractionFailureScreen extends StatelessWidget {
  const ExtractionFailureScreen({
    required this.state,
    required this.onRetry,
    required this.onRetake,
    required this.onKeep,
    required this.onDiscard,
    super.key,
  });

  final InvoiceExtractionFailure state;
  final VoidCallback onRetry;
  final VoidCallback onRetake;
  final VoidCallback onKeep;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ErrorPresentation presentation = presentationFor(l10n, state.kind);
    final ErrorPlan plan = planErrorActions(
      canRetry: state.canRetry,
      suggestsRetake: state.suggestsRetake,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxContentWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FadeInUp(
                    child: SizedBox(
                      height: AppSizes.failurePreviewHeight,
                      child: Center(
                        child: CapturedPageStack(
                          pagePaths: state.pagePaths,
                          dimmed: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeInUp(
                    delay: AppMotion.fast,
                    child: _ErrorCard(
                      presentation: presentation,
                      plan: plan,
                      onRetry: onRetry,
                      onRetake: onRetake,
                      onKeep: onKeep,
                      onDiscard: onDiscard,
                    ),
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.presentation,
    required this.plan,
    required this.onRetry,
    required this.onRetake,
    required this.onKeep,
    required this.onDiscard,
  });

  final ErrorPresentation presentation;
  final ErrorPlan plan;
  final VoidCallback onRetry;
  final VoidCallback onRetake;
  final VoidCallback onKeep;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = AppSemanticColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    const Size fullWidth = Size.fromHeight(AppSizes.minTouchTarget);

    final bool serious = presentation.tone == ErrorTone.serious;
    final Color badge = serious
        ? scheme.errorContainer
        : semantic.warningContainer;
    final Color onBadge = serious
        ? scheme.onErrorContainer
        : semantic.onWarningContainer;

    Widget action(ErrorAction a, {required bool primary}) {
      final VoidCallback onTap = a == ErrorAction.retry ? onRetry : onRetake;
      final String label = a == ErrorAction.retry
          ? l10n.retryAction
          : l10n.retakeAction;
      return primary
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(minimumSize: fullWidth),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(minimumSize: fullWidth),
              child: Text(label),
            );
    }

    final ErrorAction? primary = plan.primary;
    final ErrorAction? secondary = plan.secondary;

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              container: true,
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: badge,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                        child: Icon(
                          presentation.icon,
                          size: AppSizes.iconLg,
                          color: onBadge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      presentation.title,
                      textAlign: TextAlign.center,
                      style: text.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    presentation.message,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (primary != null) action(primary, primary: true),
            if (secondary != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              action(secondary, primary: false),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              children: <Widget>[
                TextButton(
                  onPressed: onKeep,
                  child: Text(l10n.keepImageAction),
                ),
                TextButton(
                  onPressed: onDiscard,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: Text(l10n.discardAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
