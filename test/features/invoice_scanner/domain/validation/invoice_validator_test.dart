import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/invoice_validator.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

final DateTime today = DateTime.utc(2026, 11, 8);

Money usd(int minor) => Money.tryFromMinorUnits(minor, Currency.usd)!;
DecimalValue d(String s) => DecimalValue.tryParse(s)!;

InvoiceLineItem line(
  String id, {
  String? description = 'Item',
  String? qty,
  String? unit,
  int? total,
}) {
  return InvoiceLineItem(
    id: id,
    description: description,
    quantity: qty == null ? null : d(qty),
    unitPrice: unit == null ? null : d(unit),
    lineTotal: total == null ? null : usd(total),
  );
}

/// Internally consistent: lines 1000 + 2000 = subtotal 3000, +300 tax = 3300.
Invoice clean() => Invoice(
  currency: Currency.usd,
  vendorName: 'Acme',
  invoiceDate: DateTime.utc(2026, 11, 1),
  lineItems: <InvoiceLineItem>[
    line('a', description: 'Widget', qty: '2', unit: '5.00', total: 1000),
    line('b', description: 'Gadget', qty: '1', unit: '20.00', total: 2000),
  ],
  subtotal: usd(3000),
  tax: usd(300),
  total: usd(3300),
);

List<ValidationWarning> run(
  Invoice invoice, {
  ValidationConfig config = const ValidationConfig(),
}) => validateInvoice(invoice, today: today, config: config);

List<ValidationCode> codes(List<ValidationWarning> w) =>
    w.map((ValidationWarning x) => x.code).toList();

List<ValidationWarning> only(List<ValidationWarning> w, ValidationCode c) =>
    w.where((ValidationWarning x) => x.code == c).toList();

