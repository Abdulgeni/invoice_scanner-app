import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

/// Maps anything caught at a use-case boundary to exactly one taxonomy kind.
/// Never reads the error's message or `toString`: those could contain
/// invoice content.
InvoiceFailure mapToFailure(Object error) {
  if (error is InvoiceFailure) return error;
  if (error is CancelledException) {
    return const InvoiceFailure(InvoiceErrorKind.cancelled);
  }
  return const InvoiceFailure(
    InvoiceErrorKind.unknown,
    debugCode: DebugCodes.unexpected,
  );
}
