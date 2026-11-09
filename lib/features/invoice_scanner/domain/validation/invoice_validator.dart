import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/iso_date.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

/// Thresholds for [validateInvoice]. All amounts are minor units.
final class ValidationConfig {
  const ValidationConfig({
    this.maxFutureDays = 1,
    this.oldDateYears = 5,
    this.lineBaseToleranceMinorUnits = 1,
    this.sumBaseToleranceMinorUnits = 1,
    this.totalToleranceMinorUnits = 1,
  });

  /// Days ahead of today before a date is flagged (covers timezones).
  final int maxFutureDays;

  /// Dates older than this many years get an info note.
  final int oldDateYears;

  /// Line check allows this plus half a minor unit per unit of quantity.
  final int lineBaseToleranceMinorUnits;

  /// Line-sum check allows this plus half the line count.
  final int sumBaseToleranceMinorUnits;

  /// Subtotal + tax vs total.
  final int totalToleranceMinorUnits;
}

/// Pure validation. Never throws and never blocks saving: the user reviews
/// the result. [today] is injected so the function has no clock.
///
/// Warnings come first, then infos, each in detection order.
List<ValidationWarning> validateInvoice(
  Invoice invoice, {
  required DateTime today,
  ValidationConfig config = const ValidationConfig(),
}) {
  return _Run(invoice, today, config).run();
}

final class _Run {
  _Run(this.invoice, this.today, this.config);

  final Invoice invoice;
  final DateTime today;
  final ValidationConfig config;

  final List<ValidationWarning> _warnings = <ValidationWarning>[];
  final List<ValidationWarning> _infos = <ValidationWarning>[];
  final List<Money?> _lineTotals = <Money?>[];
  Money? _subtotal;
  Money? _tax;
  Money? _total;

  static const FieldRef _vendorRef = FieldRef(InvoiceField.vendorName);
  static const FieldRef _dateRef = FieldRef(InvoiceField.invoiceDate);
  static const FieldRef _currencyRef = FieldRef(InvoiceField.currency);
  static const FieldRef _linesRef = FieldRef(InvoiceField.lineItems);
  static const FieldRef _subtotalRef = FieldRef(InvoiceField.subtotal);
  static const FieldRef _taxRef = FieldRef(InvoiceField.tax);
  static const FieldRef _totalRef = FieldRef(InvoiceField.total);

  static final DecimalValue _half = DecimalValue.tryParse('0.5')!;
  static final DecimalValue _minusOne = DecimalValue.fromInt(-1);
  static final BigInt _maxMoney = BigInt.from(Money.maxMinorUnits);

  List<ValidationWarning> run() {
    _header();
    _lines();
    _amounts();
    _lineSumCheck();
    _totalCheck();
    return List<ValidationWarning>.unmodifiable(<ValidationWarning>[
      ..._warnings,
      ..._infos,
    ]);
  }

  void _header() {
    if (invoice.currencyAssumed) {
      _add(
        ValidationCode.currencyAssumed,
        WarningSeverity.warning,
        _currencyRef,
      );
    }

    for (final FieldRef ref in invoice.unreadable) {
      final String? lineId = ref.lineId;
      // A flag for a line the user has since deleted is stale.
      if (lineId != null &&
          !invoice.lineItems.any((InvoiceLineItem i) => i.id == lineId)) {
        continue;
      }
      _add(ValidationCode.unreadableValue, WarningSeverity.warning, ref);
    }

    if (_isBlank(invoice.vendorName) && !_flagged(_vendorRef)) {
      _add(ValidationCode.missingVendor, WarningSeverity.warning, _vendorRef);
    }

    final DateTime? date = invoice.invoiceDate;
    if (date == null) {
      if (!_flagged(_dateRef)) {
        _add(ValidationCode.missingDate, WarningSeverity.warning, _dateRef);
      }
      return;
    }
    final DateTime todayDate = dateOnly(today.toUtc());
    final DateTime invoiceDay = dateOnly(date);
    final DateTime latest = todayDate.add(Duration(days: config.maxFutureDays));
    final DateTime earliest = DateTime.utc(
      todayDate.year - config.oldDateYears,
      todayDate.month,
      todayDate.day,
    );
    if (invoiceDay.isAfter(latest)) {
      _add(ValidationCode.futureDate, WarningSeverity.warning, _dateRef);
    } else if (invoiceDay.isBefore(earliest)) {
      _add(ValidationCode.oldDate, WarningSeverity.info, _dateRef);
    }
  }

