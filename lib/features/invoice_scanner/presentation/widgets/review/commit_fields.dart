import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:invoice_scanner/core/l10n/localized_number_parser.dart';
import 'package:invoice_scanner/core/theme/app_typography.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

// A field reports what the user typed upward as a value. The parent's copy
// of that value comes back down as a prop. To tell "my own value coming back"
// (possibly one frame late) from "something else changed it" (a one-tap fix,
// a currency change), each field remembers the values it recently reported:
// an incoming value it recognizes is an echo and must not rewrite the text
// the user is typing. Once the parent has caught up with the latest value,
// older ones are forgotten, so a later external change to an old value still
// takes effect.
const int _maxEchoes = 16;

class TextEntryField extends StatefulWidget {
  const TextEntryField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLength = 200,
    this.capitalization = TextCapitalization.sentences,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  final String label;
  final String? value;

  /// Trimmed text, or null when empty.
  final ValueChanged<String?> onChanged;
  final int maxLength;
  final TextCapitalization capitalization;
  final TextInputAction textInputAction;

  @override
  State<TextEntryField> createState() => _TextEntryFieldState();
}

class _TextEntryFieldState extends State<TextEntryField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );
  late String? _committed = _norm(widget.value);
  late final List<String?> _echoes = <String?>[_committed];

  static String? _norm(String? s) {
    final String? t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  @override
  void didUpdateWidget(TextEntryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? incoming = _norm(widget.value);
    if (incoming == _committed) {
      _echoes
        ..clear()
        ..add(incoming);
      return;
    }
    if (_echoes.contains(incoming)) return;
    _echoes
      ..clear()
      ..add(incoming);
    _committed = incoming;
    final String text = widget.value ?? '';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onChanged(String text) {
    final String? value = _norm(text);
    _committed = value;
    _echoes.add(value);
    if (_echoes.length > _maxEchoes) _echoes.removeAt(0);
    widget.onChanged(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.capitalization,
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      decoration: InputDecoration(labelText: widget.label),
      onChanged: _onChanged,
    );
  }
}

enum AmountProblem { notANumber, tooManyDecimals, tooLarge }

/// A number field with locale-aware parsing. Only a value that parses and
/// passes [problemFor] is reported; anything else shows an inline error,
/// leaves the last good value in place, and reports itself invalid.
class AmountField extends StatefulWidget {
  const AmountField({
    required this.label,
    required this.value,
    required this.seed,
    required this.problemFor,
    required this.maxFractionDigits,
    required this.exampleCanonical,
    required this.onChanged,
    required this.onValidityChanged,
    this.suffixText,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  /// A money amount in [currency]: exact to its minor unit, shown with fixed
  /// decimals.
  AmountField.money({
    required this.label,
    required Money? money,
    required Currency currency,
    required this.onChanged,
    required this.onValidityChanged,
    this.textInputAction = TextInputAction.next,
    super.key,
  }) : value = money?.toDecimal(),
       maxFractionDigits = currency.minorUnitExponent,
       exampleCanonical = _example(currency.minorUnitExponent),
       seed = _moneySeed(currency),
       problemFor = _moneyProblem(currency),
       suffixText = currency.code;

  final String label;
  final DecimalValue? value;

  /// Canonical ASCII text used when the field is (re)filled from [value].
  final String Function(DecimalValue value) seed;
  final AmountProblem? Function(DecimalValue value) problemFor;
  final int maxFractionDigits;

  /// A valid canonical number, shown in the "enter a valid number" message.
  final String exampleCanonical;
  final ValueChanged<DecimalValue?> onChanged;
  final ValueChanged<bool> onValidityChanged;
  final String? suffixText;
  final TextInputAction textInputAction;

  static String _example(int exponent) =>
      exponent == 0 ? '1234' : '1234.${'5'.padRight(exponent, '0')}';

  static String Function(DecimalValue) _moneySeed(Currency currency) {
    return (DecimalValue d) =>
        Money.tryFromDecimalExact(d, currency)?.toPlainString() ?? d.toString();
  }

  static AmountProblem? Function(DecimalValue) _moneyProblem(
    Currency currency,
  ) {
    return (DecimalValue d) {
      if (d.exactMinorUnits(currency.minorUnitExponent) == null) {
        return AmountProblem.tooManyDecimals;
      }
      if (Money.tryFromDecimalExact(d, currency) == null) {
        return AmountProblem.tooLarge;
      }
      return null;
    };
  }

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  static final RegExp _allowed = RegExp(
    r'[\p{Nd}\s.,\u2212\-+()\u2019\u00A0\u202F\u066B\u066C]',
    unicode: true,
  );

  late LocalizedNumberParser _parser;
  late TextEditingController _controller;
  bool _initialized = false;
  late DecimalValue? _committed = widget.value;
  late final List<DecimalValue?> _echoes = <DecimalValue?>[_committed];
  AmountProblem? _problem;

  String _seedText(DecimalValue? value) =>
      value == null ? '' : _parser.localize(widget.seed(value));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parser = LocalizedNumberParser.forLocale(
      Localizations.localeOf(context).toString(),
    );
    if (!_initialized) {
      _controller = TextEditingController(text: _seedText(widget.value));
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final DecimalValue? incoming = widget.value;
    if (incoming == _committed) {
      _echoes
        ..clear()
        ..add(incoming);
      return;
    }
    if (_echoes.contains(incoming)) return;
    _echoes
      ..clear()
      ..add(incoming);
    _committed = incoming;
    final String text = _seedText(incoming);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _problem = null;
    widget.onValidityChanged(true);
  }

  void _onChanged(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      _setProblem(null);
      _commit(null);
      return;
    }
    switch (_parser.parse(trimmed)) {
      case DecimalParseFailed(:final DecimalParseFailure reason):
        _setProblem(switch (reason) {
          DecimalParseFailure.tooManyDecimals => AmountProblem.tooManyDecimals,
          DecimalParseFailure.tooLarge => AmountProblem.tooLarge,
          _ => AmountProblem.notANumber,
        });
      case DecimalParsed(:final String canonical):
        final DecimalValue? parsed = DecimalValue.tryParse(canonical);
        if (parsed == null) {
          _setProblem(AmountProblem.notANumber);
          return;
        }
        final AmountProblem? problem = widget.problemFor(parsed);
        _setProblem(problem);
        if (problem == null) _commit(parsed);
    }
  }

  void _commit(DecimalValue? value) {
    _committed = value;
    _echoes.add(value);
    if (_echoes.length > _maxEchoes) _echoes.removeAt(0);
    widget.onChanged(value);
  }

  void _setProblem(AmountProblem? problem) {
    if (problem != _problem) setState(() => _problem = problem);
    widget.onValidityChanged(problem == null);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.onValidityChanged(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? error = switch (_problem) {
      null => null,
      AmountProblem.notANumber => l10n.validationInvalidNumber(
        _parser.localize(widget.exampleCanonical),
      ),
      AmountProblem.tooManyDecimals =>
        widget.maxFractionDigits == 0
            ? l10n.validationWholeNumberOnly
            : l10n.validationTooManyDecimals(widget.maxFractionDigits),
      AmountProblem.tooLarge => l10n.validationNumberTooLarge,
    };
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textInputAction: widget.textInputAction,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(_allowed),
        LengthLimitingTextInputFormatter(32),
      ],
      style: AppMoneyStyles.of(context).body,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: error,
        suffixText: widget.suffixText,
      ),
      onChanged: _onChanged,
    );
  }
}
