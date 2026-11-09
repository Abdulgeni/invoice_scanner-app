/// Short technical codes carried in `InvoiceFailure.debugCode`. The UI may
/// branch on these (for example, to offer "enable camera"), so treat them as
/// a contract. They never contain invoice content.
abstract final class DebugCodes {
  static const String cameraPermissionDenied = 'camera_permission_denied';
  static const String scannerUnavailable = 'scanner_unavailable';
  static const String decodeFailed = 'decode_failed';
  static const String ioFailed = 'io_failed';
  static const String imagesMissing = 'images_missing';
  static const String duplicateId = 'duplicate_id';
  static const String unexpected = 'unexpected';
}
