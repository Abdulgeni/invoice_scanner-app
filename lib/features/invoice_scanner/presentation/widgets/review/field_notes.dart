import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_colors.dart';
import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_edits.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/warning_messages.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// The findings for one field, shown directly under it: a gentle note with
/// an icon and words (never color alone), and the matching one-tap actions.
class FieldNotes extends StatelessWidget {
  const FieldNotes({
    required this.warnings,
    required this.currencyCode,
    required this.onChange,
    super.key,
  });

  final List<ValidationWarning> warnings;
  final String currencyCode;
  final void Function(Invoice Function(Invoice current) change) onChange;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ValidationWarning w in warnings)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: _Note(
                warning: w,
                currencyCode: currencyCode,
                onChange: onChange,
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.warning,
    required this.currencyCode,
    required this.onChange,
  });

  final ValidationWarning warning;
  final String currencyCode;
  final void Function(Invoice Function(Invoice current) change) onChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = AppSemanticColors.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final MoneyFormatter money = MoneyFormatter(locale);

    final bool isWarning = warning.severity == WarningSeverity.warning;
    final Color background = isWarning
        ? semantic.warningContainer
        : scheme.surfaceContainerHigh;
    final Color foreground = isWarning
        ? semantic.onWarningContainer
        : scheme.onSurfaceVariant;
    final String message = warningMessage(
      l10n,
      warning,
      money,
      currencyCode: currencyCode,
    );
    final String prefix = isWarning
        ? l10n.noteWarningPrefix
        : l10n.noteInfoPrefix;

    final List<Widget> actions = <Widget>[
      for (final SuggestedFix fix in warning.fixes)
        if (fix is SetMoneyFix)
          TextButton(
            onPressed: () =>
                onChange((Invoice inv) => applySuggestedFix(inv, fix)),
            child: Text(fixLabel(l10n, fix, money)),
          ),
      if (warning.code == ValidationCode.unreadableValue)
        TextButton(
          onPressed: () =>
              onChange((Invoice inv) => dismissFlag(inv, warning.field)),
          child: Text(l10n.dismissUnreadableAction),
        ),
      if (warning.code == ValidationCode.currencyAssumed)
        TextButton(
          onPressed: () =>
              onChange((Invoice inv) => inv.withCurrency(inv.currency)),
          child: Text(l10n.confirmCurrencyAction(currencyCode)),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              container: true,
              label: '$prefix: $message',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    isWarning
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    size: AppSizes.noteIcon,
                    color: foreground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: AppSpacing.sm, children: actions),
          ],
        ),
      ),
    );
  }
}
