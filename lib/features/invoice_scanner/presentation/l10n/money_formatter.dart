import 'package:intl/intl.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

/// Display-only currency formatting. The value goes through a double
/// (exact for every [Money] to within the currency's own precision) and is
/// never parsed back; stored and computed amounts stay in minor units.
class MoneyFormatter {
  const MoneyFormatter(this.locale);

  final String locale;

  String format(Money money) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: locale,
      name: money.currency.code,
      decimalDigits: money.currency.minorUnitExponent,
    );
    return formatter.format(double.parse(money.toPlainString()));
  }
}
