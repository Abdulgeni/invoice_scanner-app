import 'package:cunning_document_scanner/cunning_document_scanner.dart' as cds;

import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';

/// Our own error type so tests (and the rest of the datasource) never touch
/// the plugin's exception class.
final class ScannerPlatformError implements Exception {
  const ScannerPlatformError(this.code);

  final String code;

  @override
  String toString() => 'ScannerPlatformError($code)';
}

/// The one call into the plugin. Replaceable in tests.
typedef GetPictures =
    Future<List<String>?> Function({
      required int noOfPages,
      required ScanSource source,
    });

/// Maps a native error code to a [DebugCodes] value.
///
/// The plugin documents the codes ALREADY_ACTIVE, NO_ACTIVITY and
/// UNAVAILABLE, but not the one used for a denied camera permission, so
/// anything that mentions permission or denial is treated as a denial and
/// every other code as "scanner unavailable".
String mapScannerErrorCode(String code) {
  final String c = code.toUpperCase();
  if (c.contains('PERMISSION') || c.contains('DENIED')) {
    return DebugCodes.cameraPermissionDenied;
  }
  return DebugCodes.scannerUnavailable;
}

Future<List<String>?> _pluginGetPictures({
  required int noOfPages,
  required ScanSource source,
}) async {
  try {
    return await cds.CunningDocumentScanner.getPictures(
      noOfPages: noOfPages,
      scannerSource: source == ScanSource.gallery
          ? cds.ScannerSource.gallery
          : cds.ScannerSource.camera,
      // iOS returns PNG by default; JPEG keeps files small.
      iosScannerOptions: cds.IosScannerOptions(
        imageFormat: cds.IosImageFormat.jpg,
        jpgCompressionQuality: 0.9,
      ),
    );
  } on cds.CunningDocumentScannerException catch (e) {
    throw ScannerPlatformError('${e.code}');
  }
}

/// Capture layer over `cunning_document_scanner`. Knows nothing about
/// extraction.
class CunningDocumentScannerDatasource implements DocumentScanner {
  CunningDocumentScannerDatasource({GetPictures? getPictures})
    : _getPictures = getPictures ?? _pluginGetPictures;

  final GetPictures _getPictures;

  @override
  Future<List<String>?> scan({
    required ScanSource source,
    required int maxPages,
  }) async {
    try {
      final List<String>? pages = await _getPictures(
        noOfPages: maxPages,
        source: source,
      );
      if (pages == null || pages.isEmpty) return null;
      return List<String>.unmodifiable(pages);
    } on ScannerPlatformError catch (e) {
      throw InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: mapScannerErrorCode(e.code),
      );
    }
  }
}
