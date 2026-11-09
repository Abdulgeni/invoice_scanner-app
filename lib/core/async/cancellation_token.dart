import 'dart:async';

/// Thrown by [CancellationToken.race] and [CancellationToken.throwIfCancelled].
/// Data-layer catch sites map this to `InvoiceErrorKind.cancelled`.
final class CancelledException implements Exception {
  const CancelledException();

  @override
  String toString() => 'CancelledException';
}

/// Cooperative cancellation. One token per scan operation.
final class CancellationToken {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called. Never completes with an error.
  Future<void> get whenCancelled => _completer.future;

  /// Safe to call more than once.
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const CancelledException();
  }

  /// Completes with [work]'s result, or fails with [CancelledException] if
  /// the token is cancelled first.
  ///
  /// This does NOT stop [work] (an in-flight network call keeps running); it
  /// only stops waiting for it. Any result or error from [work] after
  /// cancellation is swallowed so it cannot surface as an unhandled error.
  Future<T> race<T>(Future<T> work) {
    if (isCancelled) {
      unawaited(work.then<void>((T _) {}, onError: (Object _) {}));
      return Future<T>.error(const CancelledException());
    }
    final Completer<T> out = Completer<T>();
    unawaited(
      work.then<void>(
        (T value) {
          if (!out.isCompleted) out.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!out.isCompleted) out.completeError(error, stack);
        },
      ),
    );
    unawaited(
      whenCancelled.then<void>((_) {
        if (!out.isCompleted) out.completeError(const CancelledException());
      }),
    );
    return out.future;
  }
}
