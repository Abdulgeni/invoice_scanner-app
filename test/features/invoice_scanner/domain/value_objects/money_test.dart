import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/iso_date.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

DecimalValue d(String s) => DecimalValue.tryParse(s)!;

void main() {
  group('Money bounds', () {
    test('accepts the maximum, rejects one past it', () {
      expect(
        Money.tryFromMinorUnits(Money.maxMinorUnits, Currency.usd),
        isNotNull,
      );
      expect(
        Money.tryFromMinorUnits(Money.maxMinorUnits + 1, Currency.usd),
        isNull,
      );
      expect(
        Money.tryFromMinorUnits(-Money.maxMinorUnits - 1, Currency.usd),
        isNull,
      );
    });

    test('plus and minus return null on overflow or currency mismatch', () {
      final Money max = Money.tryFromMinorUnits(
        Money.maxMinorUnits,
        Currency.usd,
      )!;
      final Money one = Money.tryFromMinorUnits(1, Currency.usd)!;
      final Money euro = Money.tryFromMinorUnits(1, Currency.eur)!;
      expect(max.plus(one), isNull);
      expect(one.plus(euro), isNull);
      expect(one.minus(euro), isNull);
      expect(one.plus(one)?.minorUnits, 2);
      expect(one.minus(max)?.minorUnits, 1 - Money.maxMinorUnits);
    });
  });

  group('from decimal', () {
    test('exact', () {
      expect(
        Money.tryFromDecimalExact(d('12.50'), Currency.usd)?.minorUnits,
        1250,
      );
      expect(
        Money.tryFromDecimalExact(d('1200'), Currency.jpy)?.minorUnits,
        1200,
      );
      expect(
        Money.tryFromDecimalExact(d('1.234'), Currency.kwd)?.minorUnits,
        1234,
      );
      expect(Money.tryFromDecimalExact(d('12.5'), Currency.jpy), isNull);
      expect(Money.tryFromDecimalExact(d('12.345'), Currency.usd), isNull);
    });

    test('rounded', () {
      expect(
        Money.tryFromDecimalRounded(d('12.5'), Currency.jpy)?.minorUnits,
        13,
      );
      expect(
        Money.tryFromDecimalRounded(d('12.345'), Currency.usd)?.minorUnits,
        1235,
      );
    });

    test('range limits', () {
      expect(
        Money.tryFromDecimalExact(d('9999999999999.99'), Currency.usd),
        isNotNull,
      );
      expect(
        Money.tryFromDecimalExact(d('999999999999999'), Currency.usd),
        isNull,
      );
    });
  });

  test('toPlainString keeps fixed precision', () {
    String plain(int minor, Currency c) =>
        Money.tryFromMinorUnits(minor, c)!.toPlainString();
    expect(plain(1250, Currency.usd), '12.50');
    expect(plain(5, Currency.usd), '0.05');
    expect(plain(-5, Currency.usd), '-0.05');
    expect(plain(500, Currency.jpy), '500');
    expect(plain(5, Currency.kwd), '0.005');
    expect(plain(0, Currency.usd), '0.00');
  });

  test('toDecimal round-trips', () {
    final Money m = Money.tryFromMinorUnits(1250, Currency.usd)!;
    expect(m.toDecimal().toString(), '12.5');
    expect(Money.tryFromDecimalExact(m.toDecimal(), Currency.usd), m);
  });

  test('value equality includes currency', () {
    expect(
      Money.tryFromMinorUnits(100, Currency.usd),
      Money.tryFromMinorUnits(100, Currency.usd),
    );
    expect(
      Money.tryFromMinorUnits(100, Currency.usd),
      isNot(Money.tryFromMinorUnits(100, Currency.eur)),
    );
    expect(const Money.zero(Currency.usd).minorUnits, 0);
  });

  group('iso date', () {
    test('parses real dates to UTC midnight', () {
      expect(tryParseIsoDate('2026-11-08'), DateTime.utc(2026, 11, 8));
      expect(tryParseIsoDate('2024-02-29'), DateTime.utc(2024, 2, 29));
      expect(tryParseIsoDate(' 2026-11-08 '), DateTime.utc(2026, 11, 8));
    });

    test('rejects impossible or malformed dates', () {
      for (final String? bad in <String?>[
        null,
        '',
        'abc',
        '2023-02-29',
        '2026-13-01',
        '2026-00-10',
        '2026-04-31',
        '2026-1-1',
        '26-11-08',
        '2026/11/08',
      ]) {
        expect(tryParseIsoDate(bad), isNull, reason: '$bad');
      }
    });

    test('dateOnly and formatIsoDate', () {
      expect(
        dateOnly(DateTime(2026, 11, 8, 23, 59)),
        DateTime.utc(2026, 11, 8),
      );
      expect(formatIsoDate(DateTime.utc(2026, 1, 5)), '2026-01-05');
    });
  });
}
