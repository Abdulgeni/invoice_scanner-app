import 'package:invoice_scanner/core/async/cancellation_token.dart';

/// Compresses captured pages for upload. Runs off the UI isolate.
abstract interface class ImagePreprocessor {
  /// Writes one compressed JPEG per source page into app-private storage
  /// and returns their paths in the same order and count as [sourcePaths].
  ///
  /// Output is orientation-correct (EXIF baked in), never upscaled, and
  /// carries no metadata. File names derive from [invoiceId] and the page
  /// index, so a repeat run overwrites instead of leaking files.
  ///
  /// Throws `InvoiceFailure(unknown, debugCode: 'decode_failed')` (or
  /// 'io_failed') if any page cannot be processed, and throws
  /// `CancelledException` if [cancel] fires. In both cases it deletes any
  /// partial outputs before throwing. It never returns the original
  /// bytes in place of a failed compression.
  Future<List<String>> compress({
    required String invoiceId,
    required List<String> sourcePaths,
    required CancellationToken cancel,
  });
}
