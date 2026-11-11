import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
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
