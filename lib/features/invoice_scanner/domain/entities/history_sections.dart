import 'package:equatable/equatable.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';

/// Live records split for the history screen.
final class HistorySections extends Equatable {
  const HistorySections({required this.attention, required this.saved});

  static const HistorySections empty = HistorySections(
    attention: <InvoiceRecord>[],
    saved: <InvoiceRecord>[],
  );

  /// Not read, being read, awaiting review, or failed. Most recently
  /// updated first.
  final List<InvoiceRecord> attention;

  /// Confirmed invoices. Most recently saved first.
  final List<InvoiceRecord> saved;

  bool get isEmpty => attention.isEmpty && saved.isEmpty;

  @override
  List<Object?> get props => <Object?>[attention, saved];
}

/// Pure grouping; deleted records are ignored.
HistorySections groupHistory(Iterable<InvoiceRecord> records) {
  final List<InvoiceRecord> attention = <InvoiceRecord>[];
  final List<InvoiceRecord> saved = <InvoiceRecord>[];
  for (final InvoiceRecord r in records) {
    if (r.isDeleted) continue;
    (r.status == InvoiceStatus.saved ? saved : attention).add(r);
  }
  attention.sort(_newestFirst((InvoiceRecord r) => r.updatedAt));
  saved.sort(_newestFirst((InvoiceRecord r) => r.savedAt ?? r.updatedAt));
  return HistorySections(
    attention: List<InvoiceRecord>.unmodifiable(attention),
    saved: List<InvoiceRecord>.unmodifiable(saved),
  );
}

int Function(InvoiceRecord, InvoiceRecord) _newestFirst(
  DateTime Function(InvoiceRecord) key,
) {
  return (InvoiceRecord a, InvoiceRecord b) {
    final int byTime = key(b).compareTo(key(a));
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  };
}
