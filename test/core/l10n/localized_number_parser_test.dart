import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/l10n/localized_number_parser.dart';

String? ok(DecimalParseResult r) => switch (r) {
      DecimalParsed(:final canonical) => canonical,
      DecimalParseFailed() => null,
    };

DecimalParseFailure? bad(DecimalParseResult r) => switch (r) {
      DecimalParsed() => null,
      DecimalParseFailed(:final reason) => reason,
    };

void main() {
  final LocalizedNumberParser en = LocalizedNumberParser.forLocale('en');
  final LocalizedNumberParser de = LocalizedNumberParser.forLocale('de');
  final LocalizedNumberParser enIn = LocalizedNumberParser.forLocale('en_IN');
  final LocalizedNumberParser hi = LocalizedNumberParser.forLocale('hi');
  final LocalizedNumberParser fr = LocalizedNumberParser.withSeparators(
    decimal: ',',
    group: '\u202F',
  );
  final LocalizedNumberParser deCh = LocalizedNumberParser.withSeparators(
    decimal: '.',
    group: '\u2019',
  );

  group('en accepts', () {
    const Map<String, String> cases = <String, String>{
      '1,234.56': '1234.56',
      '1234.56': '1234.56',
      '0.5': '0.5',
      '.5': '0.5',
      '12.': '12',
      '1 234.5': '1234.5',
      '(12.30)': '-12.30',
      '-0.00': '0.00',
      '\u22125': '-5',
      '+7': '7',
      '000': '0',
      '\u0661\u0662\u0663': '123',
      '\uFF11\uFF12\uFF13': '123',
      '\u200E-3.5': '-3.5',
    };
    cases.forEach((String input, String expected) {
      test('"$input" -> $expected', () {
        expect(ok(en.parse(input)), expected);
      });
    });
  });

  group('en rejects', () {
    const Map<String, DecimalParseFailure> cases =
        <String, DecimalParseFailure>{
      '': DecimalParseFailure.empty,
      '-': DecimalParseFailure.noDigits,
      '.': DecimalParseFailure.noDigits,
      'abc': DecimalParseFailure.invalidCharacter,
      '\$5': DecimalParseFailure.invalidCharacter,
      '-(5)': DecimalParseFailure.invalidCharacter,
      '1.2.3': DecimalParseFailure.multipleDecimalSeparators,
      '1,23': DecimalParseFailure.invalidGrouping,
      '1,2345': DecimalParseFailure.invalidGrouping,
      ',234': DecimalParseFailure.invalidGrouping,
      '1,,234': DecimalParseFailure.invalidGrouping,
      '12,34,567.89': DecimalParseFailure.invalidGrouping,
      '1234567890123456': DecimalParseFailure.tooLarge,
      '0.1234567': DecimalParseFailure.tooManyDecimals,
    };
    cases.forEach((String input, DecimalParseFailure reason) {
      test('"$input" -> ${reason.name}', () {
        expect(bad(en.parse(input)), reason);
      });
    });
  });

  group('de', () {
    test('accepts grouped and decimal input', () {
      expect(ok(de.parse('1.234,56')), '1234.56');
      expect(ok(de.parse('12,50')), '12.50');
      expect(ok(de.parse('1,234')), '1.234');
      expect(ok(de.parse('1234,5')), '1234.5');
    });
    test('rejects ambiguous input instead of guessing', () {
      expect(bad(de.parse('12.50')), DecimalParseFailure.invalidGrouping);
      expect(bad(de.parse('1.2.3')), DecimalParseFailure.invalidGrouping);
    });
  });

  group('other separators', () {
    test('fr accepts normal and narrow no-break spaces', () {
      expect(ok(fr.parse('1 234,56')), '1234.56');
      expect(ok(fr.parse('1\u202F234,56')), '1234.56');
    });
    test('de_CH style apostrophe grouping', () {
      expect(ok(deCh.parse('1\u2019234.50')), '1234.50');
    });
    test('en_IN and hi accept Indian grouping, en does not', () {
      expect(ok(enIn.parse('12,34,567.89')), '1234567.89');
      expect(ok(enIn.parse('1,234,567')), '1234567');
      expect(ok(enIn.parse('1,23,456')), '123456');
      expect(ok(hi.parse('12,34,567')), '1234567');
    });
    test('locale zero digit is honored', () {
      final LocalizedNumberParser devanagari = LocalizedNumberParser.withSeparators(
        decimal: '.',
        group: ',',
        zeroDigit: '\u0966',
      );
      expect(ok(devanagari.parse('\u0967\u0968\u0969')), '123');
      expect(bad(en.parse('\u0967\u0968\u0969')),
          DecimalParseFailure.invalidCharacter);
    });
  });

  // [M2-ADJUST-2] Currency stripping helper.
  group('stripCurrencyPrefix', () {
    test('removes ISO codes and common symbols', () {
      expect(LocalizedNumberParser.stripCurrencyPrefix('EUR 12.50'), '12.50');
      expect(LocalizedNumberParser.stripCurrencyPrefix('\$1,234.56'), '1,234.56');
      expect(LocalizedNumberParser.stripCurrencyPrefix('€ 99,00'), '99,00');
      expect(LocalizedNumberParser.stripCurrencyPrefix('  £5'), '5');
      expect(LocalizedNumberParser.stripCurrencyPrefix('12.50'), '12.50');
    });
  });
}
