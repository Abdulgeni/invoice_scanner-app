import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_store.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';

enum DeleteOutcome { deleted, notFound, storageUnavailable }

/// Turns the row into a tombstone (payload erased) and deletes its images.
/// Works in any status, including mid-extraction: the caller should cancel
/// that extraction's token, and the in-flight `ExtractInvoice` then skips
/// itself. Idempotent.
class DeleteInvoice {
  DeleteInvoice({
    required InvoiceRepository repository,
    required ImageStore imageStore,
    required Clock clock,
  }) : _repository = repository,
       _imageStore = imageStore,
       _clock = clock;

  final InvoiceRepository _repository;
  final ImageStore _imageStore;
  final Clock _clock;

  Future<DeleteOutcome> call(String recordId) async {
    List<String> paths = const <String>[];
    InvoiceRecord? result;
    try {
      result = await _repository.mutate(recordId, (InvoiceRecord current) {
        final InvoiceRecord next = current.markDeleted(_clock());
        paths = current.imagePaths;
        return next;
      });
    } on Exception {
      return DeleteOutcome.storageUnavailable;
    }
    if (result == null) return DeleteOutcome.notFound;

    await _imageStore.deleteFiles(paths);
    return DeleteOutcome.deleted;
  }
}
