import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/theme/app_colors.dart';

double contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

typedef _Pair = (String, Color, Color);

List<_Pair> _schemePairs(ColorScheme s) => <_Pair>[
  ('onSurface/surface', s.onSurface, s.surface),
  ('onSurface/card', s.onSurface, s.surfaceContainerLowest),
  ('onSurfaceVariant/surface', s.onSurfaceVariant, s.surface),
  ('onSurfaceVariant/highest', s.onSurfaceVariant, s.surfaceContainerHighest),
  ('onPrimary/primary', s.onPrimary, s.primary),
  ('onPrimaryContainer', s.onPrimaryContainer, s.primaryContainer),
  ('onSecondary/secondary', s.onSecondary, s.secondary),
  ('onSecondaryContainer', s.onSecondaryContainer, s.secondaryContainer),
  ('onTertiary/tertiary', s.onTertiary, s.tertiary),
  ('onTertiaryContainer', s.onTertiaryContainer, s.tertiaryContainer),
  ('onError/error', s.onError, s.error),
  ('onErrorContainer', s.onErrorContainer, s.errorContainer),
  ('onInverseSurface', s.onInverseSurface, s.inverseSurface),
  ('inversePrimary/inverseSurface', s.inversePrimary, s.inverseSurface),
  ('primary text on surface', s.primary, s.surface),
];

List<_Pair> _semanticPairs(AppSemanticColors c) => <_Pair>[
  ('onSuccess/success', c.onSuccess, c.success),
  ('onSuccessContainer', c.onSuccessContainer, c.successContainer),
  ('onWarning/warning', c.onWarning, c.warning),
  ('onWarningContainer', c.onWarningContainer, c.warningContainer),
  ('onHero/heroStart', c.onHero, c.heroStart),
  ('onHero/heroEnd', c.onHero, c.heroEnd),
];

void main() {
  const Map<String, (ColorScheme, AppSemanticColors)> themes =
      <String, (ColorScheme, AppSemanticColors)>{
        'light': (AppColors.lightScheme, AppSemanticColors.light),
        'dark': (AppColors.darkScheme, AppSemanticColors.dark),
      };

  for (final MapEntry<String, (ColorScheme, AppSemanticColors)> e
      in themes.entries) {
    final ColorScheme scheme = e.value.$1;
    final AppSemanticColors semantic = e.value.$2;

    group('${e.key} theme WCAG AA', () {
      for (final _Pair p in <_Pair>[
        ..._schemePairs(scheme),
        ..._semanticPairs(semantic),
      ]) {
        test('text ${p.$1} >= 4.5:1', () {
          expect(contrast(p.$2, p.$3), greaterThanOrEqualTo(4.5));
        });
      }

      test('input outline vs surface and card >= 3:1', () {
        expect(
          contrast(scheme.outline, scheme.surface),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrast(scheme.outline, scheme.surfaceContainerLowest),
          greaterThanOrEqualTo(3),
        );
      });
    });
  }
}
