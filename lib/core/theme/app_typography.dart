import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme textTheme(Brightness brightness, ColorScheme scheme) {
    final TextTheme base =
        ThemeData(brightness: brightness, useMaterial3: true).textTheme.apply(
              bodyColor: scheme.onSurface,
              displayColor: scheme.onSurface,
            );
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

@immutable
class AppMoneyStyles extends ThemeExtension<AppMoneyStyles> {
  const AppMoneyStyles({
    required this.display,
    required this.title,
    required this.body,
  });

  factory AppMoneyStyles.fromTextTheme(TextTheme t) {
    return AppMoneyStyles(
      display: (t.headlineMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: AppTypography.tabular,
      ),
      title: (t.titleMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: AppTypography.tabular,
      ),
      body: (t.bodyMedium ?? const TextStyle()).copyWith(
        fontFeatures: AppTypography.tabular,
      ),
    );
  }

  final TextStyle display;
  final TextStyle title;
  final TextStyle body;

  static AppMoneyStyles of(BuildContext context) =>
      Theme.of(context).extension<AppMoneyStyles>()!;

  @override
  AppMoneyStyles copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? body,
  }) {
    return AppMoneyStyles(
      display: display ?? this.display,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  @override
  AppMoneyStyles lerp(
    covariant ThemeExtension<AppMoneyStyles>? other,
    double t,
  ) {
    if (other is! AppMoneyStyles) return this;
    return AppMoneyStyles(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
    );
  }
}
