enum ScanSource { camera, gallery }

/// Capture layer. Knows nothing about extraction.
abstract interface class DocumentScanner {
  /// Opens the native scanner and returns page image paths in page order,
  /// or null if the user cancelled or produced no pages (never an empty
  /// list).
  ///
  /// Asks the platform for at most [maxPages], but some platforms ignore
  /// the limit and may return more; callers must check the count.
  ///
  /// Throws `InvoiceFailure(unknown, debugCode: ...)` when the scanner
  /// cannot run (for example `camera_permission_denied`,
  /// `scanner_unavailable`).
  Future<List<String>?> scan({
    required ScanSource source,
    required int maxPages,
  });
}
