import 'package:equatable/equatable.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

enum WarningSeverity {
  /// Needs the user's attention before confirming.
  warning,

  /// Worth knowing; safe to ignore.
  info,
}

enum ValidationCode {
  currencyAssumed,
  currencyInconsistent,
  unreadableValue,
  missingVendor,
  missingDate,
  missingTotal,
  missingSubtotal,
  missingTax,
  missingLineDescription,
  missingLineTotal,
  noLineItems,
  futureDate,
  oldDate,
  zeroTotal,
  negativeAmount,
  lineMathMismatch,
  lineSumMismatch,
  totalMismatch,
}

/// Why two amounts might legitimately differ. Drives gentle copy such as
/// "a discount could explain this" instead of "wrong total".
enum MismatchHint {
  /// The printed figure is smaller than computed (a discount, for example).
  possibleDiscount,

  /// The printed figure is larger than computed (shipping, tip, fees).
  possibleExtraCharge,
}

sealed class SuggestedFix extends Equatable {
  const SuggestedFix();
}

/// One-tap fix: set an amount field to [value].
final class SetMoneyFix extends SuggestedFix {
  const SetMoneyFix(this.field, this.value);

  final FieldRef field;
  final Money value;

  @override
  List<Object?> get props => <Object?>[field, value];
}

/// One finding. Carries data, not text; the UI picks the wording per [code].
final class ValidationWarning extends Equatable {
  const ValidationWarning({
    required this.code,
    required this.severity,
    required this.field,
    this.expected,
    this.actual,
    this.hint,
    this.fixes = const <SuggestedFix>[],
  });

  final ValidationCode code;
  final WarningSeverity severity;

  /// The field to highlight on the review screen.
  final FieldRef field;

  /// What the arithmetic says the value should be, when it can be computed.
  final Money? expected;

  /// What the invoice currently holds.
  final Money? actual;
  final MismatchHint? hint;
  final List<SuggestedFix> fixes;

  @override
  List<Object?> get props => <Object?>[
    code,
    severity,
    field,
    expected,
    actual,
    hint,
    fixes,
  ];
}
