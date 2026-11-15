import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/auth/anonymous_auth_gate.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

void main() {
  group('mapAuthError', () {
    test('maps known codes to the taxonomy', () {
      const Map<String, (InvoiceErrorKind, String)> expected =
          <String, (InvoiceErrorKind, String)>{
            'network-request-failed': (
              InvoiceErrorKind.network,
              AuthDebugCodes.network,
            ),
            'too-many-requests': (
              InvoiceErrorKind.quotaExceeded,
              AuthDebugCodes.rateLimited,
            ),
            'operation-not-allowed': (
              InvoiceErrorKind.unknown,
              AuthDebugCodes.anonymousDisabled,
            ),
            'invalid-api-key': (
              InvoiceErrorKind.unknown,
              AuthDebugCodes.keyRejected,
            ),
            'app-not-authorized': (
              InvoiceErrorKind.unknown,
              AuthDebugCodes.keyRejected,
            ),
            'something-new': (InvoiceErrorKind.unknown, AuthDebugCodes.other),
          };
      expected.forEach((String code, (InvoiceErrorKind, String) e) {
        final InvoiceFailure f = mapAuthError(code);
        expect((f.kind, f.debugCode), e, reason: code);
      });
    });
  });

  group('AnonymousAuthGate', () {
    late bool signedIn;
    late int signIns;
    Object? error;
    Completer<void>? gate;

    AnonymousAuthGate make() => AnonymousAuthGate(
      hasUser: () => signedIn,
      signIn: () async {
        signIns++;
        await gate?.future;
        final Object? e = error;
        if (e != null) throw e;
        signedIn = true;
      },
    );

    setUp(() {
      signedIn = false;
      signIns = 0;
      error = null;
      gate = null;
    });

    test('does nothing when a user already exists', () async {
      signedIn = true;
      await make().ensureSignedIn();
      expect(signIns, 0);
    });

    test('signs in once, and not again afterwards', () async {
      final AnonymousAuthGate g = make();
      await g.ensureSignedIn();
      await g.ensureSignedIn();
      expect(signIns, 1);
    });

    test('concurrent callers share one sign-in', () async {
      gate = Completer<void>();
      final AnonymousAuthGate g = make();
      final List<Future<void>> calls = <Future<void>>[
        g.ensureSignedIn(),
        g.ensureSignedIn(),
        g.ensureSignedIn(),
      ];
      await pumpEventQueue();
      gate!.complete();
      await Future.wait(calls);
      expect(signIns, 1);
    });

    test('a failure is typed, and the next call tries again', () async {
      error = const InvoiceFailure(InvoiceErrorKind.network, debugCode: 'x');
      final AnonymousAuthGate g = make();
      await expectLater(g.ensureSignedIn(), throwsA(isA<InvoiceFailure>()));
      error = null;
      await g.ensureSignedIn();
      expect(signIns, 2);
      expect(signedIn, isTrue);
    });

    test(
      'socket and timeout errors become network and timeout failures',
      () async {
        error = const SocketException('x');
        await expectLater(
          make().ensureSignedIn(),
          throwsA(
            isA<InvoiceFailure>().having(
              (InvoiceFailure f) => f.kind,
              'kind',
              InvoiceErrorKind.network,
            ),
          ),
        );
        error = TimeoutException('x');
        await expectLater(
          make().ensureSignedIn(),
          throwsA(
            isA<InvoiceFailure>().having(
              (InvoiceFailure f) => f.kind,
              'kind',
              InvoiceErrorKind.timeout,
            ),
          ),
        );
      },
    );
  });
}
