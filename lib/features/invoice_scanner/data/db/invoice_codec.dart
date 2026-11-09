import 'dart:convert';

import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/iso_date.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

const int _codecVersion = 1;

/// Versioned JSON for an [Invoice]. Money is stored as integer minor units
/// plus its own currency code (so an amount in a different currency than the
/// invoice survives a round trip), decimals as canonical strings, dates as
/// `YYYY-MM-DD`. Output is deterministic.
String encodeInvoice(Invoice invoice) {
  Map<String, Object?>? money(Money? m) => m == null
      ? null
      : <String, Object?>{'m': m.minorUnits, 'c': m.currency.code};

  final List<FieldRef> unreadable = invoice.unreadable.toList()
    ..sort((FieldRef a, FieldRef b) {
      final int byField = a.field.index.compareTo(b.field.index);
      return byField != 0
          ? byField
          : (a.lineId ?? '').compareTo(b.lineId ?? '');
    });

  return jsonEncode(<String, Object?>{
    'v': _codecVersion,
    'cur': invoice.currency.code,
    'assumed': invoice.currencyAssumed,
    'vendor': invoice.vendorName,
    'number': invoice.invoiceNumber,
    'date': invoice.invoiceDate == null
        ? null
        : formatIsoDate(dateOnly(invoice.invoiceDate!)),
    'lines': <Object?>[
      for (final InvoiceLineItem item in invoice.lineItems)
        <String, Object?>{
          'id': item.id,
          'desc': item.description,
          'qty': item.quantity?.toString(),
          'unit': item.unitPrice?.toString(),
          'total': money(item.lineTotal),
        },
    ],
    'sub': money(invoice.subtotal),
    'tax': money(invoice.tax),
    'tot': money(invoice.total),
    'unread': <Object?>[
      for (final FieldRef ref in unreadable)
        <String, Object?>{'f': ref.field.name, 'l': ref.lineId},
    ],
  });
}

/// Inverse of [encodeInvoice]. Throws [FormatException], and nothing else,
/// for anything that is not a valid payload.
Invoice decodeInvoice(String source) {
  try {
    return _decode(source);
  } on FormatException {
    rethrow;
  } catch (_) {
    // Wrong types in a tampered or damaged payload surface as TypeError or
    // ArgumentError; this is the untrusted-input boundary.
    throw const FormatException('invalid invoice payload');
  }
}

Invoice _decode(String source) {
  final Object? root = jsonDecode(source);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('root');
  }
  if (root['v'] != _codecVersion) throw const FormatException('version');

  final Currency? currency = Currency.tryParse(root['cur'] as String?);
  if (currency == null) throw const FormatException('currency');

  Money? money(Object? value) {
    if (value == null) return null;
    final Map<String, dynamic> map = value as Map<String, dynamic>;
    final Currency? c = Currency.tryParse(map['c'] as String?);
    final Money? parsed = c == null
        ? null
        : Money.tryFromMinorUnits(map['m'] as int, c);
    if (parsed == null) throw const FormatException('money');
    return parsed;
  }

  DecimalValue? decimal(Object? value) {
    if (value == null) return null;
    final DecimalValue? parsed = DecimalValue.tryParse(value as String);
    if (parsed == null) throw const FormatException('decimal');
    return parsed;
  }

  DateTime? date(Object? value) {
    if (value == null) return null;
    final DateTime? parsed = tryParseIsoDate(value as String);
    if (parsed == null) throw const FormatException('date');
    return parsed;
  }

  final List<dynamic> lines = (root['lines'] as List<dynamic>?) ?? <dynamic>[];
  final List<dynamic> unread =
      (root['unread'] as List<dynamic>?) ?? <dynamic>[];

  return Invoice(
    currency: currency,
    currencyAssumed: (root['assumed'] as bool?) ?? false,
    vendorName: root['vendor'] as String?,
    invoiceNumber: root['number'] as String?,
    invoiceDate: date(root['date']),
    lineItems: <InvoiceLineItem>[
      for (final dynamic raw in lines)
        () {
          final Map<String, dynamic> m = raw as Map<String, dynamic>;
          return InvoiceLineItem(
            id: m['id'] as String,
            description: m['desc'] as String?,
            quantity: decimal(m['qty']),
            unitPrice: decimal(m['unit']),
            lineTotal: money(m['total']),
          );
        }(),
    ],
    subtotal: money(root['sub']),
    tax: money(root['tax']),
    total: money(root['tot']),
    unreadable: Set<FieldRef>.unmodifiable(<FieldRef>{
      for (final dynamic raw in unread)
        FieldRef(
          InvoiceField.values.byName(
            (raw as Map<String, dynamic>)['f'] as String,
          ),
          lineId: raw['l'] as String?,
        ),
    }),
  );
}
