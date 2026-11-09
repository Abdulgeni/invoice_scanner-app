import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/extraction_fields.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/invoice_extraction_schema.dart';

void main() {
  final Schema schema = buildInvoiceSchema();
  final Map<String, Schema> props = schema.properties!;

  test('has exactly the fields the parser reads', () {
    expect(props.keys.toSet(), <String>{
      ExtractionFields.isInvoiceOrReceipt,
      ExtractionFields.vendorName,
      ExtractionFields.invoiceNumber,
      ExtractionFields.invoiceDate,
      ExtractionFields.currency,
      ExtractionFields.lineItems,
      ExtractionFields.subtotal,
      ExtractionFields.tax,
      ExtractionFields.total,
    });
    expect(Set<String>.of(schema.propertyOrdering!), props.keys.toSet());
  });

  test('every field is required: nothing is listed as optional', () {
    expect(schema.optionalProperties ?? <String>[], isEmpty);
    final Schema lineItem = props[ExtractionFields.lineItems]!.items!;
    expect(lineItem.optionalProperties ?? <String>[], isEmpty);
  });

  test('values that may be absent are nullable, the flag is not', () {
    for (final String key in <String>[
      ExtractionFields.vendorName,
      ExtractionFields.invoiceNumber,
      ExtractionFields.invoiceDate,
      ExtractionFields.currency,
      ExtractionFields.subtotal,
      ExtractionFields.tax,
      ExtractionFields.total,
    ]) {
      expect(props[key]!.nullable, isTrue, reason: key);
    }
    expect(props[ExtractionFields.isInvoiceOrReceipt]!.nullable, isNot(true));
  });

  test('money, quantity and dates are strings, never numbers', () {
    final Schema lineItem = props[ExtractionFields.lineItems]!.items!;
    final List<Schema> all = <Schema>[
      props[ExtractionFields.subtotal]!,
      props[ExtractionFields.tax]!,
      props[ExtractionFields.total]!,
      props[ExtractionFields.invoiceDate]!,
      ...lineItem.properties!.values,
    ];
    for (final Schema s in all) {
      expect(s.type, SchemaType.string);
    }
  });

  test('line items are bounded and carry every parsed field', () {
    final Schema lines = props[ExtractionFields.lineItems]!;
    expect(lines.maxItems, ExtractionLimits.maxLineItems);
    expect(lines.items!.properties!.keys.toSet(), <String>{
      ExtractionFields.description,
      ExtractionFields.quantity,
      ExtractionFields.unitPrice,
      ExtractionFields.lineTotal,
    });
  });

  test('the system instruction guards against document-borne instructions', () {
    expect(invoiceSystemInstruction, contains('not instructions'));
    expect(invoiceSystemInstruction.toLowerCase(), contains('never calculate'));
  });
}
