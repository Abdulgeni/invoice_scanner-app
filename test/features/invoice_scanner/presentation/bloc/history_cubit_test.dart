import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/history_sections.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/history_cubit.dart';

import '../../../../support/fakes.dart';

late StreamController<List<InvoiceRecord>> controller;
late List<String> deleted;
late DeleteOutcome outcome;
late int subscriptions;
Object? firstError;

InvoiceRecord pending(String id) => InvoiceRecord.queued(
  id: id,
  imagePaths: <String>['managed/${id}_0.jpg'],
  now: testT0,
);

HistoryCubit make() => HistoryCubit(
  watchLive: () {
    subscriptions++;
    final Object? error = firstError;
    if (subscriptions == 1 && error != null) {
      return Stream<List<InvoiceRecord>>.error(error);
    }
    return controller.stream;
  },
  deleteInvoice: (String id) async {
    deleted.add(id);
    return outcome;
  },
);

void main() {
  setUp(() {
    controller = StreamController<List<InvoiceRecord>>.broadcast();
    deleted = <String>[];
    outcome = DeleteOutcome.deleted;
    subscriptions = 0;
    firstError = null;
  });

  tearDown(() => controller.close());

  test('starts loading', () {
    final HistoryCubit cubit = make();
    addTearDown(cubit.close);
    expect(cubit.state, const HistoryLoading());
  });

  blocTest<HistoryCubit, HistoryState>(
    'every emission becomes grouped sections',
    build: make,
    act: (HistoryCubit c) async {
      await pumpEventQueue();
      controller.add(<InvoiceRecord>[pending('a')]);
      await pumpEventQueue();
      controller.add(<InvoiceRecord>[pending('a'), pending('b')]);
      await pumpEventQueue();
    },
    expect: () => <Matcher>[
      isA<HistoryLoaded>().having(
        (HistoryLoaded s) => s.sections.attention.length,
        'attention',
        1,
      ),
      isA<HistoryLoaded>().having(
        (HistoryLoaded s) => s.sections.attention.length,
        'attention',
        2,
      ),
    ],
  );

  blocTest<HistoryCubit, HistoryState>(
    'a stream error shows a failure, and retry recovers',
    build: () {
      firstError = Exception('db');
      return make();
    },
    act: (HistoryCubit c) async {
      await pumpEventQueue();
      c.retry();
      await pumpEventQueue();
      controller.add(<InvoiceRecord>[pending('a')]);
      await pumpEventQueue();
    },
    expect: () => <Matcher>[
      isA<HistoryFailed>(),
      isA<HistoryLoading>(),
      isA<HistoryLoaded>(),
    ],
    verify: (_) => expect(subscriptions, 2),
  );

  blocTest<HistoryCubit, HistoryState>(
    'a successful delete emits nothing: the list updates from the stream',
    build: make,
    act: (HistoryCubit c) async {
      await c.delete('a');
    },
    expect: () => <Matcher>[],
    verify: (_) => expect(deleted, <String>['a']),
  );

  blocTest<HistoryCubit, HistoryState>(
    'deleting something already gone is not an error',
    build: make,
    setUp: () => outcome = DeleteOutcome.notFound,
    act: (HistoryCubit c) async => c.delete('a'),
    expect: () => <Matcher>[],
  );

  blocTest<HistoryCubit, HistoryState>(
    'a failed delete raises a one-shot notice that keeps the list',
    build: make,
    setUp: () => outcome = DeleteOutcome.storageUnavailable,
    act: (HistoryCubit c) async {
      await pumpEventQueue();
      controller.add(<InvoiceRecord>[pending('a')]);
      await pumpEventQueue();
      await c.delete('a');
      c.noticeShown();
    },
    expect: () => <Matcher>[
      isA<HistoryLoaded>().having(
        (HistoryLoaded s) => s.notice,
        'notice',
        isNull,
      ),
      isA<HistoryLoaded>()
          .having(
            (HistoryLoaded s) => s.notice,
            'notice',
            HistoryNotice.deleteFailed,
          )
          .having((HistoryLoaded s) => s.sections.attention.length, 'kept', 1),
      isA<HistoryLoaded>().having(
        (HistoryLoaded s) => s.notice,
        'notice',
        isNull,
      ),
    ],
  );

  test('closing stops listening and ignores late events', () async {
    final HistoryCubit cubit = make();
    await pumpEventQueue();
    await cubit.close();
    controller.add(<InvoiceRecord>[pending('a')]);
    await pumpEventQueue();
    expect(cubit.isClosed, isTrue);
  });

  test('noticeShown without a notice changes nothing', () async {
    final HistoryCubit cubit = make();
    addTearDown(cubit.close);
    cubit.noticeShown();
    expect(cubit.state, const HistoryLoading());
  });

  test('groups use the shared pure function', () {
    expect(groupHistory(<InvoiceRecord>[pending('a')]).attention, hasLength(1));
  });
}
