import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/warning_messages.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

Money usd(int m) => Money.tryFromMinorUnits(m, Currency.usd)!;

void main() {
  late AppLocalizations l10n;
  const MoneyFormatter money = MoneyFormatter('en');

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  ValidationWarning warning(
    ValidationCode code, {
    FieldRef field = const FieldRef(InvoiceField.total),
    Money? expected,
    Money? actual,
    MismatchHint? hint,
  }) {
    return ValidationWarning(
      code: code,
      severity: WarningSeverity.warning,
      field: field,
      expected: expected,
      actual: actual,
      hint: hint,
    );
  }

  test('every validation code has non-empty text', () {
    for (final ValidationCode code in ValidationCode.values) {
      final String message = warningMessage(
        l10n,
        warning(code, expected: usd(100), actual: usd(200)),
        money,
        currencyCode: 'USD',
      );
      expect(message.trim(), isNotEmpty, reason: code.name);
    }
  });

  test('mismatch messages carry both amounts and the hint', () {
    final String message = warningMessage(
      l10n,
      warning(
        ValidationCode.totalMismatch,
        expected: usd(3300),
        actual: usd(3400),
        hint: MismatchHint.possibleExtraCharge,
      ),
      money,
      currencyCode: 'USD',
    );
    expect(
      message,
      allOf(contains('33.00'), contains('34.00'), contains('Shipping or fees')),
    );

    final String line = warningMessage(
      l10n,
      warning(
        ValidationCode.lineMathMismatch,
        expected: usd(1500),
        actual: usd(1000),
      ),
      money,
      currencyCode: 'USD',
    );
    expect(line, allOf(contains('15.00'), contains('10.00')));
  });

  test('a mismatch with no hint has no dangling space', () {
    final String message = warningMessage(
      l10n,
      warning(
        ValidationCode.lineSumMismatch,
        expected: usd(100),
        actual: usd(200),
      ),
      money,
      currencyCode: 'USD',
    );
    expect(message, isNot(endsWith(' ')));
  });

  test('the assumed-currency message names the currency', () {
    expect(
      warningMessage(
        l10n,
        warning(
          ValidationCode.currencyAssumed,
          field: const FieldRef(InvoiceField.currency),
        ),
        money,
        currencyCode: 'KWD',
      ),
      contains('KWD'),
    );
  });

  test('unreadable lines have their own wording', () {
    final String lines = warningMessage(
      l10n,
      warning(
        ValidationCode.unreadableValue,
        field: const FieldRef(InvoiceField.lineItems),
      ),
      money,
      currencyCode: 'USD',
    );
    final String field = warningMessage(
      l10n,
      warning(ValidationCode.unreadableValue),
      money,
      currencyCode: 'USD',
    );
    expect(lines, isNot(field));
  });

  test('fix labels name the field and the value', () {
    for (final (InvoiceField field, String word) in <(InvoiceField, String)>[
      (InvoiceField.subtotal, 'subtotal'),
      (InvoiceField.tax, 'tax'),
      (InvoiceField.total, 'total'),
    ]) {
      final String label = fixLabel(
        l10n,
        SetMoneyFix(FieldRef(field), usd(3300)),
        money,
      );
      expect(label.toLowerCase(), allOf(contains(word), contains('33.00')));
    }
  });

  test('no message leaks backend internals', () {
    for (final ValidationCode code in ValidationCode.values) {
      final String message = warningMessage(
        l10n,
        warning(code, expected: usd(1), actual: usd(2)),
        money,
        currencyCode: 'USD',
      ).toLowerCase();
      for (final String term in <String>[
        'gemini',
        'firebase',
        'model',
        'api',
      ]) {
        expect(message, isNot(contains(term)), reason: code.name);
      }
    }
  });
}
