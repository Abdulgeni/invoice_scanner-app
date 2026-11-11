part of 'invoice_scanner_bloc.dart';

sealed class InvoiceScannerEvent extends Equatable {
  const InvoiceScannerEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Open the scanner. Accepted from the start screen and after a capture
/// failure.
final class ScanRequested extends InvoiceScannerEvent {
  const ScanRequested(this.source);

  final ScanSource source;

  @override
  List<Object?> get props => <Object?>[source];
}

/// "Scan" on the preview, or "Try again" after a retryable failure.
final class ExtractRequested extends InvoiceScannerEvent {
  const ExtractRequested();
}

/// Cancels the active capture, optimizing or reading step.
final class CancelRequested extends InvoiceScannerEvent {
  const CancelRequested();
}

/// Throws away the current record and scans again.
final class RetakeRequested extends InvoiceScannerEvent {
  const RetakeRequested();
}

/// Deletes the current record and its images and returns to the start.
final class DiscardRequested extends InvoiceScannerEvent {
  const DiscardRequested();
}

/// "Keep image" on a failure: leave the record as it is and go back.
final class KeepImageRequested extends InvoiceScannerEvent {
  const KeepImageRequested();
}

/// Leave a terminal screen (saved, or a capture failure).
final class ResetRequested extends InvoiceScannerEvent {
  const ResetRequested();
}

/// Resume an existing record, for example from the history list.
final class RecordOpened extends InvoiceScannerEvent {
  const RecordOpened(this.recordId);

  final String recordId;

  @override
  List<Object?> get props => <Object?>[recordId];
}

/// The review form changed; carries the whole edited invoice.
final class InvoiceEdited extends InvoiceScannerEvent {
  const InvoiceEdited(this.invoice);

  final Invoice invoice;

  @override
  List<Object?> get props => <Object?>[invoice];
}

final class FixApplied extends InvoiceScannerEvent {
  const FixApplied(this.fix);

  final SuggestedFix fix;

  @override
  List<Object?> get props => <Object?>[fix];
}

/// The user confirms an "unreadable" field really is empty.
final class UnreadableDismissed extends InvoiceScannerEvent {
  const UnreadableDismissed(this.field);

  final FieldRef field;

  @override
  List<Object?> get props => <Object?>[field];
}

final class SaveRequested extends InvoiceScannerEvent {
  const SaveRequested();
}

/// The app is going to the background: persist any unsaved review edits now.
final class AppPaused extends InvoiceScannerEvent {
  const AppPaused();
}

/// The review form changed. The change is a function of the CURRENT invoice,
/// so rapid edits can never be applied to a stale copy.
final class InvoiceChanged extends InvoiceScannerEvent {
  const InvoiceChanged(this.transform);

  final Invoice Function(Invoice current) transform;

  @override
  List<Object?> get props => <Object?>[transform];
}

final class _DraftTick extends InvoiceScannerEvent {
  const _DraftTick();
}
