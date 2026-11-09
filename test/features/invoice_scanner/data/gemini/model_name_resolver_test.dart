import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/model_name_resolver.dart';

void main() {
  const String fallback = ModelNameResolver.defaultFallbackModel;

  ModelNameResolver resolver(String? Function() remote) =>
      ModelNameResolver(readRemote: remote);

  test('a valid remote name comes first, the fallback is always last', () {
    expect(resolver(() => 'gemini-4-argon').candidates(), <String>[
      'gemini-4-argon',
      fallback,
    ]);
  });

  test('a missing or empty remote value leaves only the fallback', () {
    expect(resolver(() => null).candidates(), <String>[fallback]);
    expect(resolver(() => '   ').candidates(), <String>[fallback]);
  });

  test('malformed names are skipped', () {
    for (final String bad in <String>[
      'Gemini-4',
      'models/gemini-4',
      'a',
      'has space',
      '-leading-dash',
      '../x',
      'x' * 100,
    ]) {
      expect(resolver(() => bad).candidates(), <String>[fallback], reason: bad);
    }
  });

  test('a throwing remote read is survived', () {
    expect(resolver(() => throw Exception('plugin')).candidates(), <String>[
      fallback,
    ]);
  });

  test('a remote name equal to the fallback is not duplicated', () {
    expect(resolver(() => fallback).candidates(), <String>[fallback]);
  });

  test('the last name that worked is tried after the remote value', () {
    String remote = 'model-a';
    final ModelNameResolver r = resolver(() => remote);
    r.markGood('model-a');
    remote = 'model-b';
    expect(r.candidates(), <String>['model-b', 'model-a', fallback]);
  });

  test('an unavailable name is skipped for the rest of the session', () {
    final ModelNameResolver r = resolver(() => 'model-a');
    r.markUnavailable('model-a');
    expect(r.candidates(), <String>[fallback]);
  });

  test('marking a name unavailable clears it as last-known-good', () {
    final ModelNameResolver r = resolver(() => null);
    r.markGood('model-a');
    r.markUnavailable('model-a');
    expect(r.candidates(), <String>[fallback]);
  });

  test('the fallback is still tried even if it was marked unavailable', () {
    final ModelNameResolver r = resolver(() => null);
    r.markUnavailable(fallback);
    expect(r.candidates(), <String>[fallback]);
  });

  test('a previously good name works again after markGood', () {
    final ModelNameResolver r = resolver(() => 'model-a');
    r.markUnavailable('model-a');
    r.markGood('model-a');
    expect(r.candidates().first, 'model-a');
  });
}
