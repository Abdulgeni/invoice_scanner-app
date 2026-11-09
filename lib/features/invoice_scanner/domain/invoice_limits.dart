abstract final class InvoiceLimits {
  /// Hard cap on pages per invoice. `CaptureInvoice` rejects above this,
  /// never truncates.
  static const int maxPages = 5;
}
