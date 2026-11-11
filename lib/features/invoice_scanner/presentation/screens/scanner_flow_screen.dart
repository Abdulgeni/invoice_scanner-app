import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/capture_status_views.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/extraction_failure_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/flow_stage_views.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/home_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/preview_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/processing_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/review_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/saved_screen.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/scan_guidance_sheet.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/stage_progress.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Routes every bloc state to a screen and owns the navigation-level
/// behavior: scan guidance, discard confirmation, the system back button,
/// notices, the "checking totals" completion beat, and lifecycle forwarding.
class ScannerFlowScreen extends StatefulWidget {
  const ScannerFlowScreen({
    required this.watchRecent,
    required this.newLineId,
    super.key,
  });

  final Stream<List<InvoiceRecord>> Function() watchRecent;

  /// Creates ids for lines the user adds in the review.
  final IdGenerator newLineId;

  @override
  State<ScannerFlowScreen> createState() => _ScannerFlowScreenState();
}

class _ScannerFlowScreenState extends State<ScannerFlowScreen>
    with WidgetsBindingObserver {
  final ScanGuidancePolicy _guidance = ScanGuidancePolicy();
  ScanSource _lastSource = ScanSource.camera;

  InvoiceScannerState? _last;

  /// Set while the "checking totals" beat is showing after a finished read.
  List<String>? _finishingPages;
  Timer? _beat;

  InvoiceScannerBloc get _bloc => context.read<InvoiceScannerBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _last = context.read<InvoiceScannerBloc>().state;
  }

  @override
  void dispose() {
    _beat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _bloc.add(const AppPaused());
  }

  // --- actions ---------------------------------------------------------

  Future<void> _scan() async {
    if (_guidance.shouldShow) {
      final bool go = await showScanGuidanceSheet(context, showStart: true);
      if (!mounted || !go) return;
      _guidance.markShown();
    }
    _start(ScanSource.camera);
  }

  void _scanAnother() {
    _bloc.add(const ResetRequested());
    unawaited(_scan());
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

  /// The system back button.
  void _onBack(InvoiceScannerState state) {
    switch (state) {
      case InvoiceScannerInitial():
        break;
      case InvoiceCapturing() || InvoicePreprocessing() || InvoiceExtracting():
        _bloc.add(const CancelRequested());
      case InvoiceCaptureFailure() || InvoiceSaved():
        _bloc.add(const ResetRequested());
      case InvoiceExtractionFailure():
        _bloc.add(const KeepImageRequested());
      case InvoiceImageReady() || InvoiceReviewing():
        _confirmDiscard();
      case InvoiceSaving():
        break;
    }
  }

  // --- state changes ---------------------------------------------------

  void _onState(BuildContext context, InvoiceScannerState state) {
    final InvoiceScannerState? previous = _last;
    _last = state;

    if (previous is InvoiceExtracting &&
        state is InvoiceReviewing &&
        !AppMotion.reduced(context)) {
      _startBeat(previous.pagePaths);
    } else if (state is! InvoiceReviewing) {
      _endBeat();
    }

    if (state is InvoiceReviewing &&
        state.notice != null &&
        (previous is! InvoiceReviewing || previous.notice != state.notice)) {
      _showNotice(context, state.notice!);
    }
  }

  void _startBeat(List<String> pages) {
    _beat?.cancel();
    setState(() => _finishingPages = pages);
    _beat = Timer(AppMotion.completionBeat, () {
      if (mounted) setState(() => _finishingPages = null);
    });
  }

  void _endBeat() {
    _beat?.cancel();
    _beat = null;
    if (_finishingPages != null) setState(() => _finishingPages = null);
  }

  void _showNotice(BuildContext context, ReviewNotice notice) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String message = switch (notice) {
      ReviewNotice.saveFailed => l10n.saveFailedNotice,
      ReviewNotice.draftNotSaved => l10n.draftNotSavedNotice,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- routing ---------------------------------------------------------

  /// Identifies the screen, not the data: edits inside one stage keep the
  /// same key (no transition replay), and optimizing and reading share the
  /// processing screen so the sweep continues while only the stage changes.
  String _stageOf(InvoiceScannerState state) => switch (state) {
    InvoiceScannerInitial() => 'home',
    InvoiceCapturing() => 'capturing',
    InvoicePreprocessing() || InvoiceExtracting() => 'processing',
    InvoiceCaptureFailure() => 'captureFailure',
    InvoiceImageReady() => 'preview',
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
        onCancel: () => _bloc.add(const CancelRequested()),
      ),
      InvoicePreprocessing(:final pagePaths) => ProcessingScreen(
        stage: ProcessingStage.optimizing,
        pagePaths: pagePaths,
        onCancel: () => _bloc.add(const CancelRequested()),
      ),
      InvoiceExtracting(:final pagePaths) => ProcessingScreen(
        stage: ProcessingStage.reading,
        pagePaths: pagePaths,
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
      final InvoiceExtractionFailure failure => ExtractionFailureScreen(
        state: failure,
        onRetry: () => _bloc.add(const ExtractRequested()),
        onRetake: () => _bloc.add(const RetakeRequested()),
        onKeep: () => _bloc.add(const KeepImageRequested()),
        onDiscard: _confirmDiscard,
      ),
      final InvoiceReviewing review => ReviewScreen(
        state: review,
        newLineId: widget.newLineId,
        onChange: (Invoice Function(Invoice) t) => _bloc.add(InvoiceChanged(t)),
        onSave: () => _bloc.add(const SaveRequested()),
        onDiscard: _confirmDiscard,
      ),
      InvoiceSaving() => const SavingView(),
      InvoiceSaved(:final Invoice? invoice) => SavedScreen(
        invoice: invoice,
        onDone: () => _bloc.add(const ResetRequested()),
        onScanAnother: _scanAnother,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoiceScannerBloc, InvoiceScannerState>(
      listener: _onState,
      builder: (BuildContext context, InvoiceScannerState state) {
        final List<String>? finishing = _finishingPages;
        final String key;
        final Widget view;
        if (finishing != null && state is InvoiceReviewing) {
          key = 'processing';
          view = ProcessingScreen(
            stage: ProcessingStage.validating,
            pagePaths: finishing,
          );
        } else {
          key = _stageOf(state);
          view = _viewFor(context, state);
        }

        return PopScope(
          canPop: state is InvoiceScannerInitial,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) _onBack(state);
          },
          child: AnimatedSwitcher(
            duration: AppMotion.resolve(context, AppMotion.base),
            switchInCurve: AppMotion.standard,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(key: ValueKey<String>(key), child: view),
          ),
        );
      },
    );
  }
}
