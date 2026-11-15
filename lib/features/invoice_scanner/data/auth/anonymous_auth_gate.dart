import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

abstract final class AuthDebugCodes {
  static const String network = 'auth_network';
  static const String timeout = 'auth_timeout';
  static const String rateLimited = 'auth_rate_limited';
  static const String anonymousDisabled = 'config_anonymous_disabled';
  static const String keyRejected = 'config_auth_key';
  static const String other = 'auth_error';
}

/// Maps a Firebase Auth error code to the failure taxonomy. Only the code is
/// used; no message text.
InvoiceFailure mapAuthError(String code) {
  return switch (code) {
    'network-request-failed' => const InvoiceFailure(
        InvoiceErrorKind.network,
        debugCode: AuthDebugCodes.network,
      ),
    'too-many-requests' => const InvoiceFailure(
        InvoiceErrorKind.quotaExceeded,
        debugCode: AuthDebugCodes.rateLimited,
      ),
    'operation-not-allowed' => const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: AuthDebugCodes.anonymousDisabled,
      ),
    'invalid-api-key' || 'app-not-authorized' || 'api-key-not-valid' =>
      const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: AuthDebugCodes.keyRejected,
      ),
    _ => const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: AuthDebugCodes.other,
      ),
  };
}

/// Makes sure the device has a Firebase identity (anonymous sign-in), which
/// authenticated-users mode and per-user limits need. Concurrent callers
/// share one sign-in, and a failed attempt can be retried.
class AnonymousAuthGate {
  AnonymousAuthGate({
    required bool Function() hasUser,
    required Future<void> Function() signIn,
  })  : _hasUser = hasUser,
        _signIn = signIn;

  factory AnonymousAuthGate.fromFirebase(FirebaseAuth auth) {
    return AnonymousAuthGate(
      hasUser: () => auth.currentUser != null,
      signIn: () async {
        try {
          await auth.signInAnonymously();
        } on FirebaseAuthException catch (e) {
          throw mapAuthError(e.code);
        }
      },
    );
  }

  final bool Function() _hasUser;
  final Future<void> Function() _signIn;
  Future<void>? _inFlight;

  Future<void> ensureSignedIn() {
    if (_hasUser()) return Future<void>.value();
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    try {
      await _signIn();
    } on SocketException {
      throw const InvoiceFailure(
        InvoiceErrorKind.network,
        debugCode: AuthDebugCodes.network,
      );
    } on TimeoutException {
      throw const InvoiceFailure(
        InvoiceErrorKind.timeout,
        debugCode: AuthDebugCodes.timeout,
      );
    }
  }
}
