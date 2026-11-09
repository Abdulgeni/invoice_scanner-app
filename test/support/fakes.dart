import 'dart:async';

import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/analytics/scan_analytics.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_preprocessor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_store.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';

final DateTime testT0 = DateTime.utc(2026, 11, 8, 10);

Clock fixedClock(DateTime time) => () => time;

Money usd(int minorUnits) =>
    Money.tryFromMinorUnits(minorUnits, Currency.usd)!;

/// Consistent invoice: lines 1000 + 2000 = subtotal 3000, +300 tax = 3300.
Invoice sampleInvoice({String vendor = 'Acme'}) {
  return Invoice(
    currency: Currency.usd,
    vendorName: vendor,
    invoiceNumber: 'A-1',
    invoiceDate: DateTime.utc(2026, 11, 1),
    lineItems: <InvoiceLineItem>[
      InvoiceLineItem(
        id: 'l1',
        description: 'Widget',
        quantity: DecimalValue.fromInt(2),
        unitPrice: DecimalValue.tryParse('5.00')!,
        lineTotal: usd(1000),
      ),
      InvoiceLineItem(
        id: 'l2',
        description: 'Gadget',
        quantity: DecimalValue.fromInt(1),
        unitPrice: DecimalValue.tryParse('20.00')!,
        lineTotal: usd(2000),
      ),
    ],
    subtotal: usd(3000),
    tax: usd(300),
    total: usd(3300),
  );
}

/// In-memory repository following the contract: `mutate` is read-modify-write
/// with no write when `change` throws.
class FakeInvoiceRepository implements InvoiceRepository {
  final Map<String, InvoiceRecord> rows = <String, InvoiceRecord>{};

  /// Counts every `mutate` call, successful or not.
  int mutateCalls = 0;

  /// 1-based `mutate` call numbers that fail with a storage error.
  final Set<int> failMutateCalls = <int>{};
  bool failInsert = false;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<bool> insertIfAbsent(InvoiceRecord record) async {
    if (failInsert) {
      throw const InvoiceFailure(InvoiceErrorKind.unknown, debugCode: 'db');
    }
    if (rows.containsKey(record.id)) return false;
    rows[record.id] = record;
    _changes.add(null);
    return true;
  }

  @override
  Future<InvoiceRecord?> get(String id) async => rows[id];

  @override
  Future<InvoiceRecord?> mutate(
    String id,
    InvoiceRecord Function(InvoiceRecord current) change,
  ) async {
    mutateCalls++;
    if (failMutateCalls.contains(mutateCalls)) {
      throw Exception('storage unavailable');
    }
    final InvoiceRecord? current = rows[id];
    if (current == null) return null;
    final InvoiceRecord next = change(current);
    if (next.id != id) throw ArgumentError('mutate must keep the id');
    rows[id] = next;
    _changes.add(null);
    return next;
  }

  @override
  Future<List<InvoiceRecord>> listByStatus(Set<InvoiceStatus> statuses) async {
    final List<InvoiceRecord> found = rows.values
        .where((InvoiceRecord r) => !r.isDeleted && statuses.contains(r.status))
        .toList();
    found.sort((InvoiceRecord a, InvoiceRecord b) {
      final int byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return found;
  }

  List<InvoiceRecord> _saved() {
    final List<InvoiceRecord> saved = rows.values
        .where(
          (InvoiceRecord r) =>
              !r.isDeleted && r.status == InvoiceStatus.saved,
        )
        .toList();
    saved.sort(
      (InvoiceRecord a, InvoiceRecord b) => b.savedAt!.compareTo(a.savedAt!),
    );
    return saved;
  }

  @override
  Stream<List<InvoiceRecord>> watchSaved() async* {
    yield _saved();
    await for (final _ in _changes.stream) {
      yield _saved();
    }
  }
}

class FakeImageStore implements ImageStore {
  /// Existing files, as exact path strings.
  final Set<String> files = <String>{};
  final List<String> deleted = <String>[];
  int cleanScannerTempCalls = 0;
  Set<String>? lastKeep;

  @override
  Future<bool> allExist(List<String> paths) async =>
      paths.isNotEmpty && paths.every(files.contains);

  @override
  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final String path in paths) {
      files.remove(path);
      deleted.add(path);
    }
  }

  @override
  Future<void> cleanScannerTemp() async {
    cleanScannerTempCalls++;
  }

  @override
  Future<void> deleteManagedFilesExcept(Set<String> keep) async {
    lastKeep = Set<String>.of(keep);
    files.removeWhere((String path) => !keep.contains(path));
  }
}

class FakeDocumentScanner implements DocumentScanner {
  /// Null simulates the user cancelling.
  List<String>? result = <String>['scan/1.jpg'];
  Object? error;
  int calls = 0;
  ScanSource? lastSource;
  int? lastMaxPages;

  /// When set, `scan` waits on it (to keep the scanner "open").
  Completer<List<String>?>? gate;

  @override
  Future<List<String>?> scan({
    required ScanSource source,
    required int maxPages,
  }) async {
    calls++;
    lastSource = source;
    lastMaxPages = maxPages;
    final Object? e = error;
    if (e != null) throw e;
    final Completer<List<String>?>? g = gate;
    if (g != null) return g.future;
    return result;
  }
}

class FakeImagePreprocessor implements ImagePreprocessor {
  FakeImagePreprocessor(this.store);

  final FakeImageStore store;
  Object? error;
  int calls = 0;

  /// Runs after outputs are written, before returning (to cancel mid-flight).
  void Function()? afterCompress;

  /// When set, `compress` waits on it after writing its outputs.
  Completer<void>? gate;

  @override
  Future<List<String>> compress({
    required String invoiceId,
    required List<String> sourcePaths,
    required CancellationToken cancel,
  }) async {
    calls++;
    final Object? e = error;
    if (e != null) throw e;
    final List<String> out = <String>[
      for (int i = 0; i < sourcePaths.length; i++)
        'managed/${invoiceId}_$i.jpg',
    ];
    store.files.addAll(out);
    afterCompress?.call();
    await gate?.future;
    return out;
  }
}

class FakeInvoiceExtractor implements InvoiceExtractor {
  Invoice? result;
  Object? error;

  /// When set, `extract` waits on it (to hold a call in flight).
  Completer<Invoice>? gate;
  int calls = 0;
  List<String>? lastPaths;
  Currency? lastFallback;

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    calls++;
    lastPaths = imagePaths;
    lastFallback = fallbackCurrency;
    final Object? e = error;
    if (e != null) throw e;
    final Completer<Invoice>? g = gate;
    if (g != null) return g.future;
    return result ?? sampleInvoice();
  }
}

class RecordingAnalytics implements ScanAnalytics {
  final List<(Duration, int, InvoiceErrorKind?)> extractions =
      <(Duration, int, InvoiceErrorKind?)>[];
  final List<InvoiceField> corrections = <InvoiceField>[];
  final List<int> saves = <int>[];

  @override
  void extractionFinished({
    required Duration captureToResult,
    required int attempt,
    InvoiceErrorKind? errorKind,
  }) {
    extractions.add((captureToResult, attempt, errorKind));
  }

  @override
  void fieldCorrected(InvoiceField field) => corrections.add(field);

  @override
  void invoiceSaved({required int correctedFieldCount}) =>
      saves.add(correctedFieldCount);
}
