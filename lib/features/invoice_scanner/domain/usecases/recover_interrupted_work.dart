import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_store.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';

/// Launch housekeeping. Must finish before any capture or extraction starts:
/// the orphan sweep would otherwise delete the images of a capture that is
/// still being written.
///
/// 1. Records stuck in `extracting` (the app died mid-call) go back to
///    `pendingExtraction`.
/// 2. Compressed images not referenced by any live, unsaved record are
///    deleted (crash leftovers).
/// 3. The scanner plugin's temp files are cleaned.
///
/// Returns how many records were reset. Throws if storage is unavailable;
/// callers should catch it and continue launching.
class RecoverInterruptedWork {
  RecoverInterruptedWork({
    required InvoiceRepository repository,
    required ImageStore imageStore,
    required Clock clock,
  }) : _repository = repository,
       _imageStore = imageStore,
       _clock = clock;

  final InvoiceRepository _repository;
  final ImageStore _imageStore;
  final Clock _clock;

  static const Set<InvoiceStatus> _unsaved = <InvoiceStatus>{
    InvoiceStatus.pendingExtraction,
    InvoiceStatus.extracting,
    InvoiceStatus.needsReview,
    InvoiceStatus.failed,
  };

  Future<int> call() async {
    final List<InvoiceRecord> stale = await _repository.listByStatus(
      const <InvoiceStatus>{InvoiceStatus.extracting},
    );

    int reset = 0;
    for (final InvoiceRecord record in stale) {
      bool didReset = false;
      try {
        await _repository.mutate(record.id, (InvoiceRecord current) {
          if (current.isDeleted || current.status != InvoiceStatus.extracting) {
            return current;
          }
          didReset = true;
          return current.markPending(_clock());
        });
      } on StateError {
        continue;
      }
      if (didReset) reset++;
    }

    final List<InvoiceRecord> live = await _repository.listByStatus(_unsaved);
    final Set<String> keep = <String>{
      for (final InvoiceRecord record in live) ...record.imagePaths,
    };
    await _imageStore.deleteManagedFilesExcept(keep);
    await _imageStore.cleanScannerTemp();

    return reset;
  }
}
