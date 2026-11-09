import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/extraction_fields.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/extraction_mapper.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

IdGenerator sequentialIds() {
  int n = 0;
  return () => 'l${++n}';
}

Money usd(int minor) => Money.tryFromMinorUnits(minor, Currency.usd)!;
DecimalValue d(String s) => DecimalValue.tryParse(s)!;

Invoice parse(Map<String, Object?> body, {Currency fallback = Currency.usd}) {
  return parseExtraction(
    jsonEncode(<String, Object?>{'isInvoiceOrReceipt': true, ...body}),
    fallbackCurrency: fallback,
    newLineId: sequentialIds(),
  );
}

InvoiceFailure? failureOf(String text) {
  try {
    parseExtraction(
      text,
      fallbackCurrency: Currency.usd,
      newLineId: sequentialIds(),
    );
  } on InvoiceFailure catch (f) {
    return f;
  }
  return null;
}

void main() {
  test('a complete invoice maps field by field', () {
    final Invoice invoice = parse(<String, Object?>{
      'vendorName': ' Acme Ltd ',
      'invoiceNumber': 'A-1',
      'invoiceDate': '2026-11-01',
      'currency': 'eur',
      'lineItems': <Object?>[
        <String, Object?>{
          'description': 'Widget',
          'quantity': '2',
          'unitPrice': '5.00',
          'lineTotal': '10.00',
        },
      ],
      'subtotal': '10.00',
      'tax': '1.00',
      'total': '11.00',
    });
    Money eur(int m) => Money.tryFromMinorUnits(m, Currency.eur)!;
    expect(invoice.currency, Currency.eur);
    expect(invoice.currencyAssumed, isFalse);
    expect(invoice.vendorName, 'Acme Ltd');
    expect(invoice.invoiceNumber, 'A-1');
    expect(invoice.invoiceDate, DateTime.utc(2026, 11, 1));
    expect(invoice.lineItems, <InvoiceLineItem>[
      InvoiceLineItem(
        id: 'l1',
        description: 'Widget',
        quantity: d('2'),
        unitPrice: d('5'),
        lineTotal: eur(1000),
      ),
    ]);
    expect(invoice.subtotal, eur(1000));
    expect(invoice.tax, eur(100));
    expect(invoice.total, eur(1100));
    expect(invoice.unreadable, isEmpty);
  });

  group('shape and classification', () {
    test('not an invoice', () {
      final InvoiceFailure? f = failureOf('{"isInvoiceOrReceipt": false}');
      expect(f!.kind, InvoiceErrorKind.notAnInvoice);
    });

    test('anything that is not the expected JSON is malformed', () {
      for (final String bad in <String>[
        '',
        '   ',
        'not json',
        '[]',
        '42',
        '"text"',
        '{}',
        '{"isInvoiceOrReceipt": "true"}',
        '{"isInvoiceOrReceipt": null}',
        '{"isInvoiceOrReceipt": true',
      ]) {
        expect(
          failureOf(bad)?.kind,
          InvoiceErrorKind.malformedJson,
          reason: bad,
        );
      }
    });

    test('markdown fences are tolerated', () {
      expect(failureOf('```json\n{"isInvoiceOrReceipt": true}\n```'), isNull);
    });

    test('missing fields are null, never defaulted', () {
      final Invoice invoice = parse(<String, Object?>{});
      expect(invoice.vendorName, isNull);
      expect(invoice.invoiceNumber, isNull);
      expect(invoice.invoiceDate, isNull);
      expect(invoice.subtotal, isNull);
      expect(invoice.tax, isNull);
      expect(invoice.total, isNull);
      expect(invoice.lineItems, isEmpty);
      expect(invoice.unreadable, isEmpty);
    });
  });

  group('currency', () {
    test('a missing currency uses the fallback and is flagged assumed', () {
      final Invoice invoice = parse(
        <String, Object?>{},
        fallback: Currency.jpy,
      );
      expect(invoice.currency, Currency.jpy);
      expect(invoice.currencyAssumed, isTrue);
    });

    test('an unusable currency counts as missing', () {
      for (final Object? value in <Object?>['US\$', '', 'dollars', 5, null]) {
        final Invoice invoice = parse(<String, Object?>{'currency': value});
        expect(invoice.currency, Currency.usd, reason: '$value');
        expect(invoice.currencyAssumed, isTrue, reason: '$value');
      }
    });

    test('the exponent follows the currency', () {
      final Invoice yen = parse(<String, Object?>{
        'currency': 'JPY',
        'total': '1200',
      });
      expect(yen.total, Money.tryFromMinorUnits(1200, Currency.jpy));
      final Invoice yenBad = parse(<String, Object?>{
        'currency': 'JPY',
        'total': '12.5',
      });
      expect(yenBad.total, isNull);
      expect(yenBad.unreadable, contains(const FieldRef(InvoiceField.total)));
      final Invoice dinar = parse(<String, Object?>{
        'currency': 'KWD',
        'total': '1.234',
      });
      expect(dinar.total, Money.tryFromMinorUnits(1234, Currency.kwd));
    });
  });

  group('text and dates', () {
    test('text is trimmed, blank is null, numbers become text', () {
      final Invoice invoice = parse(<String, Object?>{
        'vendorName': '   ',
        'invoiceNumber': 12345,
      });
      expect(invoice.vendorName, isNull);
      expect(invoice.invoiceNumber, '12345');
      expect(invoice.unreadable, isEmpty);
    });

    test('wrong types are flagged unreadable', () {
      final Invoice invoice = parse(<String, Object?>{
        'vendorName': <String, Object?>{'x': 1},
        'invoiceDate': 5,
      });
      expect(invoice.vendorName, isNull);
      expect(invoice.invoiceDate, isNull);
      expect(invoice.unreadable, <FieldRef>{
        const FieldRef(InvoiceField.vendorName),
        const FieldRef(InvoiceField.invoiceDate),
      });
    });

    test('dates must be real YYYY-MM-DD dates', () {
      expect(
        parse(<String, Object?>{'invoiceDate': '2024-02-29'}).invoiceDate,
        DateTime.utc(2024, 2, 29),
      );
      for (final String bad in <String>['2023-02-29', '08/11/2026', 'today']) {
        final Invoice invoice = parse(<String, Object?>{'invoiceDate': bad});
        expect(invoice.invoiceDate, isNull, reason: bad);
        expect(
          invoice.unreadable,
          contains(const FieldRef(InvoiceField.invoiceDate)),
          reason: bad,
        );
      }
      expect(parse(<String, Object?>{'invoiceDate': null}).unreadable, isEmpty);
    });
  });

  group('amounts', () {
    const List<(Object?, int)> good = <(Object?, int)>[
      ('12.50', 1250),
      (12.5, 1250),
      (12, 1200),
      ('1,234.50', 123450),
      ('-5.00', -500),
      ('0', 0),
      ('  7.1 ', 710),
      ('(3.20)', -320),
    ];
    for (final (Object? input, int minor) in good) {
      test('accepts $input', () {
        final Invoice invoice = parse(<String, Object?>{'total': input});
        expect(invoice.total, usd(minor));
        expect(invoice.unreadable, isEmpty);
      });
    }

    const List<Object?> bad = <Object?>[
      '12,50',
      '12.345',
      'abc',
      r'$5.00',
      true,
      <String, Object?>{},
      <Object?>['1'],
      '1e5',
      '999999999999999',
    ];
    for (final Object? input in bad) {
      test('flags $input as unreadable, not zero', () {
        final Invoice invoice = parse(<String, Object?>{'total': input});
        expect(invoice.total, isNull);
        expect(invoice.unreadable, <FieldRef>{
          const FieldRef(InvoiceField.total),
        });
      });
    }

    for (final Object? input in <Object?>[null, '', '   ']) {
      test('treats "$input" as absent, not unreadable', () {
        final Invoice invoice = parse(<String, Object?>{'total': input});
        expect(invoice.total, isNull);
        expect(invoice.unreadable, isEmpty);
      });
    }
  });

  group('line items', () {
    test('keeps decimal quantities and unit prices beyond the currency', () {
      final Invoice invoice = parse(<String, Object?>{
        'lineItems': <Object?>[
          <String, Object?>{
            'description': 'Fuel',
            'quantity': '12.5',
            'unitPrice': '1.459',
            'lineTotal': '18.24',
          },
        ],
      });
      expect(invoice.lineItems, <InvoiceLineItem>[
        InvoiceLineItem(
          id: 'l1',
          description: 'Fuel',
          quantity: d('12.5'),
          unitPrice: d('1.459'),
          lineTotal: usd(1824),
        ),
      ]);
      expect(invoice.unreadable, isEmpty);
    });

    test('an all-null row is dropped silently', () {
      final Invoice invoice = parse(<String, Object?>{
        'lineItems': <Object?>[
          <String, Object?>{
            'description': null,
            'quantity': null,
            'unitPrice': null,
            'lineTotal': null,
          },
          <String, Object?>{'description': 'A'},
        ],
      });
      expect(invoice.lineItems, hasLength(1));
      expect(invoice.lineItems.single.description, 'A');
      expect(invoice.unreadable, isEmpty);
    });

    test('an unreadable cell is flagged against its own line', () {
      final Invoice invoice = parse(<String, Object?>{
        'lineItems': <Object?>[
          <String, Object?>{'description': 'A', 'quantity': 'two'},
        ],
      });
      final InvoiceLineItem line = invoice.lineItems.single;
      expect(line.quantity, isNull);
      expect(invoice.unreadable, <FieldRef>{
        FieldRef(InvoiceField.lineQuantity, lineId: line.id),
      });
    });

    test('a flagged row is kept even when everything else is null', () {
      final Invoice invoice = parse(<String, Object?>{
        'lineItems': <Object?>[
          <String, Object?>{'lineTotal': 'abc'},
        ],
      });
      expect(invoice.lineItems, hasLength(1));
      expect(invoice.unreadable, hasLength(1));
    });

    test('malformed rows and containers are flagged', () {
      final Invoice rows = parse(<String, Object?>{
        'lineItems': <Object?>[
          'x',
          <String, Object?>{'description': 'A'},
        ],
      });
      expect(rows.lineItems, hasLength(1));
      expect(rows.unreadable, contains(const FieldRef(InvoiceField.lineItems)));

      final Invoice notList = parse(<String, Object?>{'lineItems': 'none'});
      expect(notList.lineItems, isEmpty);
      expect(
        notList.unreadable,
        contains(const FieldRef(InvoiceField.lineItems)),
      );
    });

    test('rows beyond the limit are dropped and flagged', () {
      final Invoice invoice = parse(<String, Object?>{
        'lineItems': <Object?>[
          for (int i = 0; i < ExtractionLimits.maxLineItems + 1; i++)
            <String, Object?>{'description': 'Item $i'},
        ],
      });
      expect(invoice.lineItems, hasLength(ExtractionLimits.maxLineItems));
      expect(
        invoice.unreadable,
        contains(const FieldRef(InvoiceField.lineItems)),
      );
    });

    test('line ids are unique', () {
      final Invoice invoice = parse(<String, Object?>{
        'lineItems': <Object?>[
          <String, Object?>{'description': 'A'},
          <String, Object?>{'description': 'B'},
        ],
      });
      expect(
        invoice.lineItems.map((InvoiceLineItem l) => l.id).toSet(),
        hasLength(2),
      );
    });
  });
}
