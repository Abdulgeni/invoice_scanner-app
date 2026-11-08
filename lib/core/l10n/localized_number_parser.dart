import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

enum DecimalParseFailure {
  empty,
  noDigits,
  invalidCharacter,
  invalidGrouping,
  multipleDecimalSeparators,
  tooManyDecimals,
  tooLarge,
}

sealed class DecimalParseResult {
  const DecimalParseResult();
}

final class DecimalParsed extends DecimalParseResult {
  const DecimalParsed(this.canonical);
  final String canonical;
}

final class DecimalParseFailed extends DecimalParseResult {
  const DecimalParseFailed(this.reason);
  final DecimalParseFailure reason;
}

/// Parses user-typed numbers using a locale's separators.
///
/// String-only: never goes through `double`.
///
/// Known limitation (do not "fix" into a guess): in `en`, a user typing
/// `1,234` meaning `1.234` gets `1234`. Grouping is well-formed, so the
/// parser cannot tell. Module 4 validation warnings are the safety net.
///
/// Currency symbols and ISO codes are rejected. Call [stripCurrencyPrefix]
/// before [parse] if the input might contain them.
class LocalizedNumberParser {
  LocalizedNumberParser.withSeparators({
    required String decimal,
    required String group,
    String zeroDigit = '0',
    String minus = '-',
    this.allowIndianGrouping = false,
  }) : _decimal = decimal,
       _group = group,
       _zeroRune = zeroDigit.runes.first,
       _localeMinus = minus.replaceAll(_bidiMarks, '');

  // [M2-ADJUST-3] Also accept hi/bn for Indian grouping.
  static const Set<String> _indianGroupingLocales = <String>{'hi', 'bn'};

  factory LocalizedNumberParser.forLocale(String localeName) {
    final String canonical = Intl.canonicalizedLocale(localeName);
    final String short = Intl.shortLocale(canonical);
    final symbols =
        numberFormatSymbols[canonical] ?? numberFormatSymbols[short];
    if (symbols == null) {
      return LocalizedNumberParser.withSeparators(decimal: '.', group: ',');
    }
    // [M2-ADJUST-3]
    final bool indian =
        canonical.endsWith('_IN') || _indianGroupingLocales.contains(short);
    return LocalizedNumberParser.withSeparators(
      decimal: symbols.DECIMAL_SEP,
      group: symbols.GROUP_SEP,
      zeroDigit: symbols.ZERO_DIGIT,
      minus: symbols.MINUS_SIGN,
      allowIndianGrouping: indian,
    );
  }

  static const int maxIntegerDigits = 15;
  static const int maxFractionDigits = 6;

  final bool allowIndianGrouping;

  final String _decimal;
  final String _group;
  final int _zeroRune;
  final String _localeMinus;

  static final RegExp _bidiMarks = RegExp('[\u200E\u200F\u061C]');
  static final RegExp _leadingZeros = RegExp(r'^0+');
  static final RegExp _allZeros = RegExp(r'^0*$');
  static const String _groupMarker = '\u001F';
  static const int _markerRune = 0x1F;

  static const Set<int> _universalGroupRunes = <int>{
    0x20,
    0xA0,
    0x2007,
    0x2009,
    0x202F,
    0x27,
    0x2019,
  };

  // [M2-ADJUST-2] Strip an optional ISO-4217 code or common currency symbol
  // and a single trailing space. Does not touch the parser itself.
  static final RegExp _currencyPrefix = RegExp(r'^\s*(?:[A-Z]{3}|\$|€|£|¥)\s*');

  static String stripCurrencyPrefix(String input) =>
      input.replaceFirst(_currencyPrefix, '');

