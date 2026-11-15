import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/datasources/connectivity_plus_monitor.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/datasources/document_scanner_datasource.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/db/app_database.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/db/open_app_database.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/image/isolate_image_preprocessor.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/image/managed_image_store.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/repositories/drift_invoice_repository.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/analytics/scan_analytics.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/capture_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extract_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extraction_queue_runner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/process_extraction_queue.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/recover_interrupted_work.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/save_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/update_review_draft.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/iso_date.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/history_cubit.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';

/// Everything the UI needs, built once at startup.
class AppScope {
  AppScope({
    required this.createBloc,
    required this.watchRecent,
    required this.newId,
    required this.history,
    required this.kickQueue,
    required this.dispose,
  });

  final InvoiceScannerBloc Function() createBloc;
  final Stream<List<InvoiceRecord>> Function() watchRecent;
  final String Function() newId;
  final HistoryDependencies history;

  /// Asks the offline queue to look for work (call when the app resumes).
  final void Function() kickQueue;
  final Future<void> Function() dispose;
}

/// Builds everything the UI needs. [extractorBuilder] supplies the real
/// extractor; without it the demo extractor (sample data, no network) is
/// used so the UI can be tried before Firebase is set up.
Future<AppScope> createAppScope({
  InvoiceExtractor Function(String Function() newId)? extractorBuilder,
  Currency fallbackCurrency = Currency.usd,
}) async {
  final Directory support = await getApplicationSupportDirectory();
  final Directory imageDir = Directory(
    '${support.path}${Platform.pathSeparator}invoice_images',
  )..createSync(recursive: true);

  final AppDatabase db = openAppDatabase();
  final DriftInvoiceRepository repository = DriftInvoiceRepository(
    db,
    managedDirPath: imageDir.path,
  );
  final ManagedImageStore store = ManagedImageStore(managedDir: imageDir);
  final Clock clock = () => DateTime.now().toUtc();
  const Uuid uuid = Uuid();
  String newId() => uuid.v4();
  const ScanAnalytics analytics = NoopScanAnalytics();

  try {
    await RecoverInterruptedWork(
      repository: repository,
      imageStore: store,
      clock: clock,
    )();
  } on Exception {
    // Continue launching; recovery runs again next time.
  }

  final CaptureInvoice capture = CaptureInvoice(
    scanner: CunningDocumentScannerDatasource(),
    preprocessor: IsolateImagePreprocessor(outputDir: imageDir),
    repository: repository,
    imageStore: store,
    clock: clock,
    newId: newId,
  );
  final ExtractInvoice extract = ExtractInvoice(
    repository: repository,
    extractor: extractorBuilder?.call(newId) ?? DemoInvoiceExtractor(newId: newId),
    imageStore: store,
    analytics: analytics,
    clock: clock,
  );
  final SaveInvoice save = SaveInvoice(
    repository: repository,
    imageStore: store,
    analytics: analytics,
    clock: clock,
  );
  final DeleteInvoice delete = DeleteInvoice(
    repository: repository,
    imageStore: store,
    clock: clock,
  );
  final UpdateReviewDraft draft = UpdateReviewDraft(
    repository: repository,
    clock: clock,
  );

  // Recovery above has finished, so the queue may start.
  final ConnectivityPlusMonitor monitor = ConnectivityPlusMonitor();
  final ProcessExtractionQueue queue = ProcessExtractionQueue(
    repository: repository,
    extract: extract,
    connectivity: monitor,
    fallbackCurrency: () => fallbackCurrency,
  );
  final ExtractionQueueRunner runner =
      ExtractionQueueRunner(pass: queue.runOnce, connectivity: monitor)
        ..start();

  return AppScope(
    createBloc: () => InvoiceScannerBloc(
      captureInvoice: capture,
      extractInvoice: extract,
      saveInvoice: save,
      deleteInvoice: delete,
      updateReviewDraft: draft,
      loadRecord: repository.get,
      clock: clock,
      fallbackCurrency: () => fallbackCurrency,
    ),
    watchRecent: repository.watchSaved,
    newId: newId,
    history: HistoryDependencies(
      watchLive: repository.watchLive,
      delete: delete.call,
    ),
    kickQueue: runner.kick,
    dispose: () async {
      await runner.stop();
      await db.close();
    },
  );
}

/// Returns fixed sample data after a short delay. Whole-number amounts, so
/// it works for any currency's minor-unit exponent.
class DemoInvoiceExtractor implements InvoiceExtractor {
  DemoInvoiceExtractor({
    required String Function() newId,
    this.delay = const Duration(milliseconds: 1800),
  }) : _newId = newId;

  final String Function() _newId;
  final Duration delay;

  @override
  Future<Invoice> extract({
    required List<String> imagePaths,
    required Currency fallbackCurrency,
    required CancellationToken cancel,
  }) async {
    await cancel.race(Future<void>.delayed(delay));
    Money amount(String whole) => Money.tryFromDecimalExact(
          DecimalValue.tryParse(whole)!,
          fallbackCurrency,
        )!;
    return Invoice(
      currency: fallbackCurrency,
      currencyAssumed: true,
      vendorName: 'Demo Café',
      invoiceNumber: 'D-1001',
      invoiceDate: dateOnly(DateTime.now()),
      lineItems: <InvoiceLineItem>[
        InvoiceLineItem(
          id: _newId(),
          description: 'Coffee beans',
          quantity: DecimalValue.fromInt(2),
          unitPrice: DecimalValue.tryParse('10'),
          lineTotal: amount('20'),
        ),
        InvoiceLineItem(
          id: _newId(),
          description: 'Espresso machine service',
          quantity: DecimalValue.fromInt(1),
          unitPrice: DecimalValue.tryParse('35'),
          lineTotal: amount('35'),
        ),
      ],
      subtotal: amount('55'),
      tax: amount('5'),
      total: amount('60'),
    );
  }
}
