import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0B6E5A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD3EDE4),
    onPrimaryContainer: Color(0xFF06382D),
    secondary: Color(0xFF44525C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE3E9ED),
    onSecondaryContainer: Color(0xFF1B2830),
    tertiary: Color(0xFF8A5A00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFE8BF),
    onTertiaryContainer: Color(0xFF3A2400),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF7F8F6),
    onSurface: Color(0xFF14201C),
    onSurfaceVariant: Color(0xFF46524D),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1F4F1),
    surfaceContainer: Color(0xFFEBEFEC),
    surfaceContainerHigh: Color(0xFFE5EAE6),
    surfaceContainerHighest: Color(0xFFDFE5E1),
    outline: Color(0xFF6B7872),
    outlineVariant: Color(0xFFC8D0CB),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF26312D),
    onInverseSurface: Color(0xFFEEF3F0),
    inversePrimary: Color(0xFF7FD8BE),
    surfaceTint: Color(0x00000000),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7FD8BE),
    onPrimary: Color(0xFF00382C),
    primaryContainer: Color(0xFF0B5444),
    onPrimaryContainer: Color(0xFFBDF0DF),
    secondary: Color(0xFFB9C9D2),
    onSecondary: Color(0xFF233138),
    secondaryContainer: Color(0xFF3A4850),
    onSecondaryContainer: Color(0xFFD6E4EC),
    tertiary: Color(0xFFF2BD6B),
    onTertiary: Color(0xFF432C00),
    tertiaryContainer: Color(0xFF613F00),
    onTertiaryContainer: Color(0xFFFFE0A8),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF0E1512),
    onSurface: Color(0xFFE3EAE6),
    onSurfaceVariant: Color(0xFFBFC9C3),
    surfaceContainerLowest: Color(0xFF090F0C),
    surfaceContainerLow: Color(0xFF121A16),
    surfaceContainer: Color(0xFF161F1B),
    surfaceContainerHigh: Color(0xFF1D2723),
    surfaceContainerHighest: Color(0xFF273029),
    outline: Color(0xFF8A9791),
    outlineVariant: Color(0xFF3B4641),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE3EAE6),
    onInverseSurface: Color(0xFF1B2420),
    inversePrimary: Color(0xFF0B6E5A),
    surfaceTint: Color(0x00000000),
  );
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
  });

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF16703F),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD6F0DE),
    onSuccessContainer: Color(0xFF0A3A1F),
    warning: Color(0xFF8A5A00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFF1CC),
    onWarningContainer: Color(0xFF4D3600),
    heroStart: Color(0xFF0B6E5A),
    heroEnd: Color(0xFF05483B),
    onHero: Color(0xFFFFFFFF),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF8EDBA8),
    onSuccess: Color(0xFF003919),
    successContainer: Color(0xFF0F4D2C),
    onSuccessContainer: Color(0xFFC5EFD3),
    warning: Color(0xFFF2BD6B),
    onWarning: Color(0xFF432C00),
    warningContainer: Color(0xFF4A3300),
    onWarningContainer: Color(0xFFFFE0A8),
    heroStart: Color(0xFF0B5444),
    heroEnd: Color(0xFF08382E),
    onHero: Color(0xFFE8F5F0),
  );

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color heroStart;
  final Color heroEnd;
  final Color onHero;

  LinearGradient get heroGradient => LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: <Color>[heroStart, heroEnd],
      );

  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>()!;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? heroStart,
    Color? heroEnd,
    Color? onHero,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      onHero: onHero ?? this.onHero,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      success: l(success, other.success),
      onSuccess: l(onSuccess, other.onSuccess),
      successContainer: l(successContainer, other.successContainer),
      onSuccessContainer: l(onSuccessContainer, other.onSuccessContainer),
      warning: l(warning, other.warning),
      onWarning: l(onWarning, other.onWarning),
      warningContainer: l(warningContainer, other.warningContainer),
      onWarningContainer: l(onWarningContainer, other.onWarningContainer),
      heroStart: l(heroStart, other.heroStart),
      heroEnd: l(heroEnd, other.heroEnd),
      onHero: l(onHero, other.onHero),
    );
  }
}
