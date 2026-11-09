import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/datasources/document_scanner_datasource.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';

void main() {
  group('mapScannerErrorCode', () {
    test('documented native codes mean the scanner is unavailable', () {
      for (final String code in <String>[
        'NO_ACTIVITY',
        'ALREADY_ACTIVE',
        'UNAVAILABLE',
        'SOMETHING_NEW',
        '',
      ]) {
        expect(
          mapScannerErrorCode(code),
          DebugCodes.scannerUnavailable,
          reason: code,
        );
      }
    });

    test('anything mentioning permission or denial is a denial', () {
      for (final String code in <String>[
        'CAMERA_PERMISSION_DENIED',
        'permission',
        'Denied',
      ]) {
        expect(
          mapScannerErrorCode(code),
          DebugCodes.cameraPermissionDenied,
          reason: code,
        );
      }
    });
  });

  group('CunningDocumentScannerDatasource', () {
    test('passes the page limit and source through', () async {
      int? seenPages;
      ScanSource? seenSource;
      final CunningDocumentScannerDatasource scanner =
          CunningDocumentScannerDatasource(
            getPictures:
                ({required int noOfPages, required ScanSource source}) async {
                  seenPages = noOfPages;
                  seenSource = source;
                  return <String>['a.jpg', 'b.jpg'];
                },
          );
      final List<String>? result = await scanner.scan(
        source: ScanSource.gallery,
        maxPages: 6,
      );
      expect(result, <String>['a.jpg', 'b.jpg']);
      expect(seenPages, 6);
      expect(seenSource, ScanSource.gallery);
    });

    test('null and empty results both mean cancelled', () async {
      for (final List<String>? value in <List<String>?>[null, <String>[]]) {
        final CunningDocumentScannerDatasource scanner =
            CunningDocumentScannerDatasource(
              getPictures:
                  ({
                    required int noOfPages,
                    required ScanSource source,
                  }) async => value,
            );
        expect(
          await scanner.scan(source: ScanSource.camera, maxPages: 6),
          isNull,
        );
      }
    });

    test('platform errors become typed failures with a debug code', () async {
      final CunningDocumentScannerDatasource scanner =
          CunningDocumentScannerDatasource(
            getPictures:
                ({required int noOfPages, required ScanSource source}) async =>
                    throw const ScannerPlatformError(
                      'CAMERA_PERMISSION_DENIED',
                    ),
          );
      await expectLater(
        scanner.scan(source: ScanSource.camera, maxPages: 6),
        throwsA(
          const InvoiceFailure(
            InvoiceErrorKind.unknown,
            debugCode: DebugCodes.cameraPermissionDenied,
          ),
        ),
      );
    });
  });
}
