import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/core/theme/app_theme.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/invoice_validator.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/history_cubit.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/capture_status_views.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/extraction_failure_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/history_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/home_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/invoice_detail_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/preview_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/processing_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/review_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/saved_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/scan_guidance_sheet.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/stage_progress.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

class Env {
  const Env(
    this.name,
    this.size, {
    this.dark = false,
    this.rtl = false,
    this.scale = 1,
  });

  final String name;
  final Size size;
  final bool dark;
  final bool rtl;
  final double scale;
}

const List<Env> envs = <Env>[
  Env('phone', Size(390, 844)),
  Env('small phone, double text, dark', Size(320, 568), dark: true, scale: 2),
  Env('right-to-left', Size(390, 844), rtl: true),
  Env('landscape phone', Size(844, 390), scale: 1.3),
  Env('tablet, right-to-left, dark', Size(1024, 768),
      dark: true, rtl: true, scale: 1.5),
];

const List<String> pages = <String>['managed/a_0.jpg', 'managed/a_1.jpg'];
final DateTime today = DateTime.utc(2026, 11, 8);
final List<HistoryCubit> cubits = <HistoryCubit>[];

InvoiceRecord base(String id) => InvoiceRecord.queued(
      id: id,
      imagePaths: <String>['managed/${id}_0.jpg'],
      now: testT0,
    );

InvoiceRecord saved(String id, String vendor) {
  final Invoice inv = sampleInvoice(vendor: vendor);
  return base(id)
      .markExtracting(testT0)
      .markNeedsReview(inv, testT0)
      .markSaved(inv, testT0.add(const Duration(minutes: 1)));
}

List<InvoiceRecord> records() => <InvoiceRecord>[
      base('p'),
      saved('s1', 'Acme'),
    ];

typedef Build = Widget Function();

final List<(String, Build)> screens = <(String, Build)>[
  ('HomeScreen', () => HomeScreen(
        watchRecent: () => Stream<List<InvoiceRecord>>.value(records()),
        onScan: () {},
        onImport: () {},
        onShowTips: () {},
        onViewAll: () {},
        onOpenInvoice: (InvoiceRecord _) {},
      )),
  ('PreviewScreen', () => PreviewScreen(
        pagePaths: pages,
        onRead: () {},
        onRetake: () {},
        onDiscard: () {},
      )),
  ('CaptureProgressView', () => CaptureProgressView(onCancel: () {})),
  ('CaptureFailureView', () => CaptureFailureView(
        reason: CaptureFailureReason.tooManyPages,
        maxPages: 5,
        onRetry: () {},
        onDone: () {},
      )),
  ('ProcessingScreen', () => ProcessingScreen(
        stage: ProcessingStage.reading,
        pagePaths: pages,
        onCancel: () {},
      )),
  ('ExtractionFailureScreen', () => ExtractionFailureScreen(
        state: const InvoiceExtractionFailure(
          recordId: 'a',
          pagePaths: pages,
          source: ScanSource.camera,
          kind: InvoiceErrorKind.emptyResponse,
          canRetry: true,
          suggestsRetake: true,
        ),
        onRetry: () {},
        onRetake: () {},
        onKeep: () {},
        onDiscard: () {},
      )),
  ('ReviewScreen', () {
    final Invoice invoice = sampleInvoice().copyWith(
      total: () => usd(3400),
      currencyAssumed: true,
    );
    return ReviewScreen(
      state: InvoiceReviewing(
        recordId: 'r',
        pagePaths: pages,
        invoice: invoice,
        warnings: validateInvoice(invoice, today: today),
      ),
      newLineId: () => 'n',
      now: () => today,
      onChange: (Invoice Function(Invoice) _) {},
      onSave: () {},
      onDiscard: () {},
    );
  }),
  ('SavedScreen', () => SavedScreen(
        invoice: sampleInvoice(),
        onDone: () {},
        onScanAnother: () {},
      )),
  ('HistoryScreen', () {
    final HistoryCubit cubit = HistoryCubit(
      watchLive: () => Stream<List<InvoiceRecord>>.value(records()),
      deleteInvoice: (String _) async => DeleteOutcome.deleted,
    );
    cubits.add(cubit);
    return BlocProvider<HistoryCubit>.value(
      value: cubit,
      child: HistoryScreen(
        onResume: (InvoiceRecord _) {},
        onOpenSaved: (InvoiceRecord _) {},
      ),
    );
  }),
  ('InvoiceDetailScreen', () => InvoiceDetailScreen(
        record: saved('d', 'Acme'),
        onDelete: () async => DeleteOutcome.deleted,
      )),
  ('ScanGuidanceSheet', () => const Scaffold(
        body: SingleChildScrollView(child: ScanGuidanceSheet(showStart: true)),
      )),
];

Future<void> showScreen(WidgetTester tester, Build build, Env env) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = env.size;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  await pumpLocalized(
    tester,
    build(),
    reduceMotion: true,
    textScale: env.scale,
    theme: env.dark ? AppTheme.dark : AppTheme.light,
    textDirection: env.rtl ? TextDirection.rtl : TextDirection.ltr,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() async {
    for (final HistoryCubit c in cubits) {
      await c.close();
    }
    cubits.clear();
  });

  group('every screen renders without errors in every environment', () {
    for (final Env env in envs) {
      for (final (String name, Build build) in screens) {
        testWidgets('$name, ${env.name}', (WidgetTester tester) async {
          await showScreen(tester, build, env);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
