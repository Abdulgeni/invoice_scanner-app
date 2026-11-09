import 'package:equatable/equatable.dart';

/// Every failure in the scan pipeline maps to exactly one of these.
///
/// Mapping rules for data-layer catch sites (Module 5):
/// - no connectivity or socket failure        -> [network]
/// - client deadline, 5xx, overloaded service -> [timeout]
/// - HTTP 429 or resource-exhausted           -> [quotaExceeded]
/// - App Check or auth rejection (401/403)    -> [appCheckFailed]
/// - prompt or response blocked by safety     -> [safetyBlock]
/// - null or empty model text                 -> [emptyResponse]
/// - JSON decode or shape failure             -> [malformedJson]
/// - model reports the image is not an invoice-> [notAnInvoice]
/// - CancelledException                       -> [cancelled]
/// - anything else                            -> [unknown]
enum InvoiceErrorKind {
  network,
  timeout,
  quotaExceeded,
  appCheckFailed,
  safetyBlock,
  emptyResponse,
  malformedJson,
  notAnInvoice,
  cancelled,
  unknown,
}

extension InvoiceErrorKindPolicy on InvoiceErrorKind {
  /// Eligible for bounded automatic retry with exponential backoff.
  bool get isTransient =>
      this == InvoiceErrorKind.network || this == InvoiceErrorKind.timeout;

  /// The same image is worth submitting again (manually).
  bool get canRetrySameImage => switch (this) {
    InvoiceErrorKind.network ||
    InvoiceErrorKind.timeout ||
    InvoiceErrorKind.quotaExceeded ||
    InvoiceErrorKind.emptyResponse ||
    InvoiceErrorKind.malformedJson ||
    InvoiceErrorKind.cancelled ||
    InvoiceErrorKind.unknown => true,
    InvoiceErrorKind.appCheckFailed ||
    InvoiceErrorKind.safetyBlock ||
    InvoiceErrorKind.notAnInvoice => false,
  };

  /// A new photo is more likely to help than a retry.
  bool get suggestsRetake => switch (this) {
    InvoiceErrorKind.emptyResponse ||
    InvoiceErrorKind.safetyBlock ||
    InvoiceErrorKind.notAnInvoice => true,
    _ => false,
  };

  /// Park the invoice in the offline queue and resume when online.
  bool get parksInOfflineQueue => this == InvoiceErrorKind.network;
}

/// Typed failure carried across layers.
///
/// [debugCode] is a short technical code such as `http_503`. It must never
/// contain invoice content, prompts, or model output.
final class InvoiceFailure extends Equatable implements Exception {
  const InvoiceFailure(this.kind, {this.debugCode});

  final InvoiceErrorKind kind;
  final String? debugCode;

  @override
  List<Object?> get props => <Object?>[kind, debugCode];

  @override
  String toString() => debugCode == null
      ? 'InvoiceFailure(${kind.name})'
      : 'InvoiceFailure(${kind.name}, $debugCode)';
}
