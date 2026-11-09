// ignore_for_file: prefer_final_locals

import 'dart:convert';

import 'package:invoice_scanner/core/l10n/localized_number_parser.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/extraction_fields.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/gemini_debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/iso_date.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

/// Turns the model's JSON text into an [Invoice].
///
/// Never invents values: absent or null stays null; a value that is present
/// but cannot be represented exactly becomes null and is listed in
/// `Invoice.unreadable`.
///
/// Throws [InvoiceFailure] with `malformedJson` (not JSON, wrong shape, or
/// the `isInvoiceOrReceipt` flag is missing) or `notAnInvoice`.
Invoice parseExtraction(
  String text, {
  required Currency fallbackCurrency,
  required IdGenerator newLineId,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(_stripFences(text));
  } on FormatException {
    throw const InvoiceFailure(
      InvoiceErrorKind.malformedJson,
      debugCode: GeminiDebugCodes.badJson,
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const InvoiceFailure(
      InvoiceErrorKind.malformedJson,
      debugCode: GeminiDebugCodes.badJson,
    );
  }

  final Object? flag = decoded[ExtractionFields.isInvoiceOrReceipt];
  if (flag is! bool) {
    throw const InvoiceFailure(
      InvoiceErrorKind.malformedJson,
      debugCode: GeminiDebugCodes.badJson,
    );
  }
  if (!flag) {
    throw const InvoiceFailure(
      InvoiceErrorKind.notAnInvoice,
      debugCode: GeminiDebugCodes.notInvoice,
    );
  }

  final Currency? stated = _currency(decoded[ExtractionFields.currency]);
  final Currency currency = stated ?? fallbackCurrency;
  final _Reader reader = _Reader(currency);

  final String? vendorName = reader.text(
    decoded[ExtractionFields.vendorName],
    const FieldRef(InvoiceField.vendorName),
  );
  final String? invoiceNumber = reader.text(
    decoded[ExtractionFields.invoiceNumber],
    const FieldRef(InvoiceField.invoiceNumber),
  );
  final DateTime? invoiceDate = reader.date(
    decoded[ExtractionFields.invoiceDate],
    const FieldRef(InvoiceField.invoiceDate),
  );
  final List<InvoiceLineItem> lines = reader.lines(
    decoded[ExtractionFields.lineItems],
    newLineId,
  );
  final Money? subtotal = reader.money(
    decoded[ExtractionFields.subtotal],
    const FieldRef(InvoiceField.subtotal),
  );
  final Money? tax = reader.money(
    decoded[ExtractionFields.tax],
    const FieldRef(InvoiceField.tax),
  );
  final Money? total = reader.money(
    decoded[ExtractionFields.total],
    const FieldRef(InvoiceField.total),
  );

  return Invoice(
    currency: currency,
    currencyAssumed: stated == null,
    vendorName: vendorName,
    invoiceNumber: invoiceNumber,
    invoiceDate: invoiceDate,
    lineItems: lines,
    subtotal: subtotal,
    tax: tax,
    total: total,
    unreadable: Set<FieldRef>.unmodifiable(reader.unreadable),
  );
}

Currency? _currency(Object? value) =>
    value is String ? Currency.tryParse(value) : null;

String _stripFences(String raw) {
  String s = raw.trim();
  if (s.startsWith('```')) {
    final int firstNewline = s.indexOf('\n');
    if (firstNewline != -1) s = s.substring(firstNewline + 1);
    if (s.endsWith('```')) s = s.substring(0, s.length - 3);
  }
  return s.trim();
}

final class _Reader {
  _Reader(this.currency);

  final Currency currency;
  final Set<FieldRef> unreadable = <FieldRef>{};

  static const FieldRef _linesRef = FieldRef(InvoiceField.lineItems);
  static final LocalizedNumberParser _en = LocalizedNumberParser.withSeparators(
    decimal: '.',
    group: ',',
  );

  String? text(Object? value, FieldRef ref) {
    if (value == null) return null;
    final String? s = switch (value) {
      String v => v,
      num v => v.toString(),
      _ => null,
    };
    if (s == null) {
      unreadable.add(ref);
      return null;
    }
    final String trimmed = s.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime? date(Object? value, FieldRef ref) {
    if (value == null) return null;
    if (value is! String) {
      unreadable.add(ref);
      return null;
    }
    if (value.trim().isEmpty) return null;
    final DateTime? parsed = tryParseIsoDate(value);
    if (parsed == null) unreadable.add(ref);
    return parsed;
  }

  DecimalValue? decimal(Object? value, FieldRef ref) {
    if (value == null) return null;
    final String? raw = switch (value) {
      String v => v.trim(),
      num v => v.toString(),
      _ => null,
    };
    if (raw == null) {
      unreadable.add(ref);
      return null;
    }
    if (raw.isEmpty) return null;
    final DecimalValue? parsed = DecimalValue.tryParse(raw) ?? _lenient(raw);
    if (parsed == null) unreadable.add(ref);
    return parsed;
  }

  /// Accepts "1,234.50" and "(3.20)". Ambiguous European input such as
  /// "12,50" is rejected, never guessed.
  DecimalValue? _lenient(String raw) {
    return switch (_en.parse(raw)) {
      DecimalParsed(:final String canonical) => DecimalValue.tryParse(
        canonical,
      ),
      DecimalParseFailed() => null,
    };
  }

  Money? money(Object? value, FieldRef ref) {
    final DecimalValue? parsed = decimal(value, ref);
    if (parsed == null) return null;
    final Money? exact = Money.tryFromDecimalExact(parsed, currency);
    if (exact == null) unreadable.add(ref);
    return exact;
  }

  List<InvoiceLineItem> lines(Object? value, IdGenerator newId) {
    if (value == null) return const <InvoiceLineItem>[];
    if (value is! List<dynamic>) {
      unreadable.add(_linesRef);
      return const <InvoiceLineItem>[];
    }
    final List<InvoiceLineItem> out = <InvoiceLineItem>[];
    for (final Object? element in value) {
      if (out.length >= ExtractionLimits.maxLineItems) {
        unreadable.add(_linesRef);
        break;
      }
      if (element is! Map<String, dynamic>) {
        unreadable.add(_linesRef);
        continue;
      }
      final String id = newId();
      final InvoiceLineItem item = InvoiceLineItem(
        id: id,
        description: text(
          element[ExtractionFields.description],
          FieldRef(InvoiceField.lineDescription, lineId: id),
        ),
        quantity: decimal(
          element[ExtractionFields.quantity],
          FieldRef(InvoiceField.lineQuantity, lineId: id),
        ),
        unitPrice: decimal(
          element[ExtractionFields.unitPrice],
          FieldRef(InvoiceField.lineUnitPrice, lineId: id),
        ),
        lineTotal: money(
          element[ExtractionFields.lineTotal],
          FieldRef(InvoiceField.lineTotal, lineId: id),
        ),
      );
      final bool blank =
          item.description == null &&
          item.quantity == null &&
          item.unitPrice == null &&
          item.lineTotal == null;
      final bool flagged = unreadable.any((FieldRef ref) => ref.lineId == id);
      // An all-null row with nothing flagged is noise, not a line item.
      if (blank && !flagged) continue;
      out.add(item);
    }
    return out;
  }
}
