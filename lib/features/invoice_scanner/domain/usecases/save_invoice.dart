import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/analytics/scan_analytics.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_diff.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_store.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';

enum SaveBlockReason {
  notFound,

  /// Not in review: already saved, deleted, or never extracted.
  notInReview,
  storageUnavailable,
}

sealed class SaveOutcome {
  const SaveOutcome();
}

final class SaveSucceeded extends SaveOutcome {
  const SaveSucceeded(this.record);

  final InvoiceRecord record;
}

final class SaveBlocked extends SaveOutcome {
  const SaveBlocked(this.reason);

  final SaveBlockReason reason;
}

/// Commits the user's confirmed invoice. Deliberately does not validate:
/// warnings are advice, and the user has the final say.
///
/// Order: commit the row first, then delete the images and scanner temp
/// files, then emit analytics. A crash between commit and delete leaves
/// orphans that launch recovery sweeps.
class SaveInvoice {
  SaveInvoice({
    required InvoiceRepository repository,
    required ImageStore imageStore,
    required ScanAnalytics analytics,
    required Clock clock,
  }) : _repository = repository,
       _imageStore = imageStore,
       _analytics = analytics,
       _clock = clock;

  final InvoiceRepository _repository;
  final ImageStore _imageStore;
  final ScanAnalytics _analytics;
  final Clock _clock;

  Future<SaveOutcome> call({
    required String recordId,
    required Invoice confirmed,
  }) async {
    List<String> paths = const <String>[];
    Invoice? original;
    InvoiceRecord? saved;
    try {
      saved = await _repository.mutate(recordId, (InvoiceRecord current) {
        final InvoiceRecord next = current.markSaved(confirmed, _clock());
        paths = current.imagePaths;
        original = current.extractedInvoice;
        return next;
      });
    } on StateError {
      return const SaveBlocked(SaveBlockReason.notInReview);
    } on Exception {
      return const SaveBlocked(SaveBlockReason.storageUnavailable);
    }
    if (saved == null) return const SaveBlocked(SaveBlockReason.notFound);

    await _imageStore.deleteFiles(paths);
    await _imageStore.cleanScannerTemp();

    final Invoice? before = original;
    final Set<InvoiceField> corrected = before == null
        ? const <InvoiceField>{}
        : changedInvoiceFields(before, confirmed);
    corrected.forEach(_analytics.fieldCorrected);
    _analytics.invoiceSaved(correctedFieldCount: corrected.length);

    return SaveSucceeded(saved);
  }
}
