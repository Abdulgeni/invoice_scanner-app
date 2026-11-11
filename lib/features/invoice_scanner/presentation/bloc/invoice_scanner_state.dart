part of 'invoice_scanner_bloc.dart';

/// States hold ids, file paths and entities, never image bytes.
sealed class InvoiceScannerState extends Equatable {
  const InvoiceScannerState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class InvoiceScannerInitial extends InvoiceScannerState {
  const InvoiceScannerInitial();
}

/// The native scanner is open.
final class InvoiceCapturing extends InvoiceScannerState {
  const InvoiceCapturing({required this.source});

  final ScanSource source;

  @override
  List<Object?> get props => <Object?>[source];
}

/// Pages came back; they are being compressed ("Optimizing").
final class InvoicePreprocessing extends InvoiceScannerState {
  const InvoicePreprocessing({required this.source, required this.pagePaths});

  final ScanSource source;

  /// The scanner's own files, valid until compression finishes.
  final List<String> pagePaths;

  @override
  List<Object?> get props => <Object?>[source, pagePaths];
}

enum CaptureFailureReason {
  tooManyPages,
  cameraPermissionDenied,
  scannerUnavailable,
  storageUnavailable,
  unknown,
}

/// The flow could not start or finish; no record was kept.
final class InvoiceCaptureFailure extends InvoiceScannerState {
  const InvoiceCaptureFailure({required this.reason, this.maxPages});

  final CaptureFailureReason reason;

  /// Set for [CaptureFailureReason.tooManyPages].
  final int? maxPages;

  @override
  List<Object?> get props => <Object?>[reason, maxPages];
}

/// The captured pages, waiting for the user's "Scan" or "Retake".
final class InvoiceImageReady extends InvoiceScannerState {
  const InvoiceImageReady({
    required this.recordId,
    required this.pagePaths,
    required this.source,
  });

  final String recordId;
  final List<String> pagePaths;
  final ScanSource source;

  @override
  List<Object?> get props => <Object?>[recordId, pagePaths, source];
}

/// The model is reading the pages ("Reading"). Pages stay visible.
final class InvoiceExtracting extends InvoiceScannerState {
  const InvoiceExtracting({
    required this.recordId,
    required this.pagePaths,
    required this.source,
  });

  final String recordId;
  final List<String> pagePaths;
  final ScanSource source;

  @override
  List<Object?> get props => <Object?>[recordId, pagePaths, source];
}

final class InvoiceExtractionFailure extends InvoiceScannerState {
  const InvoiceExtractionFailure({
    required this.recordId,
    required this.pagePaths,
    required this.source,
    required this.kind,
    required this.canRetry,
    required this.suggestsRetake,
    this.debugCode,
  });

  final String recordId;
  final List<String> pagePaths;
  final ScanSource source;
  final InvoiceErrorKind kind;
  final bool canRetry;
  final bool suggestsRetake;
  final String? debugCode;

  @override
  List<Object?> get props => <Object?>[
    recordId,
    pagePaths,
    source,
    kind,
    canRetry,
    suggestsRetake,
    debugCode,
  ];
}

/// One-shot messages for the review screen. They clear on the next edit.
enum ReviewNotice { saveFailed, draftNotSaved }

/// The editable confirmation screen. [warnings] are advice and never block
/// saving.
final class InvoiceReviewing extends InvoiceScannerState {
  const InvoiceReviewing({
    required this.recordId,
    required this.pagePaths,
    required this.invoice,
    required this.warnings,
    this.notice,
  });

  final String recordId;
  final List<String> pagePaths;
  final Invoice invoice;
  final List<ValidationWarning> warnings;
  final ReviewNotice? notice;

  InvoiceReviewing withNotice(ReviewNotice? value) => InvoiceReviewing(
    recordId: recordId,
    pagePaths: pagePaths,
    invoice: invoice,
    warnings: warnings,
    notice: value,
  );

  @override
  List<Object?> get props => <Object?>[
    recordId,
    pagePaths,
    invoice,
    warnings,
    notice,
  ];
}

final class InvoiceSaving extends InvoiceScannerState {
  const InvoiceSaving({
    required this.recordId,
    required this.pagePaths,
    required this.invoice,
  });

  final String recordId;
  final List<String> pagePaths;
  final Invoice invoice;

  @override
  List<Object?> get props => <Object?>[recordId, pagePaths, invoice];
}

final class InvoiceSaved extends InvoiceScannerState {
  const InvoiceSaved({required this.recordId, this.invoice});

  final String recordId;

  /// What was saved, for the success screen. Null when only the id is known.
  final Invoice? invoice;

  @override
  List<Object?> get props => <Object?>[recordId, invoice];
}
