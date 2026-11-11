import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

const List<String> commonCurrencyCodes = <String>[
  'USD',
  'EUR',
  'GBP',
  'JPY',
  'CHF',
  'CAD',
  'AUD',
  'CNY',
  'INR',
  'ETB',
  'KWD',
  'BHD',
  'OMR',
  'AED',
  'SAR',
  'ZAR',
  'KES',
  'NGN',
];

/// A short list of common currencies plus a field for any other ISO code.
Future<Currency?> showCurrencyPicker(
  BuildContext context, {
  required Currency current,
}) {
  return showModalBottomSheet<Currency>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
    builder: (BuildContext context) => _CurrencySheet(current: current),
  );
}

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({required this.current});

  final Currency current;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  final TextEditingController _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Currency? get _customCurrency =>
      _custom.text.length == 3 ? Currency.tryParse(_custom.text) : null;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final Currency? custom = _customCurrency;

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xl,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.currencyPickerTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final String code in commonCurrencyCodes)
                  ListTile(
                    title: Text(code),
                    selected: code == widget.current.code,
                    trailing: code == widget.current.code
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () =>
                        Navigator.of(context).pop(Currency.tryParse(code)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _custom,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.currencyCustomLabel,
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      final Currency? c = _customCurrency;
                      if (c != null) Navigator.of(context).pop(c);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed: custom == null
                      ? null
                      : () => Navigator.of(context).pop(custom),
                  child: Text(l10n.currencyUseCode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
