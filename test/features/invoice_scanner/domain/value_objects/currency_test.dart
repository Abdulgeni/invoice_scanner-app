import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

void main() {
  test('uses the correct minor-unit exponent', () {
    const Map<String, int> expected = <String, int>{
      'USD': 2,
      'EUR': 2,
      'GBP': 2,
      'ETB': 2,
      'JPY': 0,
      'KRW': 0,
      'VND': 0,
      'KWD': 3,
      'BHD': 3,
      'OMR': 3,
      'JOD': 3,
      'TND': 3,
      'CLF': 4,
    };
    expected.forEach((String code, int exponent) {
      expect(
        Currency.tryParse(code)?.minorUnitExponent,
        exponent,
        reason: code,
      );
    });
  });

  test('normalizes case and whitespace', () {
    expect(Currency.tryParse(' usd '), Currency.usd);
    expect(Currency.tryParse('jpy'), Currency.jpy);
  });

  test('rejects malformed codes', () {
    for (final String? bad in <String?>[
      null,
      '',
      'US',
      'USDD',
      'U5D',
      '123',
      'XXX',
    ]) {
      expect(Currency.tryParse(bad), isNull, reason: '$bad');
    }
  });

  test('minorUnitFactor', () {
    expect(Currency.jpy.minorUnitFactor, 1);
    expect(Currency.usd.minorUnitFactor, 100);
    expect(Currency.kwd.minorUnitFactor, 1000);
  });
}
