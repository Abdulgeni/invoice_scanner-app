import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/db/app_database.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/repositories/drift_invoice_repository.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

import '../../../../support/fakes.dart';

const String dir = '/data/invoice_images';
String img(String name) => '$dir${Platform.pathSeparator}$name';

final DateTime t0 = testT0;
final DateTime t1 = testT0.add(const Duration(minutes: 1));
final DateTime t2 = testT0.add(const Duration(minutes: 2));

InvoiceRecord queued(String id, {DateTime? at}) => InvoiceRecord.queued(
  id: id,
  imagePaths: <String>[img('${id}_0.jpg'), img('${id}_1.jpg')],
  now: at ?? t0,
);

InvoiceRecord inReview(String id, {DateTime? at}) =>
    queued(id, at: at).markExtracting(t1).markNeedsReview(sampleInvoice(), t1);

Future<void> waitFor(bool Function() condition) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 5)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late AppDatabase db;
  late DriftInvoiceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftInvoiceRepository(db, managedDirPath: dir);
  });

  tearDown(() => db.close());

  Future<void> rawInsert(
    String id, {
    String status = 'pendingExtraction',
    String names = '["a_0.jpg"]',
    String? invoiceJson,
    String? failureKind,
    int attempts = 0,
  }) {
    return db
        .into(db.invoiceRows)
        .insert(
          InvoiceRowsCompanion(
            id: Value<String>(id),
            status: Value<String>(status),
            imageNames: Value<String>(names),
            attemptCount: Value<int>(attempts),
            createdAt: const Value<int>(1),
            updatedAt: const Value<int>(1),
            invoiceJson: Value<String?>(invoiceJson),
            failureKind: Value<String?>(failureKind),
          ),
        );
  }

  group('schema', () {
    test('has the sync-ready nullable columns from day one', () async {
      final rows = await db.customSelect('PRAGMA table_info(invoices)').get();
      final Map<String, int> notNull = <String, int>{
        for (final row in rows)
          row.read<String>('name'): row.read<int>('notnull'),
      };
      expect(notNull['remote_synced_at'], 0);
      expect(notNull['deleted_at'], 0);
      expect(notNull['id'], isNotNull);
    });
  });

  group('insertIfAbsent', () {
    test('inserts once and never overwrites', () async {
      expect(await repo.insertIfAbsent(queued('a')), isTrue);
      final InvoiceRecord other = InvoiceRecord.queued(
        id: 'a',
        imagePaths: <String>[img('other.jpg')],
        now: t2,
      );
      expect(await repo.insertIfAbsent(other), isFalse);
      expect(await repo.get('a'), queued('a'));
    });

    test('a tombstone still blocks reuse of the id', () async {
      await repo.insertIfAbsent(queued('a'));
      await repo.mutate('a', (InvoiceRecord r) => r.markDeleted(t1));
      expect(await repo.insertIfAbsent(queued('a')), isFalse);
    });

    test('paths outside the managed directory are rejected', () async {
      final InvoiceRecord outside = InvoiceRecord.queued(
        id: 'a',
        imagePaths: <String>['/somewhere/else/a_0.jpg'],
        now: t0,
      );
      await expectLater(repo.insertIfAbsent(outside), throwsArgumentError);
      expect(await repo.get('a'), isNull);
    });
  });

  group('round trips', () {
    test('every status comes back equal', () async {
      final Map<String, InvoiceRecord> records = <String, InvoiceRecord>{
        'pending': queued('pending'),
        'extracting': queued('extracting').markExtracting(t1),
        'review': inReview('review'),
        'failed': queued('failed').markFailed(InvoiceErrorKind.network, t1),
        'saved': inReview('saved').markSaved(sampleInvoice(), t2),
        'tombstone': inReview('tombstone').markDeleted(t2),
      };
      for (final InvoiceRecord r in records.values) {
        expect(await repo.insertIfAbsent(r), isTrue);
      }
      for (final MapEntry<String, InvoiceRecord> e in records.entries) {
        expect(await repo.get(e.key), e.value, reason: e.key);
      }
    });

    test('a missing id is null', () async {
      expect(await repo.get('nope'), isNull);
    });

    test('timestamps keep microsecond precision', () async {
      final DateTime precise = DateTime.utc(2026, 11, 8, 10, 0, 0, 123, 456);
      final InvoiceRecord r = InvoiceRecord.queued(
        id: 'a',
        imagePaths: <String>[img('a_0.jpg')],
        now: precise,
      );
      await repo.insertIfAbsent(r);
      expect((await repo.get('a'))!.createdAt, precise);
    });
  });

  group('image paths', () {
    test('are stored as relative names', () async {
      await repo.insertIfAbsent(queued('a'));
      final row = (await db.select(db.invoiceRows).get()).single;
      expect(row.imageNames, '["a_0.jpg","a_1.jpg"]');
    });

    test('are rebuilt against the current directory', () async {
      await repo.insertIfAbsent(queued('a'));
      final DriftInvoiceRepository moved = DriftInvoiceRepository(
        db,
        managedDirPath: '/new/container/images',
      );
      final InvoiceRecord record = (await moved.get('a'))!;
      expect(record.imagePaths, <String>[
        '/new/container/images${Platform.pathSeparator}a_0.jpg',
        '/new/container/images${Platform.pathSeparator}a_1.jpg',
      ]);
    });
  });

  group('mutate', () {
    test('applies the change to fresh state and persists it', () async {
      await repo.insertIfAbsent(queued('a'));
      final InvoiceRecord? written = await repo.mutate(
        'a',
        (InvoiceRecord r) => r.markExtracting(t1),
      );
      expect(written!.status, InvoiceStatus.extracting);
      expect(written.attemptCount, 1);
      expect(await repo.get('a'), written);
    });

    test('a missing id returns null', () async {
      expect(await repo.mutate('nope', (InvoiceRecord r) => r), isNull);
    });

    test('an illegal transition throws and writes nothing', () async {
      await repo.insertIfAbsent(queued('a'));
      await expectLater(
        repo.mutate('a', (InvoiceRecord r) => r.markSaved(sampleInvoice(), t1)),
        throwsStateError,
      );
      expect((await repo.get('a'))!.status, InvoiceStatus.pendingExtraction);
    });

    test('changing the id is rejected and writes nothing', () async {
      await repo.insertIfAbsent(queued('a'));
      await expectLater(
        repo.mutate('a', (InvoiceRecord r) => queued('b')),
        throwsArgumentError,
      );
      expect(await repo.get('b'), isNull);
      expect(await repo.get('a'), queued('a'));
    });

    test('concurrent claims: exactly one wins', () async {
      await repo.insertIfAbsent(queued('a'));
      final List<Object?> results =
          await Future.wait<Object?>(<Future<Object?>>[
            for (int i = 0; i < 4; i++)
              repo
                  .mutate('a', (InvoiceRecord r) => r.markExtracting(t1))
                  .then<Object?>(
                    (InvoiceRecord? v) => 'ok',
                    onError: (Object e) => e,
                  ),
          ]);
      expect(results.where((Object? r) => r == 'ok'), hasLength(1));
      expect(results.whereType<StateError>(), hasLength(3));
      expect((await repo.get('a'))!.attemptCount, 1);
    });
  });

  group('tombstones', () {
    test('erase the payload at the row level', () async {
      await repo.insertIfAbsent(inReview('a'));
      await repo.mutate('a', (InvoiceRecord r) => r.markDeleted(t2));
      final row = (await db.select(db.invoiceRows).get()).single;
      expect(row.invoiceJson, isNull);
      expect(row.extractedJson, isNull);
      expect(row.failureKind, isNull);
      expect(row.imageNames, '[]');
      expect(row.deletedAt, isNotNull);
    });

    test('even a record that still carries data is erased on write', () async {
      final InvoiceRecord leaky = InvoiceRecord(
        id: 'a',
        status: InvoiceStatus.saved,
        imagePaths: <String>[img('a_0.jpg')],
        attemptCount: 1,
        createdAt: t0,
        updatedAt: t1,
        invoice: sampleInvoice(),
        failureKind: InvoiceErrorKind.network,
        deletedAt: t2,
      );
      await repo.insertIfAbsent(leaky);
      final row = (await db.select(db.invoiceRows).get()).single;
      expect(row.invoiceJson, isNull);
      expect(row.failureKind, isNull);
      expect(row.imageNames, '[]');
    });
  });

  group('listByStatus', () {
    test('filters by status, hides tombstones, orders oldest first', () async {
      await repo.insertIfAbsent(queued('b', at: t1));
      await repo.insertIfAbsent(queued('c', at: t0));
      await repo.insertIfAbsent(queued('a', at: t0));
      await repo.insertIfAbsent(inReview('r'));
      await repo.insertIfAbsent(queued('gone', at: t0).markDeleted(t1));

      final List<InvoiceRecord> pending = await repo.listByStatus(
        <InvoiceStatus>{InvoiceStatus.pendingExtraction},
      );
      expect(pending.map((InvoiceRecord r) => r.id), <String>['a', 'c', 'b']);

      final List<InvoiceRecord> both = await repo.listByStatus(<InvoiceStatus>{
        InvoiceStatus.pendingExtraction,
        InvoiceStatus.needsReview,
      });
      expect(both, hasLength(4));
    });

    test('an empty status set returns nothing', () async {
      await repo.insertIfAbsent(queued('a'));
      expect(await repo.listByStatus(<InvoiceStatus>{}), isEmpty);
    });
  });

  group('watchSaved', () {
    test(
      'emits now and after every change, newest first, no tombstones',
      () async {
        final List<List<InvoiceRecord>> events = <List<InvoiceRecord>>[];
        final StreamSubscription<List<InvoiceRecord>> sub = repo
            .watchSaved()
            .listen(events.add);
        addTearDown(sub.cancel);

        await waitFor(() => events.isNotEmpty);
        expect(events.last, isEmpty);

        await repo.insertIfAbsent(inReview('old'));
        await repo.mutate(
          'old',
          (InvoiceRecord r) => r.markSaved(sampleInvoice(), t1),
        );
        await waitFor(() => events.last.length == 1);

        await repo.insertIfAbsent(inReview('new'));
        await repo.mutate(
          'new',
          (InvoiceRecord r) => r.markSaved(sampleInvoice(), t2),
        );
        await waitFor(() => events.last.length == 2);
        expect(events.last.map((InvoiceRecord r) => r.id), <String>[
          'new',
          'old',
        ]);

        await repo.mutate('old', (InvoiceRecord r) => r.markDeleted(t2));
        await waitFor(() => events.last.length == 1);
        expect(events.last.single.id, 'new');
      },
    );
  });

  group('damaged rows', () {
    test('are skipped by lists and reported by get and mutate', () async {
      await rawInsert('bogus-status', status: 'bogus');
      await rawInsert('bad-names', names: 'not json');
      await rawInsert('traversal', names: '["../x.jpg"]');
      await rawInsert('review-no-invoice', status: 'needsReview');
      await rawInsert('saved-no-invoice', status: 'saved');
      await rawInsert('failed-no-kind', status: 'failed');
      await rawInsert(
        'failed-bad-kind',
        status: 'failed',
        failureKind: 'bogus',
      );
      await rawInsert(
        'bad-invoice',
        status: 'needsReview',
        invoiceJson: 'garbage',
      );
      await rawInsert('negative-attempts', attempts: -1);
      await repo.insertIfAbsent(queued('good'));

      final List<InvoiceRecord> listed = await repo.listByStatus(
        InvoiceStatus.values.toSet(),
      );
      expect(listed.map((InvoiceRecord r) => r.id), <String>['good']);

      for (final String id in <String>[
        'bogus-status',
        'bad-names',
        'traversal',
        'review-no-invoice',
        'saved-no-invoice',
        'failed-no-kind',
        'failed-bad-kind',
        'bad-invoice',
        'negative-attempts',
      ]) {
        final Matcher corrupt = throwsA(
          isA<InvoiceFailure>().having(
            (InvoiceFailure f) => f.debugCode,
            'debugCode',
            DebugCodes.rowCorrupt,
          ),
        );
        await expectLater(repo.get(id), corrupt, reason: id);
        await expectLater(
          repo.mutate(id, (InvoiceRecord r) => r),
          corrupt,
          reason: id,
        );
        expect(await repo.insertIfAbsent(queued(id)), isFalse, reason: id);
      }
    });
  });
}
