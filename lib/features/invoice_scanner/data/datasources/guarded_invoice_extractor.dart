import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/usage/daily_usage_counter.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

abstract final class GuardDebugCodes {
  static const String dailyCap = 'daily_cap';
  static const String firebaseUnavailable = 'firebase_unavailable';
}

/// Makes sure the user is signed in before the wrapped extractor runs.
/// A sign-in failure ends the call before anything is counted or sent.
class AuthGatedInvoiceExtractor implements InvoiceExtractor {
  AuthGatedInvoiceExtractor({
    required InvoiceExtractor inner,
    required Future<void> Function() ensureSignedIn,
  }) : _inner = inner,
       _ensureSignedIn = ensureSignedIn;

  final InvoiceExtractor _inner;
  final Future<void> Function() _ensureSignedIn;

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    cancel.throwIfCancelled();
    await cancel.race(_ensureSignedIn());
    return _inner.extract(
      imagePaths: imagePaths,
      fallbackCurrency: fallbackCurrency,
      cancel: cancel,
    );
  }
}

/// Limits reads per day on this device. Each call uses one unit up front;
/// a `network` failure (the request may never have left the device) gives
/// it back. The user sees the ordinary "scanning limit" message.
class CappedInvoiceExtractor implements InvoiceExtractor {
  CappedInvoiceExtractor({
    required InvoiceExtractor inner,
    required DailyUsageCounter counter,
    required int cap,
  }) : _inner = inner,
       _counter = counter,
       _cap = cap;

  final InvoiceExtractor _inner;
  final DailyUsageCounter _counter;
  final int _cap;

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    cancel.throwIfCancelled();
    if (!await _counter.tryConsume(_cap)) {
      throw const InvoiceFailure(
        InvoiceErrorKind.quotaExceeded,
        debugCode: GuardDebugCodes.dailyCap,
      );
    }
    try {
      return await _inner.extract(
        imagePaths: imagePaths,
        fallbackCurrency: fallbackCurrency,
        cancel: cancel,
      );
    } on InvoiceFailure catch (failure) {
      if (failure.kind == InvoiceErrorKind.network && _cap > 0) {
        await _counter.release();
      }
      rethrow;
    }
  }
}

/// Stands in when Firebase could not start. Capture, history and deletion
/// keep working; reading says it is unavailable.
class UnavailableInvoiceExtractor implements InvoiceExtractor {
  const UnavailableInvoiceExtractor();

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) {
    return Future<Invoice>.error(
      const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: GuardDebugCodes.firebaseUnavailable,
      ),
    );
  }
}
