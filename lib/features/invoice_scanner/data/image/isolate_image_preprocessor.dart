import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/image/compress_page.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_preprocessor.dart';

/// Compresses pages one at a time, each in its own short-lived isolate, so
/// cancellation can take effect between pages and the UI isolate never
/// decodes an image.
class IsolateImagePreprocessor implements ImagePreprocessor {
  IsolateImagePreprocessor({
    required this.outputDir,
    this.maxLongEdge = 1600,
    this.jpegQuality = 80,
    this.maxSourceBytes = defaultMaxSourceBytes,
  });

  static const int defaultMaxSourceBytes = 40 * 1024 * 1024;
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// App-private directory that holds only compressed invoice images.
  final Directory outputDir;
  final int maxLongEdge;
  final int jpegQuality;
  final int maxSourceBytes;

  @override
  Future<List<String>> compress({
    required String invoiceId,
    required List<String> sourcePaths,
    required CancellationToken cancel,
  }) async {
    // The id becomes part of a file name, so it must be a plain token.
    if (!_safeId.hasMatch(invoiceId) || sourcePaths.isEmpty) {
      throw const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: DebugCodes.ioFailed,
      );
    }
    try {
      outputDir.createSync(recursive: true);
    } on FileSystemException {
      throw const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: DebugCodes.ioFailed,
      );
    }

    // Copied to locals: the isolate closure must not capture `this`.
    final String dir = outputDir.path;
    final int edge = maxLongEdge;
    final int quality = jpegQuality;
    final int maxBytes = maxSourceBytes;

    final List<String> outputs = <String>[];
    try {
      for (int i = 0; i < sourcePaths.length; i++) {
        cancel.throwIfCancelled();

        final String source = sourcePaths[i];
        final String output =
            '$dir${Platform.pathSeparator}${invoiceId}_$i.jpg';
        final Future<(String?, String?)> work = Isolate.run(
          () => compressPageFile(
            sourcePath: source,
            outputPath: output,
            maxLongEdge: edge,
            quality: quality,
            maxSourceBytes: maxBytes,
          ),
        );

        final (String?, String?) result;
        try {
          result = await cancel.race(work);
        } on CancelledException {
          // The isolate cannot be stopped; delete its page if it finishes.
          unawaited(
            work.then<void>(((String?, String?) r) {
              final String? written = r.$1;
              if (written != null) _deleteQuietly(written);
            }, onError: (Object _) {}),
          );
          rethrow;
        } on Exception {
          // The isolate itself failed (for example it was killed).
          throw const InvoiceFailure(
            InvoiceErrorKind.unknown,
            debugCode: DebugCodes.decodeFailed,
          );
        }

        final String? written = result.$1;
        if (written == null) {
          throw InvoiceFailure(
            InvoiceErrorKind.unknown,
            debugCode: result.$2 ?? DebugCodes.decodeFailed,
          );
        }
        outputs.add(written);
      }
      return List<String>.unmodifiable(outputs);
    } on Object {
      for (final String path in outputs) {
        _deleteQuietly(path);
      }
      rethrow;
    }
  }

  static void _deleteQuietly(String path) {
    try {
      final File file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Best effort; the launch sweep removes leftovers.
    }
  }
}
