import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/async/cancellation_token.dart';

void main() {
  test('cancel is idempotent and completes whenCancelled', () async {
    final CancellationToken token = CancellationToken();
    expect(token.isCancelled, isFalse);
    token.cancel();
    token.cancel();
    expect(token.isCancelled, isTrue);
    await token.whenCancelled;
  });

  test('throwIfCancelled', () {
    final CancellationToken token = CancellationToken();
    token.throwIfCancelled();
    token.cancel();
    expect(token.throwIfCancelled, throwsA(isA<CancelledException>()));
  });

  test('race returns the work result when not cancelled', () async {
    final CancellationToken token = CancellationToken();
    expect(await token.race(Future<int>.value(7)), 7);
  });

  test('race propagates the work error when not cancelled', () async {
    final CancellationToken token = CancellationToken();
    await expectLater(
      token.race(Future<int>.error(StateError('boom'))),
      throwsA(isA<StateError>()),
    );
  });

  test('cancel before completion fails with CancelledException', () async {
    final CancellationToken token = CancellationToken();
    final Completer<int> work = Completer<int>();
    final Future<int> raced = token.race(work.future);
    token.cancel();
    await expectLater(raced, throwsA(isA<CancelledException>()));
    work.complete(1);
  });

  test('already-cancelled token fails immediately', () async {
    final CancellationToken token = CancellationToken()..cancel();
    await expectLater(
      token.race(Future<int>.value(1)),
      throwsA(isA<CancelledException>()),
    );
  });

  test('late errors from abandoned work never escape', () async {
    final List<Object> uncaught = <Object>[];
    await runZonedGuarded(() async {
      final CancellationToken token = CancellationToken();
      final Completer<int> work = Completer<int>();
      final Future<int> raced = token.race(work.future);
      token.cancel();
      await expectLater(raced, throwsA(isA<CancelledException>()));
      work.completeError(StateError('late'));
      await Future<void>.delayed(Duration.zero);
    }, (Object error, StackTrace stack) => uncaught.add(error));
    expect(uncaught, isEmpty);
  });

  test('late errors after an already-cancelled token never escape', () async {
    final List<Object> uncaught = <Object>[];
    await runZonedGuarded(() async {
      final CancellationToken token = CancellationToken()..cancel();
      final Completer<int> work = Completer<int>();
      await expectLater(
        token.race(work.future),
        throwsA(isA<CancelledException>()),
      );
      work.completeError(StateError('late'));
      await Future<void>.delayed(Duration.zero);
    }, (Object error, StackTrace stack) => uncaught.add(error));
    expect(uncaught, isEmpty);
  });
}
