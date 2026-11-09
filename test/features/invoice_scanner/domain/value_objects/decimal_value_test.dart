import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';

DecimalValue d(String s) => DecimalValue.tryParse(s)!;

void main() {
  group('tryParse', () {
    test('accepts canonical input', () {
      expect(d('12.50').toString(), '12.5');
      expect(d('007.50').toString(), '7.5');
      expect(d('0.05').toString(), '0.05');
      expect(d('-0.05').toString(), '-0.05');
      expect(d('-0').toString(), '0');
      expect(d(' 12.5 ').toString(), '12.5');
    });

    test('rejects malformed or out-of-range input', () {
      for (final String? bad in <String?>[
        null,
        '',
        '5.',
        '.5',
        '+5',
        '--1',
        '1e5',
        '1,5',
        'abc',
        '1234567890123456',
        '0.1234567',
      ]) {
        expect(DecimalValue.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('accepts the documented limits', () {
      expect(DecimalValue.tryParse('999999999999999'), isNotNull);
      expect(DecimalValue.tryParse('0.123456'), isNotNull);
    });
  });

  test('is equal by value regardless of trailing zeros', () {
    expect(d('2.50'), d('2.5'));
    expect(d('2.50').hashCode, d('2.5').hashCode);
    expect(d('0.000'), DecimalValue.zero);
    expect(d('0.000').isZero, isTrue);
  });

  test('compareTo aligns scales', () {
    expect(d('2.5').compareTo(d('2.50')), 0);
    expect(d('2.5').compareTo(d('2.51')), lessThan(0));
    expect(d('10').compareTo(d('9.999')), greaterThan(0));
    expect(d('-1').compareTo(d('1')), lessThan(0));
  });

  test('multiplication is exact', () {
    expect((d('3') * d('19.99')).toString(), '59.97');
    expect((d('1.5') * d('10.00')).toString(), '15');
    expect((d('0.001') * d('0.001')).toString(), '0.000001');
  });

  group('minor units', () {
    test('rounded: half away from zero', () {
      expect(d('2.345').roundedMinorUnits(2), BigInt.from(235));
      expect(d('-2.345').roundedMinorUnits(2), BigInt.from(-235));
      expect(d('2.344').roundedMinorUnits(2), BigInt.from(234));
      expect(d('0.005').roundedMinorUnits(2), BigInt.from(1));
      expect(d('0.004').roundedMinorUnits(2), BigInt.zero);
      expect(d('12.5').roundedMinorUnits(0), BigInt.from(13));
    });

    test('exact: rejects extra precision, pads missing precision', () {
      expect(d('12.50').exactMinorUnits(2), BigInt.from(1250));
      expect(d('12').exactMinorUnits(2), BigInt.from(1200));
      expect(d('1.234').exactMinorUnits(3), BigInt.from(1234));
      expect(d('12.345').exactMinorUnits(2), isNull);
      expect(d('12.5').exactMinorUnits(0), isNull);
    });
  });
}
