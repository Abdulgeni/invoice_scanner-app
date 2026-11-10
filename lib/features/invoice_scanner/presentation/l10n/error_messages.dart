import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/invoice_limits.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Human text for an extraction failure. Never mentions providers or codes.
String extractionErrorMessage(AppLocalizations l10n, InvoiceErrorKind kind) {
  return switch (kind) {
    InvoiceErrorKind.network => l10n.errorNetwork,
    InvoiceErrorKind.timeout => l10n.errorTimeout,
    InvoiceErrorKind.quotaExceeded => l10n.errorQuotaExceeded,
    InvoiceErrorKind.appCheckFailed => l10n.errorAppCheckFailed,
    InvoiceErrorKind.safetyBlock => l10n.errorSafetyBlock,
    InvoiceErrorKind.emptyResponse => l10n.errorEmptyResponse,
    InvoiceErrorKind.malformedJson => l10n.errorMalformedJson,
    InvoiceErrorKind.notAnInvoice => l10n.errorNotAnInvoice,
    InvoiceErrorKind.cancelled => l10n.errorCancelled,
    InvoiceErrorKind.unknown => l10n.errorUnknown,
  };
}

String captureErrorMessage(
  AppLocalizations l10n,
  CaptureFailureReason reason, {
  int? maxPages,
}) {
  return switch (reason) {
    CaptureFailureReason.tooManyPages => l10n.pageLimitExceeded(
      maxPages ?? InvoiceLimits.maxPages,
    ),
    CaptureFailureReason.cameraPermissionDenied =>
      l10n.captureErrorCameraDenied,
    CaptureFailureReason.scannerUnavailable =>
      l10n.captureErrorScannerUnavailable,
    CaptureFailureReason.storageUnavailable => l10n.captureErrorStorage,
    CaptureFailureReason.unknown => l10n.captureErrorUnknown,
  };
}
