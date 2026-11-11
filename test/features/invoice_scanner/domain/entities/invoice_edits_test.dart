import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_edits.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

Money usd(int m) => Money.tryFromMinorUnits(m, Currency.usd)!;

const FieldRef totalRef = FieldRef(InvoiceField.total);
const FieldRef taxRef = FieldRef(InvoiceField.tax);

void main() {
  group('pruneResolvedFlags', () {
    test('keeps flags on fields that are still empty', () {
      final Invoice invoice = Invoice(
        currency: Currency.usd,
        unreadable: <FieldRef>{totalRef, taxRef},
      );
      expect(pruneResolvedFlags(invoice), same(invoice));
    });

    test('drops a flag once the field has a value', () {
      final Invoice invoice = Invoice(
        currency: Currency.usd,
        total: usd(100),
        unreadable: <FieldRef>{totalRef, taxRef},
      );
      expect(pruneResolvedFlags(invoice).unreadable, <FieldRef>{taxRef});
    });

    test('text fields need non-blank text', () {
      const FieldRef vendor = FieldRef(InvoiceField.vendorName);
      Invoice withVendor(String? v) => Invoice(
        currency: Currency.usd,
        vendorName: v,
        unreadable: <FieldRef>{vendor},
      );
      expect(pruneResolvedFlags(withVendor('  ')).unreadable, <FieldRef>{
        vendor,
      });
      expect(pruneResolvedFlags(withVendor('Acme')).unreadable, isEmpty);
    });

    test('line flags follow their own line', () {
      const FieldRef qty = FieldRef(InvoiceField.lineQuantity, lineId: 'a');
      const FieldRef total = FieldRef(InvoiceField.lineTotal, lineId: 'a');
      final Invoice invoice = Invoice(
        currency: Currency.usd,
        lineItems: <InvoiceLineItem>[
          InvoiceLineItem(id: 'a', quantity: DecimalValue.fromInt(2)),
        ],
        unreadable: <FieldRef>{qty, total},
      );
      expect(pruneResolvedFlags(invoice).unreadable, <FieldRef>{total});
    });

    test('flags for a deleted line are dropped', () {
      const FieldRef gone = FieldRef(InvoiceField.lineTotal, lineId: 'gone');
      final Invoice invoice = Invoice(
        currency: Currency.usd,
        unreadable: <FieldRef>{gone},
      );
      expect(pruneResolvedFlags(invoice).unreadable, isEmpty);
    });

    test('container and currency flags stay until dismissed', () {
      const FieldRef lines = FieldRef(InvoiceField.lineItems);
      const FieldRef currency = FieldRef(InvoiceField.currency);
      final Invoice invoice = Invoice(
        currency: Currency.usd,
        unreadable: <FieldRef>{lines, currency},
      );
      expect(pruneResolvedFlags(invoice).unreadable, <FieldRef>{
        lines,
        currency,
      });
    });
  });

  group('dismissFlag', () {
    test('removes only the named flag and no values', () {
      final Invoice invoice = Invoice(
        currency: Currency.usd,
        unreadable: <FieldRef>{totalRef, taxRef},
      );
      final Invoice next = dismissFlag(invoice, taxRef);
      expect(next.unreadable, <FieldRef>{totalRef});
      expect(next.total, isNull);
    });

    test('an unknown flag changes nothing', () {
      const Invoice invoice = Invoice(currency: Currency.usd);
      expect(dismissFlag(invoice, taxRef), same(invoice));
    });
  });

  group('applySuggestedFix', () {
    final Invoice invoice = Invoice(currency: Currency.usd, total: usd(3400));

    test('sets the named amount', () {
      expect(
        applySuggestedFix(invoice, SetMoneyFix(totalRef, usd(3300))).total,
        usd(3300),
      );
      expect(
        applySuggestedFix(
          invoice,
          SetMoneyFix(const FieldRef(InvoiceField.subtotal), usd(3100)),
        ).subtotal,
        usd(3100),
      );
      expect(
        applySuggestedFix(invoice, SetMoneyFix(taxRef, usd(5))).tax,
        usd(5),
      );
    });

    test('a fix for a non-amount field is ignored', () {
      final Invoice same = applySuggestedFix(
        invoice,
        SetMoneyFix(const FieldRef(InvoiceField.vendorName), usd(1)),
      );
      expect(same, invoice);
    });
  });

  group('recalcLineTotal', () {
    DecimalValue d(String s) => DecimalValue.tryParse(s)!;
    InvoiceLineItem line({
      String? qty,
      String? unit,
      int? total,
      Currency c = Currency.usd,
    }) => InvoiceLineItem(
      id: 'a',
      quantity: qty == null ? null : d(qty),
      unitPrice: unit == null ? null : d(unit),
      lineTotal: total == null ? null : Money.tryFromMinorUnits(total, c),
    );
    Money usdm(int m) => Money.tryFromMinorUnits(m, Currency.usd)!;

    test('an in-step total follows the new quantity', () {
      final InvoiceLineItem before = line(qty: '2', unit: '5.00', total: 1000);
      final InvoiceLineItem after = before.copyWith(quantity: () => d('3'));
      expect(
        recalcLineTotal(before, after, Currency.usd).lineTotal,
        usdm(1500),
      );
    });

    test('an empty total is filled once quantity and price are known', () {
      final InvoiceLineItem before = line(qty: '2');
      final InvoiceLineItem after = before.copyWith(unitPrice: () => d('5.00'));
      expect(
        recalcLineTotal(before, after, Currency.usd).lineTotal,
        usdm(1000),
      );
    });

    test('a manual total is never overwritten', () {
      final InvoiceLineItem before = line(qty: '2', unit: '5.00', total: 999);
      final InvoiceLineItem after = before.copyWith(quantity: () => d('3'));
      expect(recalcLineTotal(before, after, Currency.usd).lineTotal, usdm(999));
    });

    test('a total with no quantity or price behind it is left alone', () {
      final InvoiceLineItem before = line(total: 500);
      final InvoiceLineItem after = before.copyWith(
        quantity: () => d('2'),
        unitPrice: () => d('1'),
      );
      expect(recalcLineTotal(before, after, Currency.usd).lineTotal, usdm(500));
    });

    test('edits to other fields change nothing', () {
      final InvoiceLineItem before = line(qty: '2', unit: '5.00', total: 999);
      final InvoiceLineItem after = before.copyWith(description: () => 'x');
      expect(recalcLineTotal(before, after, Currency.usd), after);
    });

    test('a cleared quantity leaves the total alone', () {
      final InvoiceLineItem before = line(qty: '2', unit: '5.00', total: 1000);
      final InvoiceLineItem after = before.copyWith(quantity: () => null);
      expect(
        recalcLineTotal(before, after, Currency.usd).lineTotal,
        usdm(1000),
      );
    });

    test('rounds half away from zero in the invoice currency', () {
      final InvoiceLineItem before = line();
      final InvoiceLineItem after = before.copyWith(
        quantity: () => d('1.5'),
        unitPrice: () => d('3.33'),
      );
      expect(recalcLineTotal(before, after, Currency.usd).lineTotal, usdm(500));
      final InvoiceLineItem yen = before.copyWith(
        quantity: () => d('2'),
        unitPrice: () => d('150.5'),
      );
      expect(
        recalcLineTotal(before, yen, Currency.jpy).lineTotal,
        Money.tryFromMinorUnits(301, Currency.jpy),
      );
    });

    test('an amount too large for the currency is left unset', () {
      final InvoiceLineItem before = line();
      final InvoiceLineItem after = before.copyWith(
        quantity: () => d('999999999999999'),
        unitPrice: () => d('999999999999999'),
      );
      expect(recalcLineTotal(before, after, Currency.usd).lineTotal, isNull);
    });
  });

  group('editLine', () {
    test('edits only the matching line and recalculates it', () {
      final Invoice invoice = Invoice(
        currency: Currency.usd,
        lineItems: <InvoiceLineItem>[
          InvoiceLineItem(
            id: 'a',
            quantity: DecimalValue.fromInt(2),
            unitPrice: DecimalValue.tryParse('5'),
            lineTotal: Money.tryFromMinorUnits(1000, Currency.usd),
          ),
          const InvoiceLineItem(id: 'b'),
        ],
      );
      final Invoice next = editLine(
        invoice,
        'a',
        (InvoiceLineItem l) =>
            l.copyWith(quantity: () => DecimalValue.fromInt(4)),
      );
      expect(
        next.lineItems[0].lineTotal,
        Money.tryFromMinorUnits(2000, Currency.usd),
      );
      expect(next.lineItems[1], const InvoiceLineItem(id: 'b'));
      expect(editLine(invoice, 'zzz', (InvoiceLineItem l) => l), invoice);
    });
  });
}
