/// Exact decimal number (BigInt unscaled value plus scale). Never uses
/// `double`. Stored normalized, so trailing zeros are dropped and
/// `2.50 == 2.5`.
///
/// Used for quantities (1.5 kg) and unit prices (fuel at 1.459 per litre),
/// which can carry more decimals than the currency's minor unit.
final class DecimalValue implements Comparable<DecimalValue> {
  DecimalValue._(this._unscaled, this._scale);

  static const int maxIntegerDigits = 15;
  static const int maxScale = 6;

  static final DecimalValue zero = DecimalValue._(BigInt.zero, 0);

  static final RegExp _pattern = RegExp(r'^(-)?(\d+)(?:\.(\d+))?$');
  static final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');

  final BigInt _unscaled;
  final int _scale;

  factory DecimalValue.fromInt(int value) => _norm(BigInt.from(value), 0);

  /// 1250 minor units at exponent 2 is 12.5.
  factory DecimalValue.fromMinorUnits(int minorUnits, int exponent) =>
      _norm(BigInt.from(minorUnits), exponent);

  /// Strict canonical input only: optional '-', digits, optional '.digits'.
  /// Use the locale-aware parser for user-typed text first. Returns null
  /// when malformed, above [maxIntegerDigits], or above [maxScale] decimals.
  static DecimalValue? tryParse(String? raw) {
    if (raw == null) return null;
    final RegExpMatch? m = _pattern.firstMatch(raw.trim());
    if (m == null) return null;
    final bool negative = m.group(1) != null;
    final String integer = m.group(2)!.replaceFirst(_leadingZeros, '');
    final String fraction = m.group(3) ?? '';
    if (integer.length > maxIntegerDigits || fraction.length > maxScale) {
      return null;
    }
    return _norm(
      BigInt.parse('${negative ? '-' : ''}$integer$fraction'),
      fraction.length,
    );
  }

  bool get isZero => _unscaled == BigInt.zero;
  bool get isNegative => _unscaled.isNegative;

  DecimalValue operator *(DecimalValue other) =>
      _norm(_unscaled * other._unscaled, _scale + other._scale);

  /// Minor units if this value fits [exponent] decimals exactly, otherwise
  /// null. Use for totals, where silently rounding would hide a misread.
  BigInt? exactMinorUnits(int exponent) {
    if (_scale > exponent) return null;
    return _unscaled * _pow10(exponent - _scale);
  }

  /// Minor units rounded half away from zero (2.345 -> 2.35, -2.345 -> -2.35).
  /// Use for qty x unit price comparisons.
  BigInt roundedMinorUnits(int exponent) {
    if (_scale <= exponent) return _unscaled * _pow10(exponent - _scale);
    final BigInt divisor = _pow10(_scale - exponent);
    final BigInt magnitude = _unscaled.abs();
    final BigInt quotient = magnitude ~/ divisor;
    final BigInt remainder = magnitude % divisor;
    final BigInt rounded = remainder * BigInt.two >= divisor
        ? quotient + BigInt.one
        : quotient;
    return _unscaled.isNegative ? -rounded : rounded;
  }

  @override
  int compareTo(DecimalValue other) {
    final int scale = _scale > other._scale ? _scale : other._scale;
    final BigInt a = _unscaled * _pow10(scale - _scale);
    final BigInt b = other._unscaled * _pow10(scale - other._scale);
    return a.compareTo(b);
  }

  @override
  bool operator ==(Object other) =>
      other is DecimalValue &&
      other._unscaled == _unscaled &&
      other._scale == _scale;

  @override
  int get hashCode => Object.hash(_unscaled, _scale);

  /// Canonical ASCII form with no trailing zeros ("12.5", "-0.05", "0").
  @override
  String toString() {
    final String sign = _unscaled.isNegative ? '-' : '';
    final String digits = _unscaled.abs().toString();
    if (_scale == 0) return '$sign$digits';
    final String padded = digits.padLeft(_scale + 1, '0');
    final String integer = padded.substring(0, padded.length - _scale);
    final String fraction = padded.substring(padded.length - _scale);
    return '$sign$integer.$fraction';
  }

  static DecimalValue _norm(BigInt unscaled, int scale) {
    if (unscaled == BigInt.zero) return DecimalValue._(BigInt.zero, 0);
    final BigInt ten = BigInt.from(10);
    BigInt u = unscaled;
    int s = scale;
    while (s > 0 && u % ten == BigInt.zero) {
      u = u ~/ ten;
      s--;
    }
    return DecimalValue._(u, s);
  }

  static BigInt _pow10(int n) => BigInt.from(10).pow(n);
}
