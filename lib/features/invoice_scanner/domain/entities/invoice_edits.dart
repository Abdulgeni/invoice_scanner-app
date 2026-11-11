import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

/// Drops "unreadable" flags that no longer apply. A flag means "the model
/// returned something we could not represent", so it is only meaningful
/// while the field is still empty: once the user has entered a value, or
/// deleted the line the flag pointed at, it is resolved.
///
/// Container-level flags (`lineItems`) and `currency` cannot be judged from
/// a value and stay until dismissed.
Invoice pruneResolvedFlags(Invoice invoice) {
  if (invoice.unreadable.isEmpty) return invoice;
  final Set<FieldRef> kept = <FieldRef>{
    for (final FieldRef ref in invoice.unreadable)
      if (!_isResolved(invoice, ref)) ref,
  };
  if (kept.length == invoice.unreadable.length) return invoice;
  return invoice.copyWith(unreadable: Set<FieldRef>.unmodifiable(kept));
}

/// Removes one flag without changing any value (the user confirms the field
/// really is empty).
Invoice dismissFlag(Invoice invoice, FieldRef ref) {
  if (!invoice.unreadable.contains(ref)) return invoice;
  final Set<FieldRef> next = <FieldRef>{...invoice.unreadable}..remove(ref);
  return invoice.copyWith(unreadable: Set<FieldRef>.unmodifiable(next));
}

/// Applies a validator's one-tap fix.
Invoice applySuggestedFix(Invoice invoice, SuggestedFix fix) {
  return switch (fix) {
    SetMoneyFix(:final FieldRef field, :final Money value) =>
      switch (field.field) {
        InvoiceField.subtotal => invoice.copyWith(subtotal: () => value),
        InvoiceField.tax => invoice.copyWith(tax: () => value),
        InvoiceField.total => invoice.copyWith(total: () => value),
        _ => invoice,
      },
  };
}

bool _filled(String? text) => text != null && text.trim().isNotEmpty;

bool _isResolved(Invoice invoice, FieldRef ref) {
  InvoiceLineItem? line;
  final String? lineId = ref.lineId;
  if (lineId != null) {
    line = invoice.lineItems
        .where((InvoiceLineItem item) => item.id == lineId)
        .firstOrNull;
    if (line == null) return true; // the line was deleted
  }
  return switch (ref.field) {
    InvoiceField.vendorName => _filled(invoice.vendorName),
    InvoiceField.invoiceNumber => _filled(invoice.invoiceNumber),
    InvoiceField.invoiceDate => invoice.invoiceDate != null,
    InvoiceField.subtotal => invoice.subtotal != null,
    InvoiceField.tax => invoice.tax != null,
    InvoiceField.total => invoice.total != null,
    InvoiceField.lineDescription => _filled(line?.description),
    InvoiceField.lineQuantity => line?.quantity != null,
    InvoiceField.lineUnitPrice => line?.unitPrice != null,
    InvoiceField.lineTotal => line?.lineTotal != null,
    InvoiceField.currency || InvoiceField.lineItems => false,
  };
}

/// Applies [edit] to the line with [lineId] and keeps its total in step.
/// Other lines are untouched; an unknown id changes nothing.
Invoice editLine(
  Invoice invoice,
  String lineId,
  InvoiceLineItem Function(InvoiceLineItem line) edit,
) {
  return invoice.copyWith(
    lineItems: <InvoiceLineItem>[
      for (final InvoiceLineItem item in invoice.lineItems)
        item.id == lineId
            ? recalcLineTotal(item, edit(item), invoice.currency)
            : item,
    ],
  );
}

/// After a quantity or unit-price edit, keeps the line total in step when it
/// was in step before: empty, or exactly quantity x unit price rounded to the
/// currency (half away from zero). Any other total, including one the user
/// typed, is left alone so a manual total is never silently overwritten.
InvoiceLineItem recalcLineTotal(
  InvoiceLineItem before,
  InvoiceLineItem after,
  Currency currency,
) {
  if (before.quantity == after.quantity &&
      before.unitPrice == after.unitPrice) {
    return after;
  }
  final DecimalValue? quantity = after.quantity;
  final DecimalValue? unitPrice = after.unitPrice;
  if (quantity == null || unitPrice == null) return after;
  if (!_wasInStep(before, currency)) return after;
  final Money? expected = Money.tryFromDecimalRounded(
    quantity * unitPrice,
    currency,
  );
  if (expected == null) return after;
  return after.copyWith(lineTotal: () => expected);
}

bool _wasInStep(InvoiceLineItem line, Currency currency) {
  final Money? total = line.lineTotal;
  if (total == null) return true;
  final DecimalValue? quantity = line.quantity;
  final DecimalValue? unitPrice = line.unitPrice;
  if (quantity == null || unitPrice == null) return false;
  return Money.tryFromDecimalRounded(quantity * unitPrice, currency) == total;
}
