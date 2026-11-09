import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

void main() {
  test('taxonomy is exactly the required set, in order', () {
    expect(
      InvoiceErrorKind.values.map((InvoiceErrorKind k) => k.name).toList(),
      <String>[
        'network',
        'timeout',
        'quotaExceeded',
        'appCheckFailed',
        'safetyBlock',
        'emptyResponse',
        'malformedJson',
        'notAnInvoice',
        'cancelled',
        'unknown',
      ],
    );
  });

  test('retry policy per kind', () {
    const Map<InvoiceErrorKind, (bool, bool, bool, bool)> expected =
        <InvoiceErrorKind, (bool, bool, bool, bool)>{
          InvoiceErrorKind.network: (true, true, false, true),
          InvoiceErrorKind.timeout: (true, true, false, false),
          InvoiceErrorKind.quotaExceeded: (false, true, false, false),
          InvoiceErrorKind.appCheckFailed: (false, false, false, false),
          InvoiceErrorKind.safetyBlock: (false, false, true, false),
          InvoiceErrorKind.emptyResponse: (false, true, true, false),
          InvoiceErrorKind.malformedJson: (false, true, false, false),
          InvoiceErrorKind.notAnInvoice: (false, false, true, false),
          InvoiceErrorKind.cancelled: (false, true, false, false),
          InvoiceErrorKind.unknown: (false, true, false, false),
        };
    expect(expected.keys.toSet(), InvoiceErrorKind.values.toSet());
    expected.forEach((InvoiceErrorKind kind, (bool, bool, bool, bool) p) {
      expect(kind.isTransient, p.$1, reason: '${kind.name} isTransient');
      expect(kind.canRetrySameImage, p.$2, reason: '${kind.name} canRetry');
      expect(kind.suggestsRetake, p.$3, reason: '${kind.name} retake');
      expect(kind.parksInOfflineQueue, p.$4, reason: '${kind.name} parks');
    });
  });

  test('only transient kinds are auto-retried', () {
    final Set<InvoiceErrorKind> transient = InvoiceErrorKind.values
        .where((InvoiceErrorKind k) => k.isTransient)
        .toSet();
    expect(transient, <InvoiceErrorKind>{
      InvoiceErrorKind.network,
      InvoiceErrorKind.timeout,
    });
  });

  test('value equality and safe toString', () {
    expect(
      const InvoiceFailure(InvoiceErrorKind.timeout, debugCode: 'http_503'),
      const InvoiceFailure(InvoiceErrorKind.timeout, debugCode: 'http_503'),
    );
    expect(
      const InvoiceFailure(InvoiceErrorKind.timeout),
      isNot(const InvoiceFailure(InvoiceErrorKind.network)),
    );
    expect(
      const InvoiceFailure(
        InvoiceErrorKind.timeout,
        debugCode: 'http_503',
      ).toString(),
      'InvoiceFailure(timeout, http_503)',
    );
    expect(
      const InvoiceFailure(InvoiceErrorKind.unknown).toString(),
      'InvoiceFailure(unknown)',
    );
  });
}
