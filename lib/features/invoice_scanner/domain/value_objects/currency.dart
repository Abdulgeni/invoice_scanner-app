import 'package:equatable/equatable.dart';

/// ISO 4217 currency with its minor-unit exponent.
///
/// Not a full ISO table: currencies with a non-2 exponent are listed
/// explicitly, and any other well-formed three-letter code is assumed to use 2.
final class Currency extends Equatable {
  const Currency._(this.code, this.minorUnitExponent);

  static const Currency usd = Currency._('USD', 2);
  static const Currency eur = Currency._('EUR', 2);
  static const Currency gbp = Currency._('GBP', 2);
  static const Currency jpy = Currency._('JPY', 0);
  static const Currency kwd = Currency._('KWD', 3);

  /// Uppercase ISO 4217 code.
  final String code;

  /// Digits after the decimal point in the minor unit (JPY 0, USD 2, KWD 3).
  final int minorUnitExponent;

  /// Returns null for anything that is not a plausible ISO 4217 code.
  static Currency? tryParse(String? raw) {
    if (raw == null) return null;
    final String code = raw.trim().toUpperCase();
    if (!_codePattern.hasMatch(code) || code == 'XXX') return null;
    return Currency._(code, _exponents[code] ?? 2);
  }

  /// 10 to the power of [minorUnitExponent].
  int get minorUnitFactor {
    int factor = 1;
    for (int i = 0; i < minorUnitExponent; i++) {
      factor *= 10;
    }
    return factor;
  }

  static final RegExp _codePattern = RegExp(r'^[A-Z]{3}$');

  // Exponents that differ from 2, following ISO 4217.
  static const Map<String, int> _exponents = <String, int>{
    // 0 decimals
    'BIF': 0, 'CLP': 0, 'DJF': 0, 'GNF': 0, 'ISK': 0, 'JPY': 0, 'KMF': 0,
    'KRW': 0, 'PYG': 0, 'RWF': 0, 'UGX': 0, 'UYI': 0, 'VND': 0, 'VUV': 0,
    'XAF': 0, 'XOF': 0, 'XPF': 0,
    // 3 decimals
    'BHD': 3, 'IQD': 3, 'JOD': 3, 'KWD': 3, 'LYD': 3, 'OMR': 3, 'TND': 3,
    // 4 decimals
    'CLF': 4, 'UYW': 4,
  };

  @override
  List<Object?> get props => <Object?>[code, minorUnitExponent];

  @override
  String toString() => code;
}
