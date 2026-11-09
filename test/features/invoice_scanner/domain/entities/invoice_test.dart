import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

Money money(int minor, Currency c) => Money.tryFromMinorUnits(minor, c)!;
DecimalValue d(String s) => DecimalValue.tryParse(s)!;

void main() {
  group('InvoiceLineItem.copyWith', () {
    final InvoiceLineItem item = InvoiceLineItem(
      id: 'a',
      description: 'Widget',
      quantity: d('2'),
      unitPrice: d('3.5'),
      lineTotal: money(700, Currency.usd),
    );

    test('null argument leaves the field unchanged', () {
      expect(item.copyWith(), item);
    });

    test('a closure sets the field', () {
      expect(item.copyWith(description: () => 'Gadget').description, 'Gadget');
    });

    test('a closure returning null clears the field', () {
      final InvoiceLineItem cleared = item.copyWith(
        description: () => null,
        quantity: () => null,
        unitPrice: () => null,
        lineTotal: () => null,
      );
      expect(cleared.id, 'a');
      expect(cleared.description, isNull);
      expect(cleared.quantity, isNull);
      expect(cleared.unitPrice, isNull);
      expect(cleared.lineTotal, isNull);
    });
  });

  group('Invoice.copyWith', () {
    final Invoice invoice = Invoice(
      currency: Currency.usd,
      vendorName: 'Acme',
      invoiceNumber: 'A-1',
      invoiceDate: DateTime.utc(2026, 11, 8),
      total: money(1250, Currency.usd),
    );

    test('unchanged by default, equal by value', () {
      expect(invoice.copyWith(), invoice);
    });

    test('set and clear', () {
      final Invoice edited = invoice.copyWith(
        vendorName: () => 'Beta',
        invoiceNumber: () => null,
      );
      expect(edited.vendorName, 'Beta');
      expect(edited.invoiceNumber, isNull);
      expect(edited.total, invoice.total);
    });

    test('new invoices have no silent defaults', () {
      const Invoice empty = Invoice(currency: Currency.usd);
      expect(empty.vendorName, isNull);
      expect(empty.invoiceDate, isNull);
      expect(empty.subtotal, isNull);
      expect(empty.tax, isNull);
      expect(empty.total, isNull);
      expect(empty.lineItems, isEmpty);
      expect(empty.unreadable, isEmpty);
      expect(empty.currencyAssumed, isFalse);
    });

    test('unreadable participates in equality', () {
      final Invoice flagged = invoice.copyWith(
        unreadable: <FieldRef>{const FieldRef(InvoiceField.tax)},
      );
      expect(flagged, isNot(invoice));
    });
  });

  group('Invoice.withCurrency', () {
    final Invoice usdInvoice = Invoice(
      currency: Currency.usd,
      currencyAssumed: true,
      vendorName: 'Acme',
      lineItems: <InvoiceLineItem>[
        InvoiceLineItem(id: 'a', lineTotal: money(1250, Currency.usd)),
        InvoiceLineItem(id: 'b', lineTotal: money(1000, Currency.usd)),
        const InvoiceLineItem(id: 'c'),
      ],
      subtotal: money(1200, Currency.usd),
      tax: money(5, Currency.usd),
    );

    test('re-expresses exact amounts, flags inexact ones, clears assumed', () {
      final Invoice jpy = usdInvoice.withCurrency(Currency.jpy);
      expect(jpy.currency, Currency.jpy);
      expect(jpy.currencyAssumed, isFalse);
      expect(jpy.subtotal, money(12, Currency.jpy));
      expect(jpy.tax, isNull);
      expect(jpy.lineItems[0].lineTotal, isNull);
      expect(jpy.lineItems[1].lineTotal, money(10, Currency.jpy));
      expect(jpy.lineItems[2].lineTotal, isNull);
      expect(jpy.unreadable, <FieldRef>{
        const FieldRef(InvoiceField.tax),
        const FieldRef(InvoiceField.lineTotal, lineId: 'a'),
      });
      expect(jpy.vendorName, 'Acme');
    });

    test('never reinterprets minor units', () {
      final Invoice yen = Invoice(
        currency: Currency.jpy,
        subtotal: money(500, Currency.jpy),
      );
      expect(
        yen.withCurrency(Currency.usd).subtotal,
        money(50000, Currency.usd),
      );

      final Invoice kwd = Invoice(
        currency: Currency.kwd,
        total: money(1234, Currency.kwd),
      );
      final Invoice usd = kwd.withCurrency(Currency.usd);
      expect(usd.total, isNull);
      expect(usd.unreadable, contains(const FieldRef(InvoiceField.total)));
    });

    test('same currency only clears the assumed flag', () {
      final Invoice same = usdInvoice.withCurrency(Currency.usd);
      expect(same.currencyAssumed, isFalse);
      expect(same.subtotal, usdInvoice.subtotal);
      expect(same.unreadable, isEmpty);
    });

    test('keeps previously flagged fields', () {
      final Invoice flagged = usdInvoice.copyWith(
        unreadable: <FieldRef>{const FieldRef(InvoiceField.invoiceDate)},
      );
      expect(
        flagged.withCurrency(Currency.jpy).unreadable,
        contains(const FieldRef(InvoiceField.invoiceDate)),
      );
    });
  });

  test('FieldRef equality', () {
    expect(const FieldRef(InvoiceField.tax), const FieldRef(InvoiceField.tax));
    expect(
      const FieldRef(InvoiceField.lineTotal, lineId: 'a'),
      isNot(const FieldRef(InvoiceField.lineTotal, lineId: 'b')),
    );
  });
}
