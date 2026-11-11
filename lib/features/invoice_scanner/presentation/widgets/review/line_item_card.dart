import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_edits.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/commit_fields.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/field_validity.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// One editable line. Swipe it away (toward the end edge) or use the button,
/// which is the accessible way to remove it.
class LineItemCard extends StatelessWidget {
  const LineItemCard({
    required this.index,
    required this.item,
    required this.currency,
    required this.notes,
    required this.validity,
    required this.onChange,
    required this.onRemove,
    super.key,
  });

  final int index;
  final InvoiceLineItem item;
  final Currency currency;

  /// Builds the notes widget for one of this line's fields.
  final Widget Function(FieldRef ref) notes;
  final FieldValidity validity;
  final void Function(Invoice Function(Invoice current) change) onChange;
  final VoidCallback onRemove;

  void _edit(InvoiceLineItem Function(InvoiceLineItem line) edit) =>
      onChange((Invoice inv) => editLine(inv, item.id, edit));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double gap = AppSpacing.md;

    Key keyFor(String part) => ValueKey<String>('line:${item.id}:$part');
    final Key totalKey = ValueKey<String>(
      'line:${item.id}:total:${currency.code}',
    );

    AmountField decimalField({
      required String part,
      required String label,
      required DecimalValue? value,
      required String example,
      required InvoiceLineItem Function(InvoiceLineItem, DecimalValue?) set,
    }) {
      return AmountField(
        key: keyFor(part),
        label: label,
        value: value,
        seed: (DecimalValue d) => d.toString(),
        problemFor: (DecimalValue d) => null,
        maxFractionDigits: 6,
        exampleCanonical: example,
        onChanged: (DecimalValue? d) =>
            _edit((InvoiceLineItem line) => set(line, d)),
        onValidityChanged: (bool valid) =>
            validity.report(keyFor(part), valid: valid),
      );
    }

    final Widget card = Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.lineNumberTitle(index + 1),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: l10n.removeLineTooltip(index + 1),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextEntryField(
              key: keyFor('desc'),
              label: l10n.lineDescriptionLabel,
              value: item.description,
              onChanged: (String? v) => _edit(
                (InvoiceLineItem line) => line.copyWith(description: () => v),
              ),
            ),
            notes(FieldRef(InvoiceField.lineDescription, lineId: item.id)),
            const SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: decimalField(
                    part: 'qty',
                    label: l10n.lineQuantityLabel,
                    value: item.quantity,
                    example: '2.5',
                    set: (InvoiceLineItem line, DecimalValue? d) =>
                        line.copyWith(quantity: () => d),
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: decimalField(
                    part: 'unit',
                    label: l10n.lineUnitPriceLabel,
                    value: item.unitPrice,
                    example: '12.5',
                    set: (InvoiceLineItem line, DecimalValue? d) =>
                        line.copyWith(unitPrice: () => d),
                  ),
                ),
              ],
            ),
            notes(FieldRef(InvoiceField.lineQuantity, lineId: item.id)),
            notes(FieldRef(InvoiceField.lineUnitPrice, lineId: item.id)),
            const SizedBox(height: gap),
            AmountField.money(
              key: totalKey,
              label: l10n.lineTotalLabel,
              money: item.lineTotal,
              currency: currency,
              onChanged: (DecimalValue? d) => _edit(
                (InvoiceLineItem line) => line.copyWith(
                  lineTotal: () =>
                      d == null ? null : Money.tryFromDecimalExact(d, currency),
                ),
              ),
              onValidityChanged: (bool valid) =>
                  validity.report(totalKey, valid: valid),
              textInputAction: TextInputAction.done,
            ),
            notes(FieldRef(InvoiceField.lineTotal, lineId: item.id)),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey<String>('swipe:${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (DismissDirection _) => onRemove(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: AppRadii.lgAll,
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: card,
    );
  }
}