  void _lines() {
    if (invoice.lineItems.isEmpty) {
      _add(ValidationCode.noLineItems, WarningSeverity.info, _linesRef);
      return;
    }
    for (final InvoiceLineItem item in invoice.lineItems) {
      final FieldRef descRef = FieldRef(
        InvoiceField.lineDescription,
        lineId: item.id,
      );
      final FieldRef totalRef = FieldRef(
        InvoiceField.lineTotal,
        lineId: item.id,
      );

      if (_isBlank(item.description) && !_flagged(descRef)) {
        _add(
          ValidationCode.missingLineDescription,
          WarningSeverity.info,
          descRef,
        );
      }

      final Money? total = _usable(item.lineTotal, totalRef);
      _lineTotals.add(total);
      if (item.lineTotal == null && !_flagged(totalRef)) {
        _add(
          ValidationCode.missingLineTotal,
          WarningSeverity.warning,
          totalRef,
        );
      }
      _lineMath(item, total, totalRef);
    }
  }

  void _lineMath(InvoiceLineItem item, Money? total, FieldRef totalRef) {
    final DecimalValue? quantity = item.quantity;
    final DecimalValue? unitPrice = item.unitPrice;
    if (quantity == null || unitPrice == null || total == null) return;

    final BigInt expected = (quantity * unitPrice).roundedMinorUnits(
      invoice.currency.minorUnitExponent,
    );
    final DecimalValue magnitude = quantity.isNegative
        ? quantity * _minusOne
        : quantity;
    final BigInt tolerance =
        BigInt.from(config.lineBaseToleranceMinorUnits) +
        (magnitude * _half).roundedMinorUnits(0);
    final BigInt diff = (BigInt.from(total.minorUnits) - expected).abs();
    if (diff > tolerance) {
      _add(
        ValidationCode.lineMathMismatch,
        WarningSeverity.warning,
        totalRef,
        expected: _money(expected),
        actual: total,
      );
    }
  }

  void _amounts() {
    _subtotal = _usable(invoice.subtotal, _subtotalRef);
    _tax = _usable(invoice.tax, _taxRef);
    _total = _usable(invoice.total, _totalRef);

    if (invoice.subtotal == null && !_flagged(_subtotalRef)) {
      _add(ValidationCode.missingSubtotal, WarningSeverity.info, _subtotalRef);
    }
    if (invoice.tax == null && !_flagged(_taxRef)) {
      _add(ValidationCode.missingTax, WarningSeverity.info, _taxRef);
    }
    if (invoice.total == null && !_flagged(_totalRef)) {
      _add(ValidationCode.missingTotal, WarningSeverity.warning, _totalRef);
    }

    for (final (FieldRef ref, Money? money) in <(FieldRef, Money?)>[
      (_subtotalRef, _subtotal),
      (_taxRef, _tax),
      (_totalRef, _total),
    ]) {
      if (money != null && money.isNegative) {
        _add(
          ValidationCode.negativeAmount,
          WarningSeverity.info,
          ref,
          actual: money,
        );
      }
    }

    final Money? total = _total;
    if (total != null && total.minorUnits == 0) {
      _add(
        ValidationCode.zeroTotal,
        WarningSeverity.warning,
        _totalRef,
        actual: total,
      );
    }
  }