void main() {
  group('clean and empty', () {
    test('a consistent invoice has no warnings', () {
      expect(run(clean()), isEmpty);
    });

    test('an empty invoice flags what is missing, warnings before infos', () {
      final List<ValidationWarning> r = run(
        const Invoice(currency: Currency.usd),
      );
      expect(codes(r), <ValidationCode>[
        ValidationCode.missingVendor,
        ValidationCode.missingDate,
        ValidationCode.missingTotal,
        ValidationCode.noLineItems,
        ValidationCode.missingSubtotal,
        ValidationCode.missingTax,
      ]);
      expect(
        r
            .take(3)
            .every(
              (ValidationWarning w) => w.severity == WarningSeverity.warning,
            ),
        isTrue,
      );
      expect(
        r
            .skip(3)
            .every((ValidationWarning w) => w.severity == WarningSeverity.info),
        isTrue,
      );
      expect(() => r.add(r.first), throwsUnsupportedError);
    });

    test('blank text counts as missing', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(
          vendorName: () => '   ',
          lineItems: <InvoiceLineItem>[
            line('a', description: '', qty: '2', unit: '5.00', total: 1000),
            line(
              'b',
              description: 'Gadget',
              qty: '1',
              unit: '20.00',
              total: 2000,
            ),
          ],
        ),
      );
      expect(only(r, ValidationCode.missingVendor), hasLength(1));
      final List<ValidationWarning> desc = only(
        r,
        ValidationCode.missingLineDescription,
      );
      expect(desc, hasLength(1));
      expect(desc.single.severity, WarningSeverity.info);
      expect(
        desc.single.field,
        const FieldRef(InvoiceField.lineDescription, lineId: 'a'),
      );
    });

    test('currencyAssumed is a warning on the currency field', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(currencyAssumed: true),
      );
      expect(codes(r), <ValidationCode>[ValidationCode.currencyAssumed]);
      expect(r.single.field, const FieldRef(InvoiceField.currency));
    });
  });

  group('unreadable', () {
    test('replaces the missing warning instead of duplicating it', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(
          total: () => null,
          unreadable: <FieldRef>{const FieldRef(InvoiceField.total)},
        ),
      );
      expect(
        r.map((ValidationWarning w) => (w.code, w.field)).toList(),
        <(ValidationCode, FieldRef)>[
          (ValidationCode.unreadableValue, const FieldRef(InvoiceField.total)),
        ],
      );
    });

    test('a flag for a deleted line is ignored', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(
          unreadable: <FieldRef>{
            const FieldRef(InvoiceField.lineTotal, lineId: 'zzz'),
          },
        ),
      );
      expect(r, isEmpty);
    });
  });

  group('dates', () {
    test('future dates are flagged beyond the allowed window', () {
      expect(
        run(clean().copyWith(invoiceDate: () => DateTime.utc(2026, 11, 9))),
        isEmpty,
      );
      final List<ValidationWarning> r = run(
        clean().copyWith(invoiceDate: () => DateTime.utc(2026, 11, 10)),
      );
      expect(codes(r), <ValidationCode>[ValidationCode.futureDate]);
      expect(r.single.severity, WarningSeverity.warning);
    });

    test('old dates are an info note', () {
      expect(
        run(clean().copyWith(invoiceDate: () => DateTime.utc(2021, 11, 8))),
        isEmpty,
      );
      final List<ValidationWarning> r = run(
        clean().copyWith(invoiceDate: () => DateTime.utc(2021, 11, 7)),
      );
      expect(codes(r), <ValidationCode>[ValidationCode.oldDate]);
      expect(r.single.severity, WarningSeverity.info);
    });
  });

  group('line math', () {
    Invoice single(InvoiceLineItem item) =>
        Invoice(currency: Currency.usd, lineItems: <InvoiceLineItem>[item]);

    test('flags a line that does not equal qty x unit price', () {
      final List<ValidationWarning> r = only(
        run(single(line('a', qty: '3', unit: '19.99', total: 5900))),
        ValidationCode.lineMathMismatch,
      );
      expect(r, hasLength(1));
      expect(r.single.expected, usd(5997));
      expect(r.single.actual, usd(5900));
      expect(
        r.single.field,
        const FieldRef(InvoiceField.lineTotal, lineId: 'a'),
      );
    });

    test('tolerance boundary: qty 3 allows 3 minor units', () {
      for (final int total in <int>[5997, 5996, 5994]) {
        expect(
          only(
            run(single(line('a', qty: '3', unit: '19.99', total: total))),
            ValidationCode.lineMathMismatch,
          ),
          isEmpty,
          reason: '$total',
        );
      }
      expect(
        only(
          run(single(line('a', qty: '3', unit: '19.99', total: 5993))),
          ValidationCode.lineMathMismatch,
        ),
        hasLength(1),
      );
    });

    test('fractional quantities round half away from zero', () {
      for (final int total in <int>[500, 499, 498]) {
        expect(
          only(
            run(single(line('a', qty: '1.5', unit: '3.33', total: total))),
            ValidationCode.lineMathMismatch,
          ),
          isEmpty,
          reason: '$total',
        );
      }
      expect(
        only(
          run(single(line('a', qty: '1.5', unit: '3.33', total: 497))),
          ValidationCode.lineMathMismatch,
        ),
        hasLength(1),
      );
    });

    test('skipped when quantity, unit price or total is missing', () {
      for (final InvoiceLineItem item in <InvoiceLineItem>[
        line('a', unit: '5.00', total: 999),
        line('a', qty: '2', total: 999),
        line('a', qty: '2', unit: '5.00'),
      ]) {
        expect(
          only(run(single(item)), ValidationCode.lineMathMismatch),
          isEmpty,
        );
      }
    });

    test('zero-decimal currency uses its own exponent', () {
      Invoice yen(int total) => Invoice(
        currency: Currency.jpy,
        lineItems: <InvoiceLineItem>[
          InvoiceLineItem(
            id: 'a',
            quantity: d('2'),
            unitPrice: d('150.5'),
            lineTotal: Money.tryFromMinorUnits(total, Currency.jpy),
          ),
        ],
      );
      expect(only(run(yen(301)), ValidationCode.lineMathMismatch), isEmpty);
      final List<ValidationWarning> r = only(
        run(yen(400)),
        ValidationCode.lineMathMismatch,
      );
      expect(r, hasLength(1));
      expect(r.single.expected, Money.tryFromMinorUnits(301, Currency.jpy));
    });

    test('a missing line total is a warning and skips the sum check', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(
          lineItems: <InvoiceLineItem>[
            line('a', qty: '2', unit: '5.00', total: 1000),
            line('b', qty: '1', unit: '20.00'),
          ],
        ),
      );
      expect(codes(r), <ValidationCode>[ValidationCode.missingLineTotal]);
      expect(
        r.single.field,
        const FieldRef(InvoiceField.lineTotal, lineId: 'b'),
      );
    });
  });

  group('lines vs subtotal', () {
    test('a smaller subtotal hints at a discount and offers a fix', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(subtotal: () => usd(2700), total: () => usd(3000)),
      );
      expect(codes(r), <ValidationCode>[ValidationCode.lineSumMismatch]);
      final ValidationWarning w = r.single;
      expect(w.field, const FieldRef(InvoiceField.subtotal));
      expect(w.expected, usd(3000));
      expect(w.actual, usd(2700));
      expect(w.hint, MismatchHint.possibleDiscount);
      expect(w.fixes, <SuggestedFix>[
        SetMoneyFix(const FieldRef(InvoiceField.subtotal), usd(3000)),
      ]);
    });

    test('a larger subtotal hints at an extra charge', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(subtotal: () => usd(3200), total: () => usd(3500)),
      );
      expect(codes(r), <ValidationCode>[ValidationCode.lineSumMismatch]);
      expect(r.single.hint, MismatchHint.possibleExtraCharge);
    });

    test('rounding differences within tolerance are not flagged', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(subtotal: () => usd(3001), total: () => usd(3301)),
      );
      expect(r, isEmpty);
    });

    test('without a subtotal the lines are compared to the total', () {
      Invoice noSubtotal({int? tax, required int total}) => clean().copyWith(
        subtotal: () => null,
        tax: () => tax == null ? null : usd(tax),
        total: () => usd(total),
      );

      expect(
        only(run(noSubtotal(total: 3000)), ValidationCode.lineSumMismatch),
        isEmpty,
      );

      final List<ValidationWarning> r = only(
        run(noSubtotal(total: 3300)),
        ValidationCode.lineSumMismatch,
      );
      expect(r, hasLength(1));
      expect(r.single.field, const FieldRef(InvoiceField.total));
      expect(r.single.hint, MismatchHint.possibleExtraCharge);
      expect(r.single.fixes, isEmpty);

      expect(
        only(
          run(noSubtotal(tax: 300, total: 3300)),
          ValidationCode.lineSumMismatch,
        ),
        isEmpty,
      );
    });
  });

  group('subtotal + tax vs total', () {
    test('flags a mismatch with a hint and two fixes', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(total: () => usd(3400)),
      );
      expect(codes(r), <ValidationCode>[ValidationCode.totalMismatch]);
      final ValidationWarning w = r.single;
      expect(w.field, const FieldRef(InvoiceField.total));
      expect(w.expected, usd(3300));
      expect(w.actual, usd(3400));
      expect(w.hint, MismatchHint.possibleExtraCharge);
      expect(w.fixes, <SuggestedFix>[
        SetMoneyFix(const FieldRef(InvoiceField.total), usd(3300)),
        SetMoneyFix(const FieldRef(InvoiceField.subtotal), usd(3100)),
      ]);
    });

    test('a smaller total hints at a discount', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(total: () => usd(3250)),
      );
      expect(r.single.hint, MismatchHint.possibleDiscount);
    });

    test('tax-inclusive pricing is accepted', () {
      expect(run(clean().copyWith(total: () => usd(3000))), isEmpty);
    });

    test('is skipped when the tax is missing', () {
      final List<ValidationWarning> r = run(
        clean().copyWith(tax: () => null, total: () => usd(3400)),
      );
      expect(only(r, ValidationCode.totalMismatch), isEmpty);
      expect(only(r, ValidationCode.missingTax), hasLength(1));
    });

    test('tolerance is configurable', () {
      final Invoice off = clean().copyWith(total: () => usd(3301));
      expect(run(off), isEmpty);
      final List<ValidationWarning> strict = run(
        off,
        config: const ValidationConfig(totalToleranceMinorUnits: 0),
      );
      expect(codes(strict), <ValidationCode>[ValidationCode.totalMismatch]);
    });
  });

  group('amount sanity', () {
    test('a zero total is a warning', () {
      final List<ValidationWarning> r = run(
        Invoice(
          currency: Currency.usd,
          vendorName: 'Acme',
          invoiceDate: DateTime.utc(2026, 11, 1),
          total: usd(0),
        ),
      );
      expect(codes(r), contains(ValidationCode.zeroTotal));
    });

    test('a negative total is an info note, not a zero-total warning', () {
      final List<ValidationWarning> r = run(
        Invoice(
          currency: Currency.usd,
          vendorName: 'Acme',
          invoiceDate: DateTime.utc(2026, 11, 1),
          total: usd(-500),
        ),
      );
      final List<ValidationWarning> neg = only(
        r,
        ValidationCode.negativeAmount,
      );
      expect(neg, hasLength(1));
      expect(neg.single.severity, WarningSeverity.info);
      expect(codes(r), isNot(contains(ValidationCode.zeroTotal)));
    });
  });

  group('robustness', () {
    test('an amount in another currency is flagged and not compared', () {
      final Invoice mixed = clean().copyWith(
        subtotal: () => Money.tryFromMinorUnits(3000, Currency.eur),
        total: () => usd(3000),
      );
      final List<ValidationWarning> r = run(mixed);
      final List<ValidationWarning> flagged = only(
        r,
        ValidationCode.currencyInconsistent,
      );
      expect(flagged, hasLength(1));
      expect(flagged.single.field, const FieldRef(InvoiceField.subtotal));
      expect(codes(r), isNot(contains(ValidationCode.totalMismatch)));
      expect(codes(r), isNot(contains(ValidationCode.lineSumMismatch)));
    });

    test('extreme values do not throw and offer no out-of-range fix', () {
      final Money max = Money.tryFromMinorUnits(
        Money.maxMinorUnits,
        Currency.usd,
      )!;
      final Invoice huge = Invoice(
        currency: Currency.usd,
        lineItems: <InvoiceLineItem>[
          InvoiceLineItem(id: 'a', lineTotal: max),
          InvoiceLineItem(id: 'b', lineTotal: max),
        ],
        subtotal: usd(1),
      );
      final List<ValidationWarning> r = only(
        run(huge),
        ValidationCode.lineSumMismatch,
      );
      expect(r, hasLength(1));
      expect(r.single.expected, isNull);
      expect(r.single.fixes, isEmpty);
    });

    test('warnings are value-equal', () {
      expect(
        run(clean().copyWith(total: () => usd(3400))),
        run(clean().copyWith(total: () => usd(3400))),
      );
    });
  });
}
