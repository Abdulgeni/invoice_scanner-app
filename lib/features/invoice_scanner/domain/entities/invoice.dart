import 'package:equatable/equatable.dart';

import 'package:invoice_scanner/core/util/nullable.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

enum InvoiceField {
  vendorName,
  invoiceNumber,
  invoiceDate,
  currency,
  subtotal,
  tax,
  total,
  lineItems,
  lineDescription,
  lineQuantity,
  lineUnitPrice,
  lineTotal,
}

/// Points at one field, or one field of one line item ([lineId]).
final class FieldRef extends Equatable {
  const FieldRef(this.field, {this.lineId});

  final InvoiceField field;
  final String? lineId;

  @override
  List<Object?> get props => <Object?>[field, lineId];
}

/// One invoice row. Everything except [id] may be missing; missing is
/// flagged by validation, never defaulted to zero.
final class InvoiceLineItem extends Equatable {
  const InvoiceLineItem({
    required this.id,
    this.description,
    this.quantity,
    this.unitPrice,
    this.lineTotal,
  });

  /// Stable local id so edits and swipe-to-delete survive reordering.
  final String id;
  final String? description;

  /// Decimal-safe: 1.5 kg, 2.25 hours.
  final DecimalValue? quantity;

  /// May carry more decimals than the currency (fuel at 1.459 per litre).
  final DecimalValue? unitPrice;
  final Money? lineTotal;

  InvoiceLineItem copyWith({
    Nullable<String>? description,
    Nullable<DecimalValue>? quantity,
    Nullable<DecimalValue>? unitPrice,
    Nullable<Money>? lineTotal,
  }) {
    return InvoiceLineItem(
      id: id,
      description: description == null ? this.description : description(),
      quantity: quantity == null ? this.quantity : quantity(),
      unitPrice: unitPrice == null ? this.unitPrice : unitPrice(),
      lineTotal: lineTotal == null ? this.lineTotal : lineTotal(),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    description,
    quantity,
    unitPrice,
    lineTotal,
  ];
}

/// Extracted or user-edited invoice data, before and after review.
///
/// By convention [lineItems] and [unreadable] are never mutated after
/// construction.
final class Invoice extends Equatable {
  const Invoice({
    required this.currency,
    this.currencyAssumed = false,
    this.vendorName,
    this.invoiceNumber,
    this.invoiceDate,
    this.lineItems = const <InvoiceLineItem>[],
    this.subtotal,
    this.tax,
    this.total,
    this.unreadable = const <FieldRef>{},
  });

  /// Every [Money] on this invoice uses this currency.
  final Currency currency;

  /// True when the model gave no currency and the app default was applied.
  /// Validation turns this into a visible warning.
  final bool currencyAssumed;

  final String? vendorName;
  final String? invoiceNumber;

  /// Calendar date as UTC midnight.
  final DateTime? invoiceDate;
  final List<InvoiceLineItem> lineItems;
  final Money? subtotal;
  final Money? tax;
  final Money? total;

  /// Fields the model returned but we could not represent exactly (for
  /// example 12.345 USD). Distinct from absent fields.
  final Set<FieldRef> unreadable;

  /// Does not accept a currency; use [withCurrency], which re-expresses
  /// every amount.
  Invoice copyWith({
    bool? currencyAssumed,
    Nullable<String>? vendorName,
    Nullable<String>? invoiceNumber,
    Nullable<DateTime>? invoiceDate,
    List<InvoiceLineItem>? lineItems,
    Nullable<Money>? subtotal,
    Nullable<Money>? tax,
    Nullable<Money>? total,
    Set<FieldRef>? unreadable,
  }) {
    return Invoice(
      currency: currency,
      currencyAssumed: currencyAssumed ?? this.currencyAssumed,
      vendorName: vendorName == null ? this.vendorName : vendorName(),
      invoiceNumber: invoiceNumber == null
          ? this.invoiceNumber
          : invoiceNumber(),
      invoiceDate: invoiceDate == null ? this.invoiceDate : invoiceDate(),
      lineItems: lineItems ?? this.lineItems,
      subtotal: subtotal == null ? this.subtotal : subtotal(),
      tax: tax == null ? this.tax : tax(),
      total: total == null ? this.total : total(),
      unreadable: unreadable ?? this.unreadable,
    );
  }

  /// Switches currency keeping every amount's numeric value. Amounts that
  /// cannot be expressed exactly (12.50 USD -> JPY) become null and are
  /// added to [unreadable]. The user has now chosen the currency, so
  /// [currencyAssumed] becomes false. Minor units are never reinterpreted.
  Invoice withCurrency(Currency newCurrency) {
    if (newCurrency == currency) return copyWith(currencyAssumed: false);

    final Set<FieldRef> flagged = <FieldRef>{...unreadable};
    Money? convert(Money? amount, FieldRef ref) {
      if (amount == null) return null;
      final Money? converted = Money.tryFromDecimalExact(
        amount.toDecimal(),
        newCurrency,
      );
      if (converted == null) flagged.add(ref);
      return converted;
    }

    return Invoice(
      currency: newCurrency,
      vendorName: vendorName,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      lineItems: <InvoiceLineItem>[
        for (final InvoiceLineItem item in lineItems)
          item.copyWith(
            lineTotal: () => convert(
              item.lineTotal,
              FieldRef(InvoiceField.lineTotal, lineId: item.id),
            ),
          ),
      ],
      subtotal: convert(subtotal, const FieldRef(InvoiceField.subtotal)),
      tax: convert(tax, const FieldRef(InvoiceField.tax)),
      total: convert(total, const FieldRef(InvoiceField.total)),
      unreadable: Set<FieldRef>.unmodifiable(flagged),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    currency,
    currencyAssumed,
    vendorName,
    invoiceNumber,
    invoiceDate,
    lineItems,
    subtotal,
    tax,
    total,
    unreadable,
  ];
}
