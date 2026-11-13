import 'package:equatable/equatable.dart';

import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/connectivity_monitor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extract_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

enum QueueStopReason {
  /// Every eligible record was attempted.
  completed,

  /// Offline, or a network failure ended the pass.
  offline,

  /// Quota or App Check rejected a call; retrying immediately would not help.
  blocked,

  /// The stop token was cancelled between records.
  stopped,
}

final class QueuePassSummary extends Equatable {
  const QueuePassSummary({
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.skipped,
    required this.stopReason,
  });

  final int processed;
  final int succeeded;
  final int failed;
  final int skipped;
  final QueueStopReason stopReason;

  @override
  List<Object?> get props => <Object?>[
    processed,
    succeeded,
    failed,
    skipped,
    stopReason,
  ];
}

/// One pass over the offline queue.
///
/// Eligible: `pendingExtraction` records with at least one prior attempt
/// (an interrupted read the user did ask for), and `failed` records whose
/// failure kind
/// `parksInOfflineQueue` (network). Everything else needs the user: a
/// timeout, quota, cancellation or blocked image is never retried here.
/// Records are attempted oldest first, one at a time, and a record that has
/// already used [maxAutoAttempts] attempts is left for a manual retry.
///
/// [stop] is checked between records only. Each extraction gets its own
/// fresh token, so pausing the queue never cancels a call in flight.
class ProcessExtractionQueue {
  ProcessExtractionQueue({
    required InvoiceRepository repository,
    required ExtractInvoice extract,
    required ConnectivityMonitor connectivity,
    required Currency Function() fallbackCurrency,
    this.maxAutoAttempts = 5,
  }) : _repository = repository,
       _extract = extract,
       _connectivity = connectivity,
       _fallbackCurrency = fallbackCurrency;

  static const Set<InvoiceStatus> _statuses = <InvoiceStatus>{
    InvoiceStatus.pendingExtraction,
    InvoiceStatus.failed,
  };

  final InvoiceRepository _repository;
  final ExtractInvoice _extract;
  final ConnectivityMonitor _connectivity;
  final Currency Function() _fallbackCurrency;
  final int maxAutoAttempts;

  bool _isEligible(InvoiceRecord r) {
    if (r.attemptCount >= maxAutoAttempts) return false;
    return switch (r.status) {
      // Only reads the user already asked for (interrupted ones). A scan
      // that was merely captured waits for the user's "Read invoice".
      InvoiceStatus.pendingExtraction => r.attemptCount > 0,
      InvoiceStatus.failed => r.failureKind?.parksInOfflineQueue ?? false,
      _ => false,
    };
  }

  Future<QueuePassSummary> runOnce({required CancellationToken stop}) async {
    final List<InvoiceRecord> candidates = (await _repository.listByStatus(
      _statuses,
    )).where(_isEligible).toList();

    int processed = 0;
    int succeeded = 0;
    int failed = 0;
    int skipped = 0;
    QueueStopReason reason = QueueStopReason.completed;

    for (final InvoiceRecord record in candidates) {
      if (stop.isCancelled) {
        reason = QueueStopReason.stopped;
        break;
      }
      if (!await _connectivity.isOnline()) {
        reason = QueueStopReason.offline;
        break;
      }

      final ExtractionOutcome outcome = await _extract(
        recordId: record.id,
        fallbackCurrency: _fallbackCurrency(),
        cancel: CancellationToken(),
      );
      processed++;

      switch (outcome) {
        case ExtractionSucceeded():
          succeeded++;
        case ExtractionSkipped():
          skipped++;
        case ExtractionFailed(:final InvoiceErrorKind kind):
          failed++;
          if (kind == InvoiceErrorKind.network) {
            reason = QueueStopReason.offline;
          } else if (kind == InvoiceErrorKind.quotaExceeded ||
              kind == InvoiceErrorKind.appCheckFailed) {
            reason = QueueStopReason.blocked;
          }
      }
      if (reason != QueueStopReason.completed) break;
    }

    return QueuePassSummary(
      processed: processed,
      succeeded: succeeded,
      failed: failed,
      skipped: skipped,
      stopReason: reason,
    );
  }
}
