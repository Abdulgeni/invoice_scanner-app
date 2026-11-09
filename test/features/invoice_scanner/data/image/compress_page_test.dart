import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:invoice_scanner/features/invoice_scanner/data/image/compress_page.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';

import '../../../../support/image_fixtures.dart';

img.Image decode(Uint8List jpeg) => img.decodeJpg(jpeg)!;

void main() {
  group('orientation', () {
    for (final int orientation in <int>[1, 3, 6, 8]) {
      test('EXIF orientation $orientation comes out upright', () {
        final img.Image upright = uprightQuadrants(300, 200);
        final Uint8List source = jpegWithOrientation(
          storedFor(orientation, upright),
          orientation,
        );

        expect(storedOrientation(source), orientation);

        final img.Image out = decode(compressPageBytes(source));
        expect(out.width, 300);
        expect(out.height, 200);
        expect(quadrantsOf(out), 'RGBY');
      });
    }
  });

  test('output carries no orientation tag or other EXIF', () {
    final Uint8List source = jpegWithOrientation(
      storedFor(6, uprightQuadrants(300, 200)),
      6,
    );
    expect(storedOrientation(source), 6);
    expect(storedOrientation(compressPageBytes(source)), isNull);
  });

  group('size', () {
    test('downscales a landscape image to a 1600px long edge', () {
      final img.Image out = decode(compressPageBytes(flatJpeg(3200, 1600)));
      expect(out.width, 1600);
      expect(out.height, 800);
    });

    test('downscales a portrait image to a 1600px long edge', () {
      final img.Image out = decode(compressPageBytes(flatJpeg(1000, 3000)));
      expect(out.height, 1600);
      expect(out.width, closeTo(533, 1));
    });

    test('never upscales', () {
      final img.Image out = decode(compressPageBytes(flatJpeg(800, 600)));
      expect(out.width, 800);
      expect(out.height, 600);
    });

    test('an image exactly at the limit is unchanged in size', () {
      final img.Image out = decode(compressPageBytes(flatJpeg(1600, 900)));
      expect(out.width, 1600);
      expect(out.height, 900);
    });

    test('the limit is configurable', () {
      final img.Image out = decode(
        compressPageBytes(flatJpeg(400, 200), maxLongEdge: 100),
      );
      expect(out.width, 100);
      expect(out.height, 50);
    });

    test('a rotated image is resized after rotation', () {
      final Uint8List source = jpegWithOrientation(
        storedFor(6, uprightQuadrants(2000, 1000)),
        6,
      );
      final img.Image out = decode(compressPageBytes(source));
      expect(out.width, 1600);
      expect(out.height, 800);
      expect(quadrantsOf(out), 'RGBY');
    });
  });

  test('PNG input (the iOS default) becomes a JPEG', () {
    final Uint8List png = Uint8List.fromList(
      img.encodePng(uprightQuadrants(300, 200)),
    );
    final Uint8List out = compressPageBytes(png);
    expect(out[0], 0xFF);
    expect(out[1], 0xD8);
    expect(quadrantsOf(decode(out)), 'RGBY');
  });

  test('corrupt or empty input fails with decode_failed', () {
    for (final Uint8List bad in <Uint8List>[
      Uint8List.fromList(List<int>.filled(100, 7)),
      Uint8List(0),
      Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 1]),
    ]) {
      expect(
        () => compressPageBytes(bad),
        throwsA(
          isA<PageCompressionException>().having(
            (PageCompressionException e) => e.debugCode,
            'debugCode',
            DebugCodes.decodeFailed,
          ),
        ),
      );
    }
  });
}
