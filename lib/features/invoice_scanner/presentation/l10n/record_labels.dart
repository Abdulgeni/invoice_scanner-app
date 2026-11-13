import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/error_presentation.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// The name shown for a record: the vendor when known.
String recordTitle(AppLocalizations l10n, InvoiceRecord record) {
  final String? vendor = record.invoice?.vendorName?.trim();
  if (vendor != null && vendor.isNotEmpty) return vendor;
  return switch (record.status) {
    InvoiceStatus.saved || InvoiceStatus.needsReview => l10n.invoiceUnnamed,
    _ => l10n.historyUnreadInvoice,
  };
}

/// Where a record stands, in plain words. Failures reuse the wording of the
/// error screen, so the history never leaks backend terms.
String recordStatus(AppLocalizations l10n, InvoiceRecord record) {
  return switch (record.status) {
    InvoiceStatus.pendingExtraction => l10n.statusNotRead,
    InvoiceStatus.extracting => l10n.statusReading,
    InvoiceStatus.needsReview => l10n.statusNeedsReview,
    InvoiceStatus.saved => l10n.statusSaved,
    InvoiceStatus.failed => switch (record.failureKind) {
        null || InvoiceErrorKind.cancelled => l10n.statusNotRead,
        final InvoiceErrorKind kind => presentationFor(l10n, kind).title,
      },
  };
}
