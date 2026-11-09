import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';

/// Which kinds of field differ between what the model returned and what the
/// user confirmed. Text compares trimmed, with null equal to empty. Line
/// items match by id; added or removed lines count once as
/// [InvoiceField.lineItems]; reordering alone is not a change.
Set<InvoiceField> changedInvoiceFields(Invoice before, Invoice after) {
  final Set<InvoiceField> changed = <InvoiceField>{};

  if (_text(before.vendorName) != _text(after.vendorName)) {
    changed.add(InvoiceField.vendorName);
  }
  if (_text(before.invoiceNumber) != _text(after.invoiceNumber)) {
    changed.add(InvoiceField.invoiceNumber);
  }
  if (before.invoiceDate != after.invoiceDate) {
    changed.add(InvoiceField.invoiceDate);
  }
  if (before.currency != after.currency) changed.add(InvoiceField.currency);
  if (before.subtotal != after.subtotal) changed.add(InvoiceField.subtotal);
  if (before.tax != after.tax) changed.add(InvoiceField.tax);
  if (before.total != after.total) changed.add(InvoiceField.total);

  final Map<String, InvoiceLineItem> original = <String, InvoiceLineItem>{
    for (final InvoiceLineItem item in before.lineItems) item.id: item,
  };
  final Set<String> keptIds = <String>{};
  for (final InvoiceLineItem item in after.lineItems) {
    final InvoiceLineItem? old = original[item.id];
    if (old == null) {
      changed.add(InvoiceField.lineItems);
      continue;
    }
    keptIds.add(item.id);
    if (_text(old.description) != _text(item.description)) {
      changed.add(InvoiceField.lineDescription);
    }
    if (old.quantity != item.quantity) changed.add(InvoiceField.lineQuantity);
    if (old.unitPrice != item.unitPrice) {
      changed.add(InvoiceField.lineUnitPrice);
    }
    if (old.lineTotal != item.lineTotal) changed.add(InvoiceField.lineTotal);
  }
  if (keptIds.length != original.length) changed.add(InvoiceField.lineItems);

  return changed;
}

String _text(String? value) => (value ?? '').trim();
