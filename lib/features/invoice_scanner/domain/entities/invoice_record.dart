import 'package:equatable/equatable.dart';

import 'package:invoice_scanner/core/util/nullable.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

enum InvoiceStatus {
  /// Captured and compressed; waiting for network or a free worker.
  pendingExtraction,

  /// A Gemini call is in flight. A record found in this state at app launch
  /// is stale and must be reset with [InvoiceRecord.markPending].
  extracting,

  /// Extraction finished; waiting for the user to confirm.
  needsReview,

  /// Extraction failed; see [InvoiceRecord.failureKind].
  failed,

  /// Confirmed by the user.
  saved,
}

/// One scanned invoice's lifecycle row. Also the offline queue entry.
///
/// All timestamps are UTC. [id] is a client-generated UUID v4 and doubles as
/// the idempotency key and primary key. [imagePaths] holds the compressed
/// JPEGs in page order and is emptied by [markSaved] and [markDeleted]; the
/// caller reads the paths first and deletes the files.
final class InvoiceRecord extends Equatable {
  const InvoiceRecord({
    required this.id,
    required this.status,
    required this.imagePaths,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.invoice,
    this.failureKind,
    this.savedAt,
    this.remoteSyncedAt,
    this.deletedAt,
  }) : assert(attemptCount >= 0, 'attemptCount must not be negative'),
       assert(
         status != InvoiceStatus.needsReview || invoice != null,
         'needsReview requires an invoice',
       ),
       assert(
         status != InvoiceStatus.saved || invoice != null,
         'saved requires an invoice',
       ),
       assert(
         status != InvoiceStatus.failed || failureKind != null,
         'failed requires a failureKind',
       );

  factory InvoiceRecord.queued({
    required String id,
    required List<String> imagePaths,
    required DateTime now,
  }) {
    assert(now.isUtc, 'timestamps must be UTC');
    assert(imagePaths.isNotEmpty, 'a record needs at least one page');
    return InvoiceRecord(
      id: id,
      status: InvoiceStatus.pendingExtraction,
      imagePaths: List<String>.unmodifiable(imagePaths),
      attemptCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final InvoiceStatus status;
  final List<String> imagePaths;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Invoice? invoice;
  final InvoiceErrorKind? failureKind;
  final DateTime? savedAt;

  /// Reserved for the later sync phase. Nothing writes it in Phase 1.
  final DateTime? remoteSyncedAt;

  /// Soft delete marker, reserved for sync. Never queried as "live".
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// pendingExtraction or failed -> extracting. Counts an attempt.
  InvoiceRecord markExtracting(DateTime now) {
    _require(const <InvoiceStatus>{
      InvoiceStatus.pendingExtraction,
      InvoiceStatus.failed,
    }, 'markExtracting');
    return _copy(
      updatedAt: now,
      status: InvoiceStatus.extracting,
      attemptCount: attemptCount + 1,
      failureKind: () => null,
    );
  }

  /// extracting or failed -> pendingExtraction (requeue or launch recovery).
  InvoiceRecord markPending(DateTime now) {
    _require(const <InvoiceStatus>{
      InvoiceStatus.extracting,
      InvoiceStatus.failed,
    }, 'markPending');
    return _copy(
      updatedAt: now,
      status: InvoiceStatus.pendingExtraction,
      failureKind: () => null,
    );
  }

  /// extracting -> needsReview.
  InvoiceRecord markNeedsReview(Invoice extracted, DateTime now) {
    _require(const <InvoiceStatus>{
      InvoiceStatus.extracting,
    }, 'markNeedsReview');
    return _copy(
      updatedAt: now,
      status: InvoiceStatus.needsReview,
      invoice: () => extracted,
      failureKind: () => null,
    );
  }

  /// pendingExtraction or extracting -> failed.
  InvoiceRecord markFailed(InvoiceErrorKind kind, DateTime now) {
    _require(const <InvoiceStatus>{
      InvoiceStatus.pendingExtraction,
      InvoiceStatus.extracting,
    }, 'markFailed');
    return _copy(
      updatedAt: now,
      status: InvoiceStatus.failed,
      failureKind: () => kind,
    );
  }

  /// Autosaves review edits (survives backgrounding). needsReview only.
  InvoiceRecord withEditedInvoice(Invoice edited, DateTime now) {
    _require(const <InvoiceStatus>{
      InvoiceStatus.needsReview,
    }, 'withEditedInvoice');
    return _copy(updatedAt: now, invoice: () => edited);
  }

  /// needsReview -> saved. Clears [imagePaths]; the caller deletes the files
  /// after this record is persisted.
  InvoiceRecord markSaved(Invoice confirmed, DateTime now) {
    _require(const <InvoiceStatus>{InvoiceStatus.needsReview}, 'markSaved');
    return _copy(
      updatedAt: now,
      status: InvoiceStatus.saved,
      invoice: () => confirmed,
      imagePaths: const <String>[],
      failureKind: () => null,
      savedAt: () => now,
    );
  }

  /// Any status. Soft delete: clears [imagePaths]; the caller deletes the
  /// files. Idempotent: an existing [deletedAt] is kept.
  InvoiceRecord markDeleted(DateTime now) {
    return _copy(
      updatedAt: now,
      imagePaths: const <String>[],
      deletedAt: () => deletedAt ?? now,
    );
  }

  void _require(Set<InvoiceStatus> allowed, String operation) {
    if (!allowed.contains(status)) {
      throw StateError('InvoiceRecord in ${status.name} cannot $operation');
    }
  }

  InvoiceRecord _copy({
    required DateTime updatedAt,
    InvoiceStatus? status,
    List<String>? imagePaths,
    int? attemptCount,
    Nullable<Invoice>? invoice,
    Nullable<InvoiceErrorKind>? failureKind,
    Nullable<DateTime>? savedAt,
    Nullable<DateTime>? deletedAt,
  }) {
    return InvoiceRecord(
      id: id,
      status: status ?? this.status,
      imagePaths: imagePaths ?? this.imagePaths,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      invoice: invoice == null ? this.invoice : invoice(),
      failureKind: failureKind == null ? this.failureKind : failureKind(),
      savedAt: savedAt == null ? this.savedAt : savedAt(),
      remoteSyncedAt: remoteSyncedAt,
      deletedAt: deletedAt == null ? this.deletedAt : deletedAt(),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    status,
    imagePaths,
    attemptCount,
    createdAt,
    updatedAt,
    invoice,
    failureKind,
    savedAt,
    remoteSyncedAt,
    deletedAt,
  ];
}
