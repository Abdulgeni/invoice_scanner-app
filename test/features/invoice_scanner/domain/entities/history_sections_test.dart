import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/history_sections.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

import '../../../../support/fakes.dart';

DateTime at(int minutes) => testT0.add(Duration(minutes: minutes));

InvoiceRecord base(String id, {int created = 0}) => InvoiceRecord.queued(
  id: id,
  imagePaths: <String>['managed/${id}_0.jpg'],
  now: at(created),
);

InvoiceRecord saved(String id, {required int savedAt}) => base(id)
    .markExtracting(at(1))
    .markNeedsReview(sampleInvoice(), at(1))
    .markSaved(sampleInvoice(), at(savedAt));

List<String> ids(List<InvoiceRecord> list) =>
    list.map((InvoiceRecord r) => r.id).toList();

void main() {
  test('nothing in, nothing out', () {
    final HistorySections s = groupHistory(const <InvoiceRecord>[]);
    expect(s.isEmpty, isTrue);
    expect(s, HistorySections.empty);
  });

  test('splits unfinished work from saved invoices', () {
    final HistorySections s = groupHistory(<InvoiceRecord>[
      base('pending'),
      base('reading').markExtracting(at(1)),
      base(
        'review',
      ).markExtracting(at(1)).markNeedsReview(sampleInvoice(), at(1)),
      base('failed').markFailed(InvoiceErrorKind.timeout, at(1)),
      saved('done', savedAt: 5),
    ]);
    expect(ids(s.saved), <String>['done']);
    expect(ids(s.attention).toSet(), <String>{
      'pending',
      'reading',
      'review',
      'failed',
    });
  });

  test('unfinished work is ordered by last update, newest first', () {
    final HistorySections s = groupHistory(<InvoiceRecord>[
      base('a', created: 1),
      base('b', created: 3),
      base('c', created: 2),
    ]);
    expect(ids(s.attention), <String>['b', 'c', 'a']);
  });

  test('saved invoices are ordered by when they were saved', () {
    final HistorySections s = groupHistory(<InvoiceRecord>[
      saved('old', savedAt: 5),
      saved('new', savedAt: 9),
      saved('mid', savedAt: 7),
    ]);
    expect(ids(s.saved), <String>['new', 'mid', 'old']);
  });

  test('ties break by id, so the order is stable', () {
    final HistorySections s = groupHistory(<InvoiceRecord>[
      base('b'),
      base('a'),
    ]);
    expect(ids(s.attention), <String>['a', 'b']);
  });

  test('deleted records are ignored', () {
    final HistorySections s = groupHistory(<InvoiceRecord>[
      base('gone').markDeleted(at(2)),
      saved('gone-saved', savedAt: 3).markDeleted(at(4)),
      base('kept'),
    ]);
    expect(ids(s.attention), <String>['kept']);
    expect(s.saved, isEmpty);
  });

  test('the result lists cannot be modified', () {
    final HistorySections s = groupHistory(<InvoiceRecord>[base('a')]);
    expect(() => s.attention.add(base('x')), throwsUnsupportedError);
  });
}
