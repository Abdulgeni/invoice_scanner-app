import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

void main() {
  test('every error kind has a human message', () async {
    final AppLocalizations l = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    final Map<String, String> messages = <String, String>{
      'network': l.errorNetwork,
      'timeout': l.errorTimeout,
      'quotaExceeded': l.errorQuotaExceeded,
      'appCheckFailed': l.errorAppCheckFailed,
      'safetyBlock': l.errorSafetyBlock,
      'emptyResponse': l.errorEmptyResponse,
      'malformedJson': l.errorMalformedJson,
      'notAnInvoice': l.errorNotAnInvoice,
      'cancelled': l.errorCancelled,
      'unknown': l.errorUnknown,
    };
    messages.forEach((String kind, String text) {
      expect(text.trim(), isNotEmpty, reason: kind);
    });
  });

  test('user-facing error messages leak no backend internals', () async {
    final AppLocalizations l = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    const List<String> forbidden = <String>[
      'firebase',
      'gemini',
      'google',
      'vertex',
      'quota',
      'app check',
      '429',
      'api',
      'token',
    ];
    final List<String> all = <String>[
      l.errorNetwork,
      l.errorTimeout,
      l.errorQuotaExceeded,
      l.errorAppCheckFailed,
      l.errorSafetyBlock,
      l.errorEmptyResponse,
      l.errorMalformedJson,
      l.errorNotAnInvoice,
      l.errorUnknown,
    ];
    for (final String message in all) {
      for (final String term in forbidden) {
        expect(message.toLowerCase(), isNot(contains(term)), reason: message);
      }
    }
  });

  test('placeholders render', () async {
    final AppLocalizations l = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(l.pageLimitExceeded(5), contains('5'));
    expect(l.validationInvalidNumber('1,234.56'), contains('1,234.56'));
  });
}
