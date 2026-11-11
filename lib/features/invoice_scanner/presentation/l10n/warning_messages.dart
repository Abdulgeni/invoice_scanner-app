import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Plain-language text for one validation finding. Amounts come from the
/// finding's own expected and actual values.
String warningMessage(
  AppLocalizations l10n,
  ValidationWarning w,
  MoneyFormatter money, {
  required String currencyCode,
}) {
  String amount(Money? m) => m == null ? '' : money.format(m);
  final String hint = switch (w.hint) {
    MismatchHint.possibleDiscount => l10n.hintDiscount,
    MismatchHint.possibleExtraCharge => l10n.hintExtraCharge,
    null => '',
  };
  return switch (w.code) {
    ValidationCode.currencyAssumed => l10n.warningCurrencyAssumed(currencyCode),
    ValidationCode.currencyInconsistent => l10n.warningCurrencyInconsistent,
    ValidationCode.unreadableValue =>
      w.field.field == InvoiceField.lineItems
          ? l10n.warningUnreadableLines
          : l10n.warningUnreadable,
    ValidationCode.missingVendor => l10n.warningMissingVendor,
    ValidationCode.missingDate => l10n.warningMissingDate,
    ValidationCode.missingTotal => l10n.warningMissingTotal,
    ValidationCode.missingSubtotal => l10n.warningMissingSubtotal,
    ValidationCode.missingTax => l10n.warningMissingTax,
    ValidationCode.missingLineDescription => l10n.warningMissingLineDescription,
    ValidationCode.missingLineTotal => l10n.warningMissingLineTotal,
    ValidationCode.noLineItems => l10n.warningNoLineItems,
    ValidationCode.futureDate => l10n.warningFutureDate,
    ValidationCode.oldDate => l10n.warningOldDate,
    ValidationCode.zeroTotal => l10n.warningZeroTotal,
    ValidationCode.negativeAmount => l10n.warningNegativeAmount,
    ValidationCode.lineMathMismatch => l10n.warningLineMathMismatch(
      amount(w.expected),
      amount(w.actual),
    ),
    ValidationCode.lineSumMismatch =>
      l10n
          .warningLineSumMismatch(amount(w.expected), amount(w.actual), hint)
          .trim(),
    ValidationCode.totalMismatch =>
      l10n
          .warningTotalMismatchSum(amount(w.expected), amount(w.actual), hint)
          .trim(),
  };
}

/// Label for a one-tap fix button.
String fixLabel(AppLocalizations l10n, SetMoneyFix fix, MoneyFormatter money) {
  final String value = money.format(fix.value);
  return switch (fix.field.field) {
    InvoiceField.subtotal => l10n.fixSetSubtotal(value),
    InvoiceField.tax => l10n.fixSetTax(value),
    InvoiceField.total => l10n.fixSetTotal(value),
    _ => value,
  };
}
