import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/app/app_config.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

void main() {
  test('safe defaults', () {
    const AppConfig c = AppConfig();
    expect(c.useDemoExtractor, isFalse);
    expect(
      c.useDeveloperApi,
      isFalse,
      reason: 'real invoices need Agent Platform',
    );
    expect(c.dailyExtractionCap, 60);
    expect(c.limitedUseAppCheckTokens, isFalse);
    expect(c.fallbackCurrency, Currency.usd);
    expect(c.location, isNull);
  });

  test('location is trimmed and empty means default', () {
    expect(const AppConfig(aiLocation: '  eu-west  ').location, 'eu-west');
    expect(const AppConfig(aiLocation: '   ').location, isNull);
  });

  test('an unusable fallback currency falls back to USD', () {
    expect(
      const AppConfig(fallbackCurrencyCode: 'etb').fallbackCurrency.code,
      'ETB',
    );
    expect(
      const AppConfig(fallbackCurrencyCode: 'nope').fallbackCurrency,
      Currency.usd,
    );
    expect(
      const AppConfig(fallbackCurrencyCode: '').fallbackCurrency,
      Currency.usd,
    );
  });

  group('the App Check debug provider', () {
    bool use({
      required bool debug,
      required bool release,
      required bool forced,
    }) => AppConfig.debugProviderFor(
      debugMode: debug,
      releaseMode: release,
      forced: forced,
    );

    test('is used in debug builds', () {
      expect(use(debug: true, release: false, forced: false), isTrue);
    });

    test('is used in profile builds only when forced', () {
      expect(use(debug: false, release: false, forced: false), isFalse);
      expect(use(debug: false, release: false, forced: true), isTrue);
    });

    test('is never used in release builds, even when forced', () {
      expect(use(debug: false, release: true, forced: true), isFalse);
      expect(use(debug: false, release: true, forced: false), isFalse);
    });
  });
}
