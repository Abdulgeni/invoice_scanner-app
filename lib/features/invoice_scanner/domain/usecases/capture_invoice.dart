import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/failure_mapper.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/invoice_limits.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_preprocessor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_store.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';

sealed class CaptureResult {
  const CaptureResult();
}

final class CaptureSucceeded extends CaptureResult {
  const CaptureSucceeded(this.record);

  /// New record in `pendingExtraction`, images already compressed.
  final InvoiceRecord record;
}

/// The user backed out, or the operation was cancelled. Not an error.
final class CaptureCancelled extends CaptureResult {
  const CaptureCancelled();
}

/// More pages than allowed. Nothing was processed or stored.
final class CaptureTooManyPages extends CaptureResult {
  const CaptureTooManyPages(this.maxPages);

  final int maxPages;
}

final class CaptureFailed extends CaptureResult {
  const CaptureFailed(this.failure);

  final InvoiceFailure failure;
}

/// scan -> page cap -> compress -> persist as `pendingExtraction`.
class CaptureInvoice {
  CaptureInvoice({
    required DocumentScanner scanner,
    required ImagePreprocessor preprocessor,
    required InvoiceRepository repository,
    required ImageStore imageStore,
    required Clock clock,
    required IdGenerator newId,
    int maxPages = InvoiceLimits.maxPages,
  }) : _scanner = scanner,
       _preprocessor = preprocessor,
       _repository = repository,
       _imageStore = imageStore,
       _clock = clock,
       _newId = newId,
       _maxPages = maxPages;

  final DocumentScanner _scanner;
  final ImagePreprocessor _preprocessor;
  final InvoiceRepository _repository;
  final ImageStore _imageStore;
  final Clock _clock;
  final IdGenerator _newId;
  final int _maxPages;

  Future<CaptureResult> call({
    required ScanSource source,
    required CancellationToken cancel,

    /// Called once the scanner's pages are accepted (not too many, not
    /// cancelled), just before compression starts. Lets the UI move from
    /// "scanner open" to "optimizing".
    void Function(List<String> pages)? onPagesAccepted,
  }) async {
    List<String> compressed = const <String>[];
    try {
      cancel.throwIfCancelled();

      final List<String>? pages = await _scanner.scan(
        source: source,
        maxPages: _maxPages + 1,
      );
      if (pages == null || pages.isEmpty) return const CaptureCancelled();
      if (pages.length > _maxPages) {
        await _imageStore.deleteFiles(pages);
        return CaptureTooManyPages(_maxPages);
      }
      cancel.throwIfCancelled();
      onPagesAccepted?.call(pages);

      final String id = _newId();
      compressed = await _preprocessor.compress(
        invoiceId: id,
        sourcePaths: pages,
        cancel: cancel,
      );
      cancel.throwIfCancelled();

      final InvoiceRecord record = InvoiceRecord.queued(
        id: id,
        imagePaths: compressed,
        now: _clock(),
      );
      final bool inserted = await _repository.insertIfAbsent(record);
      if (!inserted) {
        return const CaptureFailed(
          InvoiceFailure(
            InvoiceErrorKind.unknown,
            debugCode: DebugCodes.duplicateId,
          ),
        );
      }
      await _imageStore.deleteFiles(pages);
      return CaptureSucceeded(record);
    } on Exception catch (error) {
      if (compressed.isNotEmpty) await _imageStore.deleteFiles(compressed);
      final InvoiceFailure failure = mapToFailure(error);
      if (failure.kind == InvoiceErrorKind.cancelled) {
        return const CaptureCancelled();
      }
      return CaptureFailed(failure);
    }
  }
}
