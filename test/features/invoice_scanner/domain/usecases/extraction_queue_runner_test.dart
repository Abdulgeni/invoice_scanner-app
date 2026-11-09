import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/connectivity_monitor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extraction_queue_runner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/process_extraction_queue.dart';

class FakeMonitor implements ConnectivityMonitor {
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => controller.stream;
}

const QueuePassSummary done = QueuePassSummary(
  processed: 0,
  succeeded: 0,
  failed: 0,
  skipped: 0,
  stopReason: QueueStopReason.completed,
);

void main() {
  late FakeMonitor monitor;
  late int passes;
  late List<Completer<void>> gates;
  late List<CancellationToken> tokens;

  /// Each pass waits for the next gate, so tests control when it finishes.
  QueuePass gated({Object? throwOnFirst}) {
    return ({required CancellationToken stop}) async {
      final int index = passes++;
      tokens.add(stop);
      if (index == 0 && throwOnFirst != null) throw throwOnFirst;
      if (index < gates.length) await gates[index].future;
      return done;
    };
  }

  setUp(() {
    monitor = FakeMonitor();
    passes = 0;
    gates = <Completer<void>>[];
    tokens = <CancellationToken>[];
  });

  tearDown(() async {
    for (final Completer<void> g in gates) {
      if (!g.isCompleted) g.complete();
    }
    await monitor.controller.close();
  });

  test('start runs one pass immediately', () async {
    final ExtractionQueueRunner runner = ExtractionQueueRunner(
      pass: gated(),
      connectivity: monitor,
    )..start();
    await pumpEventQueue();
    expect(passes, 1);
    await runner.stop();
  });

  test('going online triggers a pass, going offline does not', () async {
    final ExtractionQueueRunner runner = ExtractionQueueRunner(
      pass: gated(),
      connectivity: monitor,
    )..start();
    await pumpEventQueue();
    expect(passes, 1);

    monitor.controller.add(false);
    await pumpEventQueue();
    expect(passes, 1);

    monitor.controller.add(true);
    await pumpEventQueue();
    expect(passes, 2);
    await runner.stop();
  });

  test('triggers while running coalesce into exactly one more pass', () async {
    gates.add(Completer<void>());
    final ExtractionQueueRunner runner = ExtractionQueueRunner(
      pass: gated(),
      connectivity: monitor,
    )..start();
    await pumpEventQueue();
    expect(passes, 1);

    runner.kick();
    runner.kick();
    monitor.controller.add(true);
    await pumpEventQueue();
    expect(passes, 1, reason: 'single-flight');

    gates.first.complete();
    await pumpEventQueue();
    expect(passes, 2, reason: 'one follow-up pass, not three');
    await runner.stop();
  });

  test(
    'stop waits for the in-flight pass and cancels its stop token',
    () async {
      gates.add(Completer<void>());
      final ExtractionQueueRunner runner = ExtractionQueueRunner(
        pass: gated(),
        connectivity: monitor,
      )..start();
      await pumpEventQueue();

      bool stopped = false;
      final Future<void> stopping = runner.stop().then((_) => stopped = true);
      await pumpEventQueue();
      expect(stopped, isFalse, reason: 'must wait for the running pass');
      expect(tokens.single.isCancelled, isTrue);

      gates.first.complete();
      await stopping;
      expect(stopped, isTrue);
    },
  );

  test('after stop nothing runs again', () async {
    final ExtractionQueueRunner runner = ExtractionQueueRunner(
      pass: gated(),
      connectivity: monitor,
    )..start();
    await pumpEventQueue();
    await runner.stop();

    runner.kick();
    runner.start();
    monitor.controller.add(true);
    await pumpEventQueue();
    expect(passes, 1);
    await runner.stop();
  });

  test('a failing pass does not kill the runner', () async {
    final ExtractionQueueRunner runner = ExtractionQueueRunner(
      pass: gated(throwOnFirst: Exception('storage unavailable')),
      connectivity: monitor,
    )..start();
    await pumpEventQueue();
    expect(passes, 1);

    runner.kick();
    await pumpEventQueue();
    expect(passes, 2);
    await runner.stop();
  });

  test('start is idempotent', () async {
    final ExtractionQueueRunner runner =
        ExtractionQueueRunner(pass: gated(), connectivity: monitor)
          ..start()
          ..start();
    await pumpEventQueue();
    expect(passes, 1);
    monitor.controller.add(true);
    await pumpEventQueue();
    expect(passes, 2, reason: 'one subscription, one extra pass');
    await runner.stop();
  });
}
