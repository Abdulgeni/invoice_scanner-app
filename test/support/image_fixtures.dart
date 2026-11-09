import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Upright image: top-left red, top-right green, bottom-left blue,
/// bottom-right yellow.
img.Image uprightQuadrants(int w, int h) {
  final img.Image image = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final bool left = x < w ~/ 2;
      final bool top = y < h ~/ 2;
      if (top && left) {
        image.setPixelRgb(x, y, 255, 0, 0);
      } else if (top) {
        image.setPixelRgb(x, y, 0, 255, 0);
      } else if (left) {
        image.setPixelRgb(x, y, 0, 0, 255);
      } else {
        image.setPixelRgb(x, y, 255, 255, 0);
      }
    }
  }
  return image;
}

/// The pixels a camera would store so that EXIF [orientation] (1, 3, 6 or 8)
/// displays [upright]: 6 means "rotate 90 degrees clockwise to display",
/// 8 means "rotate 90 degrees counter-clockwise".
img.Image storedFor(int orientation, img.Image upright) {
  final int w = upright.width;
  final int h = upright.height;
  final bool swapped = orientation == 6 || orientation == 8;
  final img.Image stored = img.Image(
    width: swapped ? h : w,
    height: swapped ? w : h,
  );
  for (int ys = 0; ys < stored.height; ys++) {
    for (int xs = 0; xs < stored.width; xs++) {
      final (int, int) src = switch (orientation) {
        3 => (w - 1 - xs, h - 1 - ys),
        6 => (w - 1 - ys, xs),
        8 => (ys, h - 1 - xs),
        _ => (xs, ys),
      };
      final img.Pixel p = upright.getPixel(src.$1, src.$2);
      stored.setPixelRgb(xs, ys, p.r, p.g, p.b);
    }
  }
  return stored;
}

Uint8List jpegWithOrientation(img.Image stored, int orientation) {
  stored.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(stored, quality: 95));
}

/// The EXIF orientation stored in [jpeg], or null when there is none.
int? storedOrientation(Uint8List jpeg) =>
    img.decodeJpgExif(jpeg)?.imageIfd.orientation;

Uint8List flatJpeg(int w, int h) {
  final img.Image image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 100, 50));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

String _classify(img.Pixel p) {
  final num r = p.r;
  final num g = p.g;
  final num b = p.b;
  if (r > 150 && g < 100 && b < 100) return 'R';
  if (g > 150 && r < 100 && b < 100) return 'G';
  if (b > 150 && r < 100 && g < 100) return 'B';
  if (r > 150 && g > 150 && b < 100) return 'Y';
  return '?';
}

/// Colors at the centers of the TL, TR, BL, BR quadrants, for example
/// "RGBY" for an upright [uprightQuadrants] image.
String quadrantsOf(img.Image image) {
  final int w = image.width;
  final int h = image.height;
  return <(int, int)>[
    (w ~/ 4, h ~/ 4),
    (3 * w ~/ 4, h ~/ 4),
    (w ~/ 4, 3 * h ~/ 4),
    (3 * w ~/ 4, 3 * h ~/ 4),
  ].map(((int, int) p) => _classify(image.getPixel(p.$1, p.$2))).join();
}
