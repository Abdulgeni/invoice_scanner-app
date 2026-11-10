import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/error_presentation.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('planErrorActions', () {
    test('a retake suggestion leads, and a retry follows when still useful',
        () {
      final ErrorPlan both =
          planErrorActions(canRetry: true, suggestsRetake: true);
      expect((both.primary, both.secondary),
          (ErrorAction.retake, ErrorAction.retry));

      final ErrorPlan retakeOnly =
          planErrorActions(canRetry: false, suggestsRetake: true);
      expect((retakeOnly.primary, retakeOnly.secondary),
          (ErrorAction.retake, null));
    });

    test('a retry leads when a new photo would not help', () {
      final ErrorPlan plan =
          planErrorActions(canRetry: true, suggestsRetake: false);
      expect((plan.primary, plan.secondary), (ErrorAction.retry, null));
    });

    test('with neither, only keep and discard remain', () {
      final ErrorPlan plan =
          planErrorActions(canRetry: false, suggestsRetake: false);
      expect((plan.primary, plan.secondary), (null, null));
    });
  });

  group('presentationFor', () {
    test('every kind has its own title, a message and an icon', () {
      final Set<String> titles = <String>{};
      for (final InvoiceErrorKind kind in InvoiceErrorKind.values) {
        final ErrorPresentation p = presentationFor(l10n, kind);
        expect(p.title.trim(), isNotEmpty, reason: kind.name);
        expect(p.message.trim(), isNotEmpty, reason: kind.name);
        titles.add(p.title);
      }
      expect(titles, hasLength(InvoiceErrorKind.values.length));
    });

    test('only app-update, blocked-image and unknown errors are serious', () {
      final Set<InvoiceErrorKind> serious = InvoiceErrorKind.values
          .where((InvoiceErrorKind k) =>
              presentationFor(l10n, k).tone == ErrorTone.serious)
          .toSet();
      expect(serious, <InvoiceErrorKind>{
        InvoiceErrorKind.appCheckFailed,
        InvoiceErrorKind.safetyBlock,
        InvoiceErrorKind.unknown,
      });
    });

    test('titles and messages never leak backend internals', () {
      const List<String> forbidden = <String>[
        'firebase', 'gemini', 'google', 'vertex', 'quota', 'app check', '429',
      ];
      for (final InvoiceErrorKind kind in InvoiceErrorKind.values) {
        final ErrorPresentation p = presentationFor(l10n, kind);
        for (final String term in forbidden) {
          expect(p.title.toLowerCase(), isNot(contains(term)), reason: p.title);
          expect(p.message.toLowerCase(), isNot(contains(term)),
              reason: p.message);
        }
      }
    });

    test('the offline message promises nothing the app cannot keep', () {
      final String message =
          presentationFor(l10n, InvoiceErrorKind.network).message;
      expect(message.toLowerCase(), contains('saved'));
      expect(message.toLowerCase(), isNot(contains("we'll read")));
    });
  });
}
