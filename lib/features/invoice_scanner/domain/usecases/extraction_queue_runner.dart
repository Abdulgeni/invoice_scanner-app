import 'dart:async';

import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/connectivity_monitor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/process_extraction_queue.dart';

/// `ProcessExtractionQueue.runOnce` has this shape.
typedef QueuePass =
    Future<QueuePassSummary> Function({required CancellationToken stop});

/// Keeps the offline queue draining while the app is running.
///
/// Passes start on [start], on every transition to online, and on [kick]
/// (call it when the app resumes). Single-flight: triggers that arrive while
/// a pass is running coalesce into exactly one more pass afterwards.
///
/// Records are not picked up merely because they were captured: the
/// foreground flow extracts those itself, and a record only reaches this
/// queue after a network failure or crash recovery.
class ExtractionQueueRunner {
  ExtractionQueueRunner({
    required QueuePass pass,
    required ConnectivityMonitor connectivity,
  }) : _pass = pass,
       _connectivity = connectivity;

  final QueuePass _pass;
  final ConnectivityMonitor _connectivity;
  final CancellationToken _stop = CancellationToken();

  StreamSubscription<bool>? _subscription;
  Future<void>? _current;
  bool _running = false;
  bool _again = false;
  bool _stopped = false;

  void start() {
    if (_stopped || _subscription != null) return;
    _subscription = _connectivity.onlineChanges.listen((bool online) {
      if (online) kick();
    }, onError: (Object _) {});
    kick();
  }

  void kick() {
    if (_stopped) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _current = _loop();
  }

  Future<void> _loop() async {
    try {
      do {
        _again = false;
        await _pass(stop: _stop);
      } while (_again && !_stopped);
    } on Exception {
      // A failed pass (for example storage unavailable) must not end the
      // runner; the next trigger tries again.
    } finally {
      _running = false;
    }
  }

  /// Stops scheduling, lets an in-flight extraction finish, and waits for
  /// the current pass to end. Idempotent.
  Future<void> stop() async {
    _stopped = true;
    _stop.cancel();
    final StreamSubscription<bool>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _current;
  }
}
