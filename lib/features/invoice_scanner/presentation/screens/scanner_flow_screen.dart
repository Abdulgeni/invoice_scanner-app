import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/capture_status_views.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/flow_stage_views.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/home_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/preview_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/scan_guidance_sheet.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Routes every bloc state to a screen and owns the navigation-level
/// behavior: scan guidance, discard confirmation, the system back button,
/// notices, and app-lifecycle forwarding.
class ScannerFlowScreen extends StatefulWidget {
  const ScannerFlowScreen({required this.watchRecent, super.key});

  final Stream<List<InvoiceRecord>> Function() watchRecent;

  @override
  State<ScannerFlowScreen> createState() => _ScannerFlowScreenState();
}

class _ScannerFlowScreenState extends State<ScannerFlowScreen>
    with WidgetsBindingObserver {
  final ScanGuidancePolicy _guidance = ScanGuidancePolicy();
  ScanSource _lastSource = ScanSource.camera;

  InvoiceScannerBloc get _bloc => context.read<InvoiceScannerBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _bloc.add(const AppPaused());
  }

  Future<void> _scan() async {
    if (_guidance.shouldShow) {
      final bool go = await showScanGuidanceSheet(context, showStart: true);
      if (!mounted || !go) return;
      _guidance.markShown();
    }
    _start(ScanSource.camera);
  }

  void _start(ScanSource source) {
    _lastSource = source;
    _bloc.add(ScanRequested(source));
  }

  Future<void> _confirmDiscard() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.discardConfirmTitle),
        content: Text(l10n.discardConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discardAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _bloc.add(const DiscardRequested());
  }

  String _stageOf(InvoiceScannerState state) => switch (state) {
    InvoiceScannerInitial() => 'home',
    InvoiceCapturing() => 'capturing',
    InvoicePreprocessing() => 'optimizing',
    InvoiceCaptureFailure() => 'captureFailure',
    InvoiceImageReady() => 'preview',
    InvoiceExtracting() => 'reading',
    InvoiceExtractionFailure() => 'failure',
    InvoiceReviewing() => 'review',
    InvoiceSaving() => 'saving',
    InvoiceSaved() => 'saved',
  };

  Widget _viewFor(BuildContext context, InvoiceScannerState state) {
    return switch (state) {
      InvoiceScannerInitial() => HomeScreen(
        watchRecent: widget.watchRecent,
        onScan: _scan,
        onImport: () => _start(ScanSource.gallery),
        onShowTips: () => showScanGuidanceSheet(context, showStart: false),
      ),
      InvoiceCapturing() => CaptureProgressView(
        stage: CaptureStage.opening,
        onCancel: () => _bloc.add(const CancelRequested()),
      ),
      InvoicePreprocessing() => CaptureProgressView(
        stage: CaptureStage.optimizing,
        onCancel: () => _bloc.add(const CancelRequested()),
      ),
      InvoiceCaptureFailure(:final reason, :final maxPages) =>
        CaptureFailureView(
          reason: reason,
          maxPages: maxPages,
          onRetry: () => _start(_lastSource),
          onDone: () => _bloc.add(const ResetRequested()),
        ),
      InvoiceImageReady(:final pagePaths) => PreviewScreen(
        pagePaths: pagePaths,
        onRead: () => _bloc.add(const ExtractRequested()),
        onRetake: () => _bloc.add(const RetakeRequested()),
        onDiscard: _confirmDiscard,
      ),
      InvoiceExtracting(:final pagePaths) => ExtractingView(
        firstPagePath: pagePaths.isEmpty ? null : pagePaths.first,
        onCancel: () => _bloc.add(const CancelRequested()),
      ),
      final InvoiceExtractionFailure failure => ExtractionFailureView(
        state: failure,
        onRetry: () => _bloc.add(const ExtractRequested()),
        onRetake: () => _bloc.add(const RetakeRequested()),
        onKeep: () => _bloc.add(const KeepImageRequested()),
      ),
      final InvoiceReviewing review => ReviewingStubView(
        state: review,
        onSave: () => _bloc.add(const SaveRequested()),
        onDiscard: _confirmDiscard,
      ),
      InvoiceSaving() => const SavingView(),
      InvoiceSaved() => SavedView(
        onDone: () => _bloc.add(const ResetRequested()),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvoiceScannerBloc, InvoiceScannerState>(
      listenWhen: (InvoiceScannerState previous, InvoiceScannerState current) {
        if (current is! InvoiceReviewing || current.notice == null) {
          return false;
        }
        return previous is! InvoiceReviewing ||
            previous.notice != current.notice;
      },
      listener: (BuildContext context, InvoiceScannerState state) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        final ReviewNotice? notice = (state as InvoiceReviewing).notice;
        final String? message = switch (notice) {
          ReviewNotice.saveFailed => l10n.saveFailedNotice,
          ReviewNotice.draftNotSaved => l10n.draftNotSavedNotice,
          null => null,
        };
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: BlocBuilder<InvoiceScannerBloc, InvoiceScannerState>(
        builder: (BuildContext context, InvoiceScannerState state) {
          final bool previewing = state is InvoiceImageReady;
          return PopScope(
            canPop: !previewing,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (!didPop && previewing) _confirmDiscard();
            },
            child: AnimatedSwitcher(
              duration: AppMotion.resolve(context, AppMotion.base),
              switchInCurve: AppMotion.standard,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<String>(_stageOf(state)),
                child: _viewFor(context, state),
              ),
            ),
          );
        },
      ),
    );
  }
}
