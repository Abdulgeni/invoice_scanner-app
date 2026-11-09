import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

/// Product metrics. Implementations must never receive invoice content:
/// no vendor names, amounts, numbers, text, or file paths.
abstract interface class ScanAnalytics {
  /// One event per finished extraction attempt. [errorKind] null means
  /// success. Failure rate = events with an error / all events.
  /// [captureToResult] runs from capture to this attempt's end, so it
  /// includes any time spent waiting in the offline queue.
  void extractionFinished({
    required Duration captureToResult,
    required int attempt,
    InvoiceErrorKind? errorKind,
  });

  /// The user changed [field] during review. Per-field correction rate =
  /// corrections / reviews.
  void fieldCorrected(InvoiceField field);
}

/// Default sink: drops everything.
final class NoopScanAnalytics implements ScanAnalytics {
  const NoopScanAnalytics();

  @override
  void extractionFinished({
    required Duration captureToResult,
    required int attempt,
    InvoiceErrorKind? errorKind,
  }) {}

  @override
  void fieldCorrected(InvoiceField field) {}
}
