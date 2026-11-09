import 'package:equatable/equatable.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';

/// Amount in integer minor units (cents, yen, fils) plus its currency.
///
/// Bounded to +/- [maxMinorUnits], which is below 2^53, so values are safe
/// on every platform and in SQLite INTEGER columns. Factories return null
/// instead of wrapping or throwing.
final class Money extends Equatable {
  const Money._(this.minorUnits, this.currency);

  const Money.zero(this.currency) : minorUnits = 0;

  static const int maxMinorUnits = 999999999999999;
  static final BigInt _maxBig = BigInt.from(maxMinorUnits);

  final int minorUnits;
  final Currency currency;

  static Money? tryFromMinorUnits(int minorUnits, Currency currency) {
    if (minorUnits.abs() > maxMinorUnits) return null;
    return Money._(minorUnits, currency);
  }

  /// Null if [value] has more decimals than the currency allows
  /// (12.345 USD) or is out of range.
  static Money? tryFromDecimalExact(DecimalValue value, Currency currency) {
    final BigInt? minor = value.exactMinorUnits(currency.minorUnitExponent);
    return minor == null ? null : _fromBig(minor, currency);
  }

  /// Rounds half away from zero. Null only when out of range.
  static Money? tryFromDecimalRounded(DecimalValue value, Currency currency) {
    return _fromBig(
      value.roundedMinorUnits(currency.minorUnitExponent),
      currency,
    );
  }

  bool get isNegative => minorUnits < 0;

  /// Null on currency mismatch or overflow.
  Money? plus(Money other) {
    if (other.currency != currency) return null;
    return tryFromMinorUnits(minorUnits + other.minorUnits, currency);
  }

  /// Null on currency mismatch or overflow.
  Money? minus(Money other) {
    if (other.currency != currency) return null;
    return tryFromMinorUnits(minorUnits - other.minorUnits, currency);
  }

  DecimalValue toDecimal() =>
      DecimalValue.fromMinorUnits(minorUnits, currency.minorUnitExponent);

  /// Fixed-precision ASCII form ("12.50", "500", "0.005"). For persistence
  /// and seeding edit fields; locale formatting is a presentation concern.
  String toPlainString() {
    final int exponent = currency.minorUnitExponent;
    final int magnitude = minorUnits.abs();
    final String sign = minorUnits < 0 ? '-' : '';
    if (exponent == 0) return '$sign$magnitude';
    final int factor = currency.minorUnitFactor;
    final String major = (magnitude ~/ factor).toString();
    final String minor = (magnitude % factor).toString().padLeft(exponent, '0');
    return '$sign$major.$minor';
  }

  static Money? _fromBig(BigInt minor, Currency currency) {
    if (minor.abs() > _maxBig) return null;
    return Money._(minor.toInt(), currency);
  }

  @override
  List<Object?> get props => <Object?>[minorUnits, currency];

  @override
  String toString() => '${toPlainString()} ${currency.code}';
}
