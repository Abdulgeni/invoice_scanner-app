import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';

/// Internal failure of one page. [debugCode] is a [DebugCodes] value.
final class PageCompressionException implements Exception {
  const PageCompressionException(this.debugCode);

  final String debugCode;

  @override
  String toString() => 'PageCompressionException($debugCode)';
}

/// Decodes [source] (JPEG or PNG), bakes in EXIF orientation, downscales so
/// the long edge is at most [maxLongEdge] (never upscales), drops all
/// metadata, and re-encodes as JPEG.
///
/// Orientation is baked in BEFORE resizing and the tag is cleared, so a
/// library that also applies orientation while resizing has nothing left
/// to apply. Throws [PageCompressionException] on any failure.
Uint8List compressPageBytes(
  Uint8List source, {
  int maxLongEdge = 1600,
  int quality = 80,
}) {
  try {
    final img.Image? decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const PageCompressionException(DebugCodes.decodeFailed);
    }

    img.Image image = img.bakeOrientation(decoded);
    if (math.max(image.width, image.height) > maxLongEdge) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxLongEdge : null,
        height: image.height > image.width ? maxLongEdge : null,
        interpolation: img.Interpolation.average,
      );
    }

    image.exif = img.ExifData();
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  } on PageCompressionException {
    rethrow;
  } catch (_) {
    // Corrupt input often surfaces as RangeError or StateError, which are
    // not Exceptions; this is the untrusted-input boundary.
    throw const PageCompressionException(DebugCodes.decodeFailed);
  }
}

/// File wrapper that runs inside the worker isolate. Returns
/// `(outputPath, null)` on success or `(null, debugCode)` on failure; plain
/// records cross the isolate boundary safely.
///
/// Writes `<outputPath>.tmp` then renames, so a crash never leaves a
/// truncated file under the final name. A source above [maxSourceBytes]
/// fails as `decode_failed` before it is read into memory.
(String?, String?) compressPageFile({
  required String sourcePath,
  required String outputPath,
  required int maxLongEdge,
  required int quality,
  required int maxSourceBytes,
}) {
  final Uint8List bytes;
  try {
    final File source = File(sourcePath);
    if (source.lengthSync() > maxSourceBytes) {
      return (null, DebugCodes.decodeFailed);
    }
    bytes = source.readAsBytesSync();
  } on FileSystemException {
    return (null, DebugCodes.ioFailed);
  }

  final Uint8List jpeg;
  try {
    jpeg = compressPageBytes(bytes, maxLongEdge: maxLongEdge, quality: quality);
  } on PageCompressionException catch (e) {
    return (null, e.debugCode);
  }

  final File tmp = File('$outputPath.tmp');
  try {
    tmp.writeAsBytesSync(jpeg, flush: true);
    tmp.renameSync(outputPath);
  } on FileSystemException {
    try {
      if (tmp.existsSync()) tmp.deleteSync();
    } on FileSystemException {
      // Best effort; the launch sweep removes leftovers.
    }
    return (null, DebugCodes.ioFailed);
  }
  return (outputPath, null);
}