  /// Sum of line totals vs the printed subtotal (or total when there is no
  /// subtotal). Skipped when any line total is missing or unusable.
  void _lineSumCheck() {
    if (_lineTotals.isEmpty) return;
    BigInt lineSum = BigInt.zero;
    for (final Money? m in _lineTotals) {
      if (m == null) return;
      lineSum += BigInt.from(m.minorUnits);
    }

    final Money? subtotal = _subtotal;
    final Money? tax = _tax;
    final Money? total = _total;

    final List<BigInt> refs;
    final FieldRef field;
    final Money printed;
    if (subtotal != null) {
      refs = <BigInt>[BigInt.from(subtotal.minorUnits)];
      field = _subtotalRef;
      printed = subtotal;
    } else if (total != null) {
      final BigInt t = BigInt.from(total.minorUnits);
      // Tax-inclusive receipts: lines may add up to the total itself.
      refs = <BigInt>[t, if (tax != null) t - BigInt.from(tax.minorUnits)];
      field = _totalRef;
      printed = total;
    } else {
      return;
    }

    final BigInt tolerance = BigInt.from(
      config.sumBaseToleranceMinorUnits + _lineTotals.length ~/ 2,
    );
    if (refs.any((BigInt r) => (r - lineSum).abs() <= tolerance)) return;

    final Money? expected = _money(lineSum);
    _add(
      ValidationCode.lineSumMismatch,
      WarningSeverity.warning,
      field,
      expected: expected,
      actual: printed,
      hint: refs.first > lineSum
          ? MismatchHint.possibleExtraCharge
          : MismatchHint.possibleDiscount,
      fixes: <SuggestedFix>[
        // Only offered for a printed subtotal; never overwrite a total.
        if (subtotal != null && expected != null)
          SetMoneyFix(_subtotalRef, expected),
      ],
    );
  }

  /// Subtotal + tax vs total. Skipped unless all three are present and usable.
  void _totalCheck() {
    final Money? subtotal = _subtotal;
    final Money? tax = _tax;
    final Money? total = _total;
    if (subtotal == null || tax == null || total == null) return;

    final BigInt s = BigInt.from(subtotal.minorUnits);
    final BigInt x = BigInt.from(tax.minorUnits);
    final BigInt t = BigInt.from(total.minorUnits);
    final BigInt tolerance = BigInt.from(config.totalToleranceMinorUnits);
    final BigInt computed = s + x;
    final BigInt diff = t - computed;

    if (diff.abs() <= tolerance) return;
    // Tax-inclusive pricing: the subtotal already includes the tax.
    if ((t - s).abs() <= tolerance) return;

    final Money? computedMoney = _money(computed);
    final Money? impliedSubtotal = _money(t - x);
    _add(
      ValidationCode.totalMismatch,
      WarningSeverity.warning,
      _totalRef,
      expected: computedMoney,
      actual: total,
      hint: diff.isNegative
          ? MismatchHint.possibleDiscount
          : MismatchHint.possibleExtraCharge,
      fixes: <SuggestedFix>[
        if (computedMoney != null) SetMoneyFix(_totalRef, computedMoney),
        if (impliedSubtotal != null) SetMoneyFix(_subtotalRef, impliedSubtotal),
      ],
    );
  }

  /// Returns [money] unless it is in another currency, in which case it is
  /// flagged and excluded from arithmetic.
  Money? _usable(Money? money, FieldRef field) {
    if (money == null) return null;
    if (money.currency != invoice.currency) {
      _add(
        ValidationCode.currencyInconsistent,
        WarningSeverity.warning,
        field,
        actual: money,
      );
      return null;
    }
    return money;
  }

  /// Null when out of [Money] range, so a fix is never offered for it.
  Money? _money(BigInt minorUnits) {
    if (minorUnits.abs() > _maxMoney) return null;
    return Money.tryFromMinorUnits(minorUnits.toInt(), invoice.currency);
  }

  bool _flagged(FieldRef ref) => invoice.unreadable.contains(ref);

  bool _isBlank(String? text) => text == null || text.trim().isEmpty;

  void _add(
    ValidationCode code,
    WarningSeverity severity,
    FieldRef field, {
    Money? expected,
    Money? actual,
    MismatchHint? hint,
    List<SuggestedFix> fixes = const <SuggestedFix>[],
  }) {
    final ValidationWarning warning = ValidationWarning(
      code: code,
      severity: severity,
      field: field,
      expected: expected,
      actual: actual,
      hint: hint,
      fixes: fixes,
    );
    (severity == WarningSeverity.warning ? _warnings : _infos).add(warning);
  }
}
