import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/db/invoice_codec.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

Money m(int minor, Currency c) => Money.tryFromMinorUnits(minor, c)!;
DecimalValue d(String s) => DecimalValue.tryParse(s)!;

Map<String, Object?> valid() => <String, Object?>{
  'v': 1,
  'cur': 'USD',
  'assumed': false,
  'vendor': null,
  'number': null,
  'date': null,
  'lines': <Object?>[],
  'sub': null,
  'tax': null,
  'tot': null,
  'unread': <Object?>[],
};

void main() {
  final Invoice rich = Invoice(
    currency: Currency.kwd,
    currencyAssumed: true,
    vendorName: 'Ünï Café "Ltd" 東京',
    invoiceNumber: 'A/1',
    invoiceDate: DateTime.utc(2026, 11, 1),
    lineItems: <InvoiceLineItem>[
      InvoiceLineItem(
        id: 'l1',
        description: 'x\nnewline',
        quantity: d('1.5'),
        unitPrice: d('1.459'),
        lineTotal: m(2188, Currency.kwd),
      ),
      const InvoiceLineItem(id: 'l2'),
    ],
    subtotal: m(2188, Currency.kwd),
    total: m(5, Currency.eur),
    unreadable: <FieldRef>{
      const FieldRef(InvoiceField.tax),
      const FieldRef(InvoiceField.lineTotal, lineId: 'l2'),
    },
  );

  test('a rich invoice survives a round trip exactly', () {
    expect(decodeInvoice(encodeInvoice(rich)), rich);
  });

  test('an empty invoice survives a round trip', () {
    const Invoice empty = Invoice(currency: Currency.jpy);
    expect(decodeInvoice(encodeInvoice(empty)), empty);
  });

  test('extreme values survive', () {
    final Invoice big = Invoice(
      currency: Currency.usd,
      total: Money.tryFromMinorUnits(Money.maxMinorUnits, Currency.usd),
      subtotal: Money.tryFromMinorUnits(-Money.maxMinorUnits, Currency.usd),
    );
    expect(decodeInvoice(encodeInvoice(big)), big);
  });

  test('output is deterministic regardless of set order', () {
    final Invoice a = Invoice(
      currency: Currency.usd,
      unreadable: <FieldRef>{
        const FieldRef(InvoiceField.total),
        const FieldRef(InvoiceField.tax),
      },
    );
    final Invoice b = Invoice(
      currency: Currency.usd,
      unreadable: <FieldRef>{
        const FieldRef(InvoiceField.tax),
        const FieldRef(InvoiceField.total),
      },
    );
    expect(encodeInvoice(a), encodeInvoice(b));
  });

  test('optional keys may be missing', () {
    final Invoice invoice = decodeInvoice('{"v":1,"cur":"USD"}');
    expect(invoice, const Invoice(currency: Currency.usd));
  });

  group('damaged payloads throw FormatException and nothing else', () {
    void bad(String name, Object? payload) {
      test(name, () {
        final String text = payload is String ? payload : jsonEncode(payload);
        expect(() => decodeInvoice(text), throwsFormatException);
      });
    }

    bad('empty string', '');
    bad('not json', 'garbage');
    bad('array root', <Object?>[]);
    bad('number root', 7);
    bad('missing version', <String, Object?>{'cur': 'USD'});
    bad('future version', valid()..['v'] = 2);
    bad('missing currency', valid()..remove('cur'));
    bad('bad currency', valid()..['cur'] = 'XX');
    bad('currency of the wrong type', valid()..['cur'] = 5);
    bad('lines not a list', valid()..['lines'] = 'x');
    bad(
      'line without an id',
      valid()..['lines'] = <Object?>[<String, Object?>{}],
    );
    bad('line that is not a map', valid()..['lines'] = <Object?>['x']);
    bad(
      'bad decimal',
      valid()
        ..['lines'] = <Object?>[
          <String, Object?>{'id': 'a', 'qty': 'abc'},
        ],
    );
    bad(
      'money with a string amount',
      valid()..['tot'] = <String, Object?>{'m': '1', 'c': 'USD'},
    );
    bad(
      'money beyond the limit',
      valid()..['tot'] = <String, Object?>{'m': 10000000000000000, 'c': 'USD'},
    );
    bad(
      'money with a bad currency',
      valid()..['tot'] = <String, Object?>{'m': 1, 'c': 'zz'},
    );
    bad('impossible date', valid()..['date'] = '2023-02-29');
    bad('date of the wrong type', valid()..['date'] = 20231101);
    bad(
      'unknown unreadable field',
      valid()
        ..['unread'] = <Object?>[
          <String, Object?>{'f': 'nonsense'},
        ],
    );
    bad(
      'unreadable entry that is not a map',
      valid()..['unread'] = <Object?>['x'],
    );
  });
}
