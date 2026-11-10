import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/error_messages.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

Money money(int minor, Currency c) => Money.tryFromMinorUnits(minor, c)!;

void main() {
  group('MoneyFormatter', () {
    const MoneyFormatter en = MoneyFormatter('en');

    test('uses the currency exponent', () {
      expect(en.format(money(1250, Currency.usd)), contains('12.50'));
      expect(en.format(money(1200, Currency.jpy)), contains('1,200'));
      expect(en.format(money(1200, Currency.jpy)), isNot(contains('.')));
      expect(en.format(money(1234, Currency.kwd)), contains('1.234'));
    });

    test('groups digits and keeps the sign', () {
      final String text = en.format(money(-123456789, Currency.usd));
      expect(text, contains('1,234,567.89'));
      expect(text, contains('-'));
    });

    test('follows the locale separators', () {
      expect(
        const MoneyFormatter('de').format(money(1234567, Currency.eur)),
        contains('12.345,67'),
      );
    });

    test('formats the largest representable amount without losing digits', () {
      final String text = en.format(money(Money.maxMinorUnits, Currency.usd));
      expect(text, contains('9,999,999,999,999.99'));
    });

    test('formats zero', () {
      expect(en.format(money(0, Currency.usd)), contains('0.00'));
    });
  });

  group('error messages', () {
    late AppLocalizations l10n;
    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('every extraction error kind has text', () {
      for (final InvoiceErrorKind kind in InvoiceErrorKind.values) {
        expect(
          extractionErrorMessage(l10n, kind).trim(),
          isNotEmpty,
          reason: kind.name,
        );
      }
    });

    test('every capture failure reason has text', () {
      for (final CaptureFailureReason reason in CaptureFailureReason.values) {
        expect(
          captureErrorMessage(l10n, reason).trim(),
          isNotEmpty,
          reason: reason.name,
        );
      }
    });

    test('the page-limit message carries the limit', () {
      expect(
        captureErrorMessage(
          l10n,
          CaptureFailureReason.tooManyPages,
          maxPages: 5,
        ),
        contains('5'),
      );
      expect(
        captureErrorMessage(l10n, CaptureFailureReason.tooManyPages),
        contains('5'),
      );
    });

    test('messages never leak backend internals', () {
      const List<String> forbidden = <String>[
        'firebase',
        'gemini',
        'google',
        'vertex',
        'quota',
        'app check',
        '429',
      ];
      final List<String> all = <String>[
        for (final InvoiceErrorKind k in InvoiceErrorKind.values)
          extractionErrorMessage(l10n, k),
        for (final CaptureFailureReason r in CaptureFailureReason.values)
          captureErrorMessage(l10n, r),
      ];
      for (final String message in all) {
        for (final String term in forbidden) {
          expect(message.toLowerCase(), isNot(contains(term)), reason: message);
        }
      }
    });
  });
}
