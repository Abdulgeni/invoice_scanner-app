/// Field names shared by the schema and the parser, so they cannot drift.
abstract final class ExtractionFields {
  static const String isInvoiceOrReceipt = 'isInvoiceOrReceipt';
  static const String vendorName = 'vendorName';
  static const String invoiceNumber = 'invoiceNumber';
  static const String invoiceDate = 'invoiceDate';
  static const String currency = 'currency';
  static const String lineItems = 'lineItems';
  static const String description = 'description';
  static const String quantity = 'quantity';
  static const String unitPrice = 'unitPrice';
  static const String lineTotal = 'lineTotal';
  static const String subtotal = 'subtotal';
  static const String tax = 'tax';
  static const String total = 'total';
}

abstract final class ExtractionLimits {
  /// Also the schema's `maxItems`. Rows beyond it are dropped and flagged.
  static const int maxLineItems = 200;
}
