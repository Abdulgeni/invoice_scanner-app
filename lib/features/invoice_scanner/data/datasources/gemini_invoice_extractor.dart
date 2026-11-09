import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/extraction_mapper.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/gemini_debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/gemini_error_classifier.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/model_invoker.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/model_name_resolver.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/invoice_limits.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

/// Extraction layer: reads the page files, calls the model with a per-attempt
/// timeout, retries transient failures with exponential backoff, falls back
/// across model names, and maps every outcome to the failure taxonomy.
///
/// Every error thrown from here is an [InvoiceFailure] or a
/// [CancelledException]. Nothing here logs or embeds invoice content.
class GeminiInvoiceExtractor implements InvoiceExtractor {
  GeminiInvoiceExtractor({
    required ModelInvoker invoker,
    required ModelNameResolver models,
    required IdGenerator newLineId,
    Future<Uint8List> Function(String path)? readFile,
    Future<void> Function(Duration)? sleep,
    this.attemptTimeout = const Duration(seconds: 45),
    this.maxRetries = 2,
    this.baseBackoff = const Duration(seconds: 1),
    this.maxPages = InvoiceLimits.maxPages,
  }) : _invoker = invoker,
       _models = models,
       _newLineId = newLineId,
       _readFile = readFile ?? _readFromDisk,
       _sleep = sleep ?? Future<void>.delayed;

  final ModelInvoker _invoker;
  final ModelNameResolver _models;
  final IdGenerator _newLineId;
  final Future<Uint8List> Function(String path) _readFile;
  final Future<void> Function(Duration) _sleep;

  /// Limit for one model call. A timed-out request may still finish and be
  /// billed on the server.
  final Duration attemptTimeout;

  /// Extra attempts after the first, for transient failures only.
  final int maxRetries;
  final Duration baseBackoff;
  final int maxPages;

  static Future<Uint8List> _readFromDisk(String path) =>
      File(path).readAsBytes();

  /// Finish reasons (enum names) that mean the content was blocked.
  static const Set<String> _blockedFinishReasons = <String>{
    'safety',
    'recitation',
    'blocklist',
    'prohibitedContent',
    'spii',
    'imageSafety',
    'imageProhibitedContent',
    'imageRecitation',
  };

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    if (imagePaths.isEmpty || imagePaths.length > maxPages) {
      throw const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: GeminiDebugCodes.badPageCount,
      );
    }
    cancel.throwIfCancelled();
    final List<Uint8List> pages = await cancel.race(_readPages(imagePaths));

    int retries = 0;
    while (true) {
      cancel.throwIfCancelled();
      try {
        return await _attempt(pages, fallbackCurrency, cancel);
      } on CancelledException {
        rethrow;
      } on InvoiceFailure catch (failure) {
        if (!failure.kind.isTransient || retries >= maxRetries) rethrow;
        retries++;
        await cancel.race(_sleep(baseBackoff * (1 << (retries - 1))));
      }
    }
  }

  Future<List<Uint8List>> _readPages(List<String> paths) async {
    final List<Uint8List> pages = <Uint8List>[];
    for (final String path in paths) {
      try {
        final Uint8List bytes = await _readFile(path);
        if (bytes.isEmpty) {
          throw const InvoiceFailure(
            InvoiceErrorKind.unknown,
            debugCode: GeminiDebugCodes.pageEmpty,
          );
        }
        pages.add(bytes);
      } on FileSystemException {
        throw const InvoiceFailure(
          InvoiceErrorKind.unknown,
          debugCode: DebugCodes.ioFailed,
        );
      }
    }
    return pages;
  }

  /// One pass over the model-name candidates. Only a "model not found" error
  /// moves on to the next candidate; every other failure stops here.
  Future<Invoice> _attempt(
    List<Uint8List> pages,
    Currency fallbackCurrency,
    CancellationToken cancel,
  ) async {
    InvoiceFailure? lastModelFailure;
    for (final String name in _models.candidates()) {
      cancel.throwIfCancelled();

      final GeminiRawResult raw;
      try {
        // The try covers only the third-party call. The SDK can throw Errors
        // as well as Exceptions on malformed responses, so this boundary
        // catches Object; our own logic below is outside it.
        raw = await cancel.race(
          _invoker(modelName: name, jpegPages: pages).timeout(attemptTimeout),
        );
      } on CancelledException {
        rethrow;
      } on Object catch (error) {
        final ClassifiedError classified = classifyGeminiError(error);
        if (classified.modelNotFound) {
          _models.markUnavailable(name);
          lastModelFailure = const InvoiceFailure(
            InvoiceErrorKind.unknown,
            debugCode: GeminiDebugCodes.modelUnavailable,
          );
          continue;
        }
        throw InvoiceFailure(classified.kind, debugCode: classified.debugCode);
      }

      _models.markGood(name);
      return _interpret(raw, fallbackCurrency);
    }
    throw lastModelFailure ??
        const InvoiceFailure(
          InvoiceErrorKind.unknown,
          debugCode: GeminiDebugCodes.modelUnavailable,
        );
  }

  Invoice _interpret(GeminiRawResult raw, Currency fallbackCurrency) {
    if (raw.blockReason != null) {
      throw const InvoiceFailure(
        InvoiceErrorKind.safetyBlock,
        debugCode: GeminiDebugCodes.promptBlocked,
      );
    }
    final String? finish = raw.finishReason;
    if (finish != null && _blockedFinishReasons.contains(finish)) {
      throw const InvoiceFailure(
        InvoiceErrorKind.safetyBlock,
        debugCode: GeminiDebugCodes.finishBlocked,
      );
    }
    if (finish == 'maxTokens') {
      throw const InvoiceFailure(
        InvoiceErrorKind.malformedJson,
        debugCode: GeminiDebugCodes.truncated,
      );
    }
    final String? text = raw.text;
    if (text == null || text.trim().isEmpty) {
      throw const InvoiceFailure(
        InvoiceErrorKind.emptyResponse,
        debugCode: GeminiDebugCodes.emptyText,
      );
    }
    return parseExtraction(
      text,
      fallbackCurrency: fallbackCurrency,
      newLineId: _newLineId,
    );
  }
}
