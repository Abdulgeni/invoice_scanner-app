import 'package:flutter/foundation.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

/// Build-time settings, read from `--dart-define`.
///
///   flutter run --dart-define=USE_DEMO_EXTRACTOR=true      (no Firebase)
///   flutter run --dart-define=AI_LOCATION=`<location>`
///   flutter run --dart-define=APP_CHECK_DEBUG=true         (profile builds)
final class AppConfig {
  const AppConfig({
    this.useDemoExtractor = const bool.fromEnvironment('USE_DEMO_EXTRACTOR'),
    this.useDeveloperApi = const bool.fromEnvironment('USE_DEVELOPER_API'),
    this.aiLocation = const String.fromEnvironment('AI_LOCATION'),
    this.forceAppCheckDebug = const bool.fromEnvironment('APP_CHECK_DEBUG'),
    this.limitedUseAppCheckTokens =
        const bool.fromEnvironment('LIMITED_USE_APP_CHECK_TOKENS'),
    this.dailyExtractionCap =
        const int.fromEnvironment('DAILY_EXTRACTION_CAP', defaultValue: 60),
    this.fallbackCurrencyCode =
        const String.fromEnvironment('FALLBACK_CURRENCY', defaultValue: 'USD'),
  });

  /// Skip Firebase entirely and read invoices with sample data.
  final bool useDemoExtractor;

  /// Use the Gemini Developer API instead of Agent Platform. Its free tier
  /// may use prompts to improve Google products: synthetic invoices only.
  final bool useDeveloperApi;
  final String aiLocation;
  final bool forceAppCheckDebug;
  final bool limitedUseAppCheckTokens;

  /// Reads per UTC day, counted on this device. Zero or less disables the cap.
  final int dailyExtractionCap;
  final String fallbackCurrencyCode;

  /// Null means "the SDK default".
  String? get location {
    final String trimmed = aiLocation.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Currency get fallbackCurrency =>
      Currency.tryParse(fallbackCurrencyCode) ?? Currency.usd;

  bool get useAppCheckDebugProvider => debugProviderFor(
        debugMode: kDebugMode,
        releaseMode: kReleaseMode,
        forced: forceAppCheckDebug,
      );

  /// Release builds always attest with Play Integrity. The debug provider is
  /// for debug builds, and for profile builds when explicitly forced.
  static bool debugProviderFor({
    required bool debugMode,
    required bool releaseMode,
    required bool forced,
  }) {
    if (releaseMode) return false;
    return debugMode || forced;
  }
}
