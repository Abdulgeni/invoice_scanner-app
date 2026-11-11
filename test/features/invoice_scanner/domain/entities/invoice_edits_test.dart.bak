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
}
