import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/analytics/scan_analytics.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/failure_mapper.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_store.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

enum ExtractionSkipReason {
  /// No row with this id.
  notFound,

  /// Deleted, already extracting, already reviewed or saved. Includes the
  /// loser of a concurrent claim and a record deleted mid-flight.
  notExtractable,

  /// The database could not be read or written.
  storageUnavailable,
}

sealed class ExtractionOutcome {
  const ExtractionOutcome();
}

final class ExtractionSucceeded extends ExtractionOutcome {
  const ExtractionSucceeded(this.record);

  /// The record, now in `needsReview`.
  final InvoiceRecord record;
}

/// [kind] may be [InvoiceErrorKind.cancelled]. [record] is `failed`.
/// [debugCode] is not persisted; after a restart only the kind remains.
final class ExtractionFailed extends ExtractionOutcome {
  const ExtractionFailed(this.record, this.kind, {this.debugCode});

  final InvoiceRecord record;
  final InvoiceErrorKind kind;
  final String? debugCode;
}

final class ExtractionSkipped extends ExtractionOutcome {
  const ExtractionSkipped(this.reason);

  final ExtractionSkipReason reason;
}

/// Claims a record, runs extraction, and persists the result.
///
/// - pendingExtraction or failed -> extracting is one atomic `mutate`, so
///   only one caller can extract a given record.
/// - Network failures stay `failed(network)`. The offline worker resumes
///   records whose kind `parksInOfflineQueue`; it must not resume others.
/// - A cancelled run becomes `failed(cancelled)`, so it is never auto-resumed.
/// - If the final write fails, the record stays `extracting` until launch
///   recovery resets it; the model result is lost.
class ExtractInvoice {
  ExtractInvoice({
    required InvoiceRepository repository,
    required InvoiceExtractor extractor,
    required ImageStore imageStore,
    required ScanAnalytics analytics,
    required Clock clock,
  }) : _repository = repository,
       _extractor = extractor,
       _imageStore = imageStore,
       _analytics = analytics,
       _clock = clock;

  final InvoiceRepository _repository;
  final InvoiceExtractor _extractor;
  final ImageStore _imageStore;
  final ScanAnalytics _analytics;
  final Clock _clock;

  Future<ExtractionOutcome> call({
    required String recordId,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    InvoiceRecord? claimed;
    try {
      claimed = await _repository.mutate(
        recordId,
        (InvoiceRecord current) => current.markExtracting(_clock()),
      );
    } on StateError {
      return const ExtractionSkipped(ExtractionSkipReason.notExtractable);
    } on Exception {
      return const ExtractionSkipped(ExtractionSkipReason.storageUnavailable);
    }
    if (claimed == null) {
      return const ExtractionSkipped(ExtractionSkipReason.notFound);
    }

    Invoice? extracted;
    InvoiceFailure? failure;
    try {
      cancel.throwIfCancelled();
      if (!await _imageStore.allExist(claimed.imagePaths)) {
        throw const InvoiceFailure(
          InvoiceErrorKind.unknown,
          debugCode: DebugCodes.imagesMissing,
        );
      }
      // race() stops waiting on cancel even if the extractor ignores the
      // token, and swallows late results from the abandoned call.
      extracted = await cancel.race(
        _extractor.extract(
          imagePaths: claimed.imagePaths,
          fallbackCurrency: fallbackCurrency,
          cancel: cancel,
        ),
      );
    } on Exception catch (error) {
      failure = mapToFailure(error);
    }

    final Invoice? result = extracted;
    final InvoiceFailure? problem = failure;
    final InvoiceErrorKind kind = problem?.kind ?? InvoiceErrorKind.unknown;

    InvoiceRecord? updated;
    try {
      updated = await _repository.mutate(recordId, (InvoiceRecord current) {
        if (result != null) return current.markNeedsReview(result, _clock());
        return current.markFailed(kind, _clock());
      });
    } on StateError {
      // Deleted (or otherwise changed) while the model call was running.
      return const ExtractionSkipped(ExtractionSkipReason.notExtractable);
    } on Exception {
      return const ExtractionSkipped(ExtractionSkipReason.storageUnavailable);
    }
    if (updated == null) {
      return const ExtractionSkipped(ExtractionSkipReason.notFound);
    }

    if (result != null || kind != InvoiceErrorKind.cancelled) {
      final Duration elapsed = _clock().difference(updated.createdAt);
      _analytics.extractionFinished(
        captureToResult: elapsed.isNegative ? Duration.zero : elapsed,
        attempt: updated.attemptCount,
        errorKind: result != null ? null : kind,
      );
    }

    if (result != null) return ExtractionSucceeded(updated);
    return ExtractionFailed(updated, kind, debugCode: problem?.debugCode);
  }
}
