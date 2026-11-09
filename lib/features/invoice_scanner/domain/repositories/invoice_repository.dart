import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';

/// Local persistence for [InvoiceRecord]s, which double as the offline queue.
///
/// Failure convention: implementations throw `InvoiceFailure` with a
/// taxonomy kind, or any other exception, which use cases map to
/// `unknown`. Messages must never contain invoice content.
abstract interface class InvoiceRepository {
  /// Inserts [record] only if no row with its id exists (idempotent: a
  /// replayed capture never duplicates or overwrites). Returns true when
  /// inserted, false when a row (including a tombstone) already existed.
  Future<bool> insertIfAbsent(InvoiceRecord record);

  /// The row with [id], or null. Includes tombstones (deleted rows), so
  /// callers can tell "deleted" from "never existed".
  Future<InvoiceRecord?> get(String id);

  /// Atomic read-modify-write. Reads the current row, applies [change], and
  /// writes the result in one transaction, so transitions always apply to
  /// fresh state. Returns the written record, or null if no row with [id]
  /// exists.
  ///
  /// - [change] must be synchronous and quick (it runs inside a transaction).
  /// - If [change] throws, nothing is written and the error propagates.
  /// - [change] must return a record with the same id; implementations
  ///   throw [ArgumentError] otherwise.
  /// - Writing a record with `isDeleted` persists a tombstone: only id,
  ///   status, timestamps and deletedAt are kept, and any invoice payload,
  ///   image paths and failure kind are erased.
  Future<InvoiceRecord?> mutate(
    String id,
    InvoiceRecord Function(InvoiceRecord current) change,
  );

  /// Live rows (not deleted) whose status is in [statuses], oldest
  /// `createdAt` first, ties broken by id. This is the queue order.
  Future<List<InvoiceRecord>> listByStatus(Set<InvoiceStatus> statuses);

  /// Saved, not-deleted records, newest `savedAt` first. Emits the current
  /// list on listen, then again after every change.
  Stream<List<InvoiceRecord>> watchSaved();
}
