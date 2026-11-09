import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';

/// Autosaves review edits so they survive backgrounding or process death.
/// Returns true when persisted; false when the record is missing, not in
/// review, or storage failed. Callers may retry on the next edit.
class UpdateReviewDraft {
  UpdateReviewDraft({
    required InvoiceRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final InvoiceRepository _repository;
  final Clock _clock;

  Future<bool> call({
    required String recordId,
    required Invoice invoice,
  }) async {
    try {
      final updated = await _repository.mutate(
        recordId,
        (current) => current.withEditedInvoice(invoice, _clock()),
      );
      return updated != null;
    } on StateError {
      return false;
    } on Exception {
      return false;
    }
  }
}
