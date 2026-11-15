import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:invoice_scanner/core/l10n/localized_number_parser.dart';
import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/core/theme/app_typography.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/delete_confirmation.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// A saved invoice, read-only, with permanent deletion.
class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({
    required this.record,
    required this.onDelete,
    super.key,
  });

  final InvoiceRecord record;
  final Future<DeleteOutcome> Function() onDelete;

  Future<void> _delete(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!await confirmDeleteInvoice(context)) return;
    final DeleteOutcome outcome = await onDelete();
    if (outcome == DeleteOutcome.storageUnavailable) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteFailedNotice)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.invoiceDeletedNotice)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Invoice? invoice = record.invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.detailTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => _delete(context),
            tooltip: l10n.deleteInvoiceTitle,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: invoice == null
            ? Center(child: Text(l10n.detailNothingToShow))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.maxContentWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                    children: <Widget>[
                      _HeaderCard(invoice: invoice),
                      const SizedBox(height: AppSpacing.md),
                      _LinesCard(invoice: invoice),
                      const SizedBox(height: AppSpacing.md),
                      _TotalsCard(invoice: invoice),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: emphasized
                    ? AppMoneyStyles.of(context).title
                    : text.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final String? vendor = invoice.vendorName?.trim();
    final String? number = invoice.invoiceNumber?.trim();
    final DateTime? date = invoice.invoiceDate;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                (vendor == null || vendor.isEmpty)
                    ? l10n.invoiceUnnamed
                    : vendor,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (number != null && number.isNotEmpty)
              _Row(label: l10n.invoiceNumberLabel, value: number),
            _Row(
              label: l10n.invoiceDateLabel,
              value: date == null
                  ? l10n.recentNoDate
                  : DateFormat.yMMMd(locale).format(date),
            ),
            _Row(label: l10n.currencyLabel, value: invoice.currency.code),
          ],
        ),
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();
    final MoneyFormatter money = MoneyFormatter(locale);
    final LocalizedNumberParser numbers = LocalizedNumberParser.forLocale(
      locale,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(l10n.reviewSectionLines, style: text.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (invoice.lineItems.isEmpty)
              Text(
                l10n.detailNoLines,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            for (final InvoiceLineItem item in invoice.lineItems)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: _LineRow(
                  description: item.description?.trim(),
                  detail: (item.quantity != null && item.unitPrice != null)
                      ? l10n.detailQuantityTimesPrice(
                          numbers.localize(item.quantity.toString()),
                          numbers.localize(item.unitPrice.toString()),
                        )
                      : null,
                  total: item.lineTotal == null
                      ? null
                      : money.format(item.lineTotal!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.description,
    required this.detail,
    required this.total,
  });

  final String? description;
  final String? detail;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String name = (description == null || description!.isEmpty)
        ? l10n.invoiceUnnamed
        : description!;
    return Semantics(
      container: true,
      label: <String?>[name, detail, total].whereType<String>().join(', '),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: text.bodyLarge),
                if (detail != null)
                  Text(
                    detail!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (total != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Text(total!, style: AppMoneyStyles.of(context).body),
          ],
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final MoneyFormatter money = MoneyFormatter(locale);
    final Money? subtotal = invoice.subtotal;
    final Money? tax = invoice.tax;
    final Money? total = invoice.total;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.reviewSectionTotals,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (subtotal != null)
              _Row(label: l10n.subtotalLabel, value: money.format(subtotal)),
            if (tax != null)
              _Row(label: l10n.taxLabel, value: money.format(tax)),
            _Row(
              label: l10n.totalLabel,
              value: total == null ? l10n.recentNoTotal : money.format(total),
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}