  DecimalParseResult parse(String input) {
    String s = input.replaceAll(_bidiMarks, '').trim();
    if (s.isEmpty) return _fail(DecimalParseFailure.empty);
    s = _toAsciiDigits(s);

    bool negative = false;
    if (s.length >= 2 && s.startsWith('(') && s.endsWith(')')) {
      negative = true;
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isNotEmpty) {
      final String first = s[0];
      if (first == '+') {
        s = s.substring(1).trimLeft();
      } else if (_isMinus(first)) {
        if (negative) return _fail(DecimalParseFailure.invalidCharacter);
        negative = true;
        s = s.substring(1).trimLeft();
      }
    }

    final int decAt = s.indexOf(_decimal);
    if (decAt != s.lastIndexOf(_decimal)) {
      return _fail(DecimalParseFailure.multipleDecimalSeparators);
    }
    final String intPart = decAt < 0 ? s : s.substring(0, decAt);
    final String fracPart = decAt < 0
        ? ''
        : s.substring(decAt + _decimal.length);
    if (!_isAsciiDigits(fracPart)) {
      return _fail(DecimalParseFailure.invalidCharacter);
    }

    final List<String> groups = <String>[];
    final StringBuffer current = StringBuffer();
    for (final int r in intPart.replaceAll(_group, _groupMarker).runes) {
      if (r >= 0x30 && r <= 0x39) {
        current.writeCharCode(r);
      } else if (r == _markerRune || _universalGroupRunes.contains(r)) {
        groups.add(current.toString());
        current.clear();
      } else {
        return _fail(DecimalParseFailure.invalidCharacter);
      }
    }
    groups.add(current.toString());

    final String digits;
    if (groups.length == 1) {
      digits = groups.first;
    } else {
      if (!_validGrouping(groups)) {
        return _fail(DecimalParseFailure.invalidGrouping);
      }
      digits = groups.join();
    }

    if (digits.isEmpty && fracPart.isEmpty) {
      return _fail(DecimalParseFailure.noDigits);
    }

    String integer = digits.replaceFirst(_leadingZeros, '');
    if (integer.isEmpty) integer = '0';
    if (integer.length > maxIntegerDigits) {
      return _fail(DecimalParseFailure.tooLarge);
    }
    if (fracPart.length > maxFractionDigits) {
      return _fail(DecimalParseFailure.tooManyDecimals);
    }

    final bool isZero = _allZeros.hasMatch('$digits$fracPart');
    final String sign = (negative && !isZero) ? '-' : '';
    final String fraction = fracPart.isEmpty ? '' : '.$fracPart';
    return DecimalParsed('$sign$integer$fraction');
  }

  bool _validGrouping(List<String> g) {
    if (g.any((String x) => x.isEmpty)) return false;
    final String first = g.first;
    final String last = g.last;
    final bool standard =
        first.length <= 3 && g.skip(1).every((String x) => x.length == 3);
    if (standard) return true;
    if (!allowIndianGrouping) return false;
    final List<String> middle = g.sublist(1, g.length - 1);
    return first.length <= 2 &&
        last.length == 3 &&
        middle.every((String x) => x.length == 2);
  }

  bool _isMinus(String ch) => ch == '-' || ch == '\u2212' || ch == _localeMinus;

  int? _digitValue(int r) {
    if (r >= 0x30 && r <= 0x39) return r - 0x30;
    if (r >= _zeroRune && r <= _zeroRune + 9) return r - _zeroRune;
    if (r >= 0x0660 && r <= 0x0669) return r - 0x0660;
    if (r >= 0x06F0 && r <= 0x06F9) return r - 0x06F0;
    if (r >= 0xFF10 && r <= 0xFF19) return r - 0xFF10;
    return null;
  }

  String _toAsciiDigits(String s) {
    final StringBuffer b = StringBuffer();
    for (final int r in s.runes) {
      final int? v = _digitValue(r);
      b.writeCharCode(v == null ? r : 0x30 + v);
    }
    return b.toString();
  }

  static bool _isAsciiDigits(String s) =>
      s.runes.every((int r) => r >= 0x30 && r <= 0x39);

  static DecimalParseFailed _fail(DecimalParseFailure reason) =>
      DecimalParseFailed(reason);
}
