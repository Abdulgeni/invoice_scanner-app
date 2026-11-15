import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/usage/daily_usage_counter.dart';

void main() {
  late Directory temp;
  late File file;
  late DateTime now;

  DailyUsageCounter make() => DailyUsageCounter(file: file, clock: () => now);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('usage_test');
    file = File('${temp.path}${Platform.pathSeparator}usage.json');
    now = DateTime.utc(2026, 11, 8, 10);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('counts up to the cap and then refuses without recording', () async {
    final DailyUsageCounter c = make();
    expect(
      <bool>[
        await c.tryConsume(3),
        await c.tryConsume(3),
        await c.tryConsume(3),
        await c.tryConsume(3),
      ],
      <bool>[true, true, true, false],
    );
    expect(await c.countToday(), 3);
  });

  test('the count survives a new instance', () async {
    await make().tryConsume(5);
    await make().tryConsume(5);
    expect(await make().countToday(), 2);
  });

  test('a new UTC day starts at zero', () async {
    final DailyUsageCounter c = make();
    await c.tryConsume(2);
    await c.tryConsume(2);
    expect(await c.tryConsume(2), isFalse);

    now = DateTime.utc(2026, 11, 9, 0, 0, 1);
    expect(await c.countToday(), 0);
    expect(await c.tryConsume(2), isTrue);
  });

  test('the day boundary is UTC, whatever zone the clock reports', () async {
    final DailyUsageCounter c = make();
    now = DateTime.utc(2026, 11, 8, 23, 59, 59);
    await c.tryConsume(1);
    expect(await c.tryConsume(1), isFalse);
    now = DateTime.parse('2026-11-09T02:59:59+03:00');
    expect(await c.tryConsume(1), isFalse);
  });

  test('release gives a use back, never below zero', () async {
    final DailyUsageCounter c = make();
    await c.tryConsume(2);
    await c.tryConsume(2);
    await c.release();
    expect(await c.countToday(), 1);
    await c.release();
    await c.release();
    expect(await c.countToday(), 0);
  });

  test('a damaged file counts as zero and is repaired', () async {
    file.writeAsStringSync('{not json');
    final DailyUsageCounter c = make();
    expect(await c.countToday(), 0);
    expect(await c.tryConsume(5), isTrue);
    expect(await make().countToday(), 1);

    for (final String bad in <String>[
      '[]',
      '{"day":"2026-11-08","count":-4}',
      '{"day":"2026-11-08","count":"3"}',
      '{"count":2}',
    ]) {
      file.writeAsStringSync(bad);
      expect(await make().countToday(), 0, reason: bad);
    }
  });

  test('a cap of zero or less means no cap and records nothing', () async {
    final DailyUsageCounter c = make();
    for (int i = 0; i < 5; i++) {
      expect(await c.tryConsume(0), isTrue);
      expect(await c.tryConsume(-1), isTrue);
    }
    expect(await c.countToday(), 0);
    expect(file.existsSync(), isFalse);
  });

  test('parallel callers are serialized: exactly the cap succeeds', () async {
    final DailyUsageCounter c = make();
    final List<bool> results = await Future.wait<bool>(<Future<bool>>[
      for (int i = 0; i < 12; i++) c.tryConsume(5),
    ]);
    expect(results.where((bool ok) => ok), hasLength(5));
    expect(await c.countToday(), 5);
  });

  test('a file that cannot be written fails open', () async {
    final File blocker = File('${temp.path}${Platform.pathSeparator}blocker')
      ..writeAsStringSync('x');
    final DailyUsageCounter c = DailyUsageCounter(
      file: File('${blocker.path}${Platform.pathSeparator}usage.json'),
      clock: () => now,
    );
    expect(await c.tryConsume(1), isTrue);
    expect(await c.tryConsume(1), isTrue);
  });

  test('no temporary file is left behind', () async {
    await make().tryConsume(3);
    expect(
      temp
          .listSync()
          .whereType<File>()
          .map((File f) => f.path)
          .where((String p) => p.endsWith('.tmp')),
      isEmpty,
    );
  });
}
