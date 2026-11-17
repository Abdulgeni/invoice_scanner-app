import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_edits.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/document_scanner.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/capture_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/extract_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/save_invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/update_review_draft.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/invoice_validator.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';

part 'invoice_scanner_event.dart';
part 'invoice_scanner_state.dart';

/// Debug codes the bloc itself produces.
abstract final class BlocDebugCodes {
  static const String settleTimeout = 'settle_timeout';
  static const String storageUnavailable = 'storage_unavailable';
}

/// Drives the scan flow. Long-running work is delegated to use cases; the
/// bloc owns cancellation, the "abandoned flow" guard, draft autosave and
/// the mapping from outcomes to UI states.
///
/// Event handlers run concurrently (bloc's default), which is what lets
/// [CancelRequested] act while an extraction is still awaited. Every handler
/// that awaits checks [_stale] before it emits, so a flow the user has
/// abandoned (discard, retake, opening another record) can never write to
/// the screen afterwards.
class InvoiceScannerBloc
    extends Bloc<InvoiceScannerEvent, InvoiceScannerState> {
  InvoiceScannerBloc({
    required CaptureInvoice captureInvoice,
    required ExtractInvoice extractInvoice,
    required SaveInvoice saveInvoice,
    required DeleteInvoice deleteInvoice,
    required UpdateReviewDraft updateReviewDraft,
    required Future<InvoiceRecord?> Function(String id) loadRecord,
    required Clock clock,
    required Currency Function() fallbackCurrency,
    this.draftDebounce = const Duration(milliseconds: 600),
    this.settlePollInterval = const Duration(milliseconds: 500),
    this.settleTimeout = const Duration(minutes: 3),
    Future<void> Function(Duration)? sleep,
  }) : _captureInvoice = captureInvoice,
       _extractInvoice = extractInvoice,
       _saveInvoice = saveInvoice,
       _deleteInvoice = deleteInvoice,
       _updateReviewDraft = updateReviewDraft,
       _loadRecord = loadRecord,
       _clock = clock,
       _fallbackCurrency = fallbackCurrency,
       _sleep = sleep ?? Future<void>.delayed,
       super(const InvoiceScannerInitial()) {
    on<ScanRequested>(_onScanRequested);
    on<ExtractRequested>(_onExtractRequested);
    on<CancelRequested>(_onCancelRequested);
    on<RetakeRequested>(_onRetakeRequested);
    on<DiscardRequested>(_onDiscardRequested);
    on<KeepImageRequested>(_onKeepImageRequested);
    on<ResetRequested>(_onResetRequested);
    on<RecordOpened>(_onRecordOpened);
    on<InvoiceEdited>(_onInvoiceEdited);
    on<FixApplied>(_onFixApplied);
    on<UnreadableDismissed>(_onUnreadableDismissed);
    on<SaveRequested>(_onSaveRequested);
    on<InvoiceChanged>(_onInvoiceChanged);
    on<AppPaused>(_onAppPaused);
    on<_DraftTick>(_onDraftTick);
  }

  final CaptureInvoice _captureInvoice;
  final ExtractInvoice _extractInvoice;
  final SaveInvoice _saveInvoice;
  final DeleteInvoice _deleteInvoice;
  final UpdateReviewDraft _updateReviewDraft;
  final Future<InvoiceRecord?> Function(String id) _loadRecord;
  final Clock _clock;
  final Currency Function() _fallbackCurrency;
  final Future<void> Function(Duration) _sleep;

  /// Quiet period after the last edit before the draft is written.
  final Duration draftDebounce;

  /// How often to look at a record another worker is extracting.
  final Duration settlePollInterval;
  final Duration settleTimeout;

  /// Bumped whenever the current flow is abandoned.
  int _epoch = 0;
  CancellationToken? _token;
  Timer? _draftTimer;

  bool _stale(int epoch) => epoch != _epoch || isClosed;

  CancellationToken _newToken() => _token = CancellationToken();

  void _abandonFlow() {
    _epoch++;
    _token?.cancel();
    _token = null;
    _draftTimer?.cancel();
    _draftTimer = null;
  }

  // --- capture ---------------------------------------------------------

  Future<void> _onScanRequested(
    ScanRequested event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    if (state is! InvoiceScannerInitial && state is! InvoiceCaptureFailure) {
      return;
    }
    await _runCapture(event.source, emit);
  }

  Future<void> _runCapture(
    ScanSource source,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final int epoch = _epoch;
    final CancellationToken token = _newToken();
    emit(InvoiceCapturing(source: source));

    final CaptureResult result = await _captureInvoice(
      source: source,
      cancel: token,
      onPagesAccepted: (List<String> pages) {
        if (!_stale(epoch) && !emit.isDone) {
          emit(
            InvoicePreprocessing(
              source: source,
              pagePaths: List<String>.unmodifiable(pages),
            ),
          );
        }
      },
    );

    if (_stale(epoch)) {
      if (result is CaptureSucceeded) {
        unawaited(_deleteQuietly(result.record.id));
      }
      return;
    }
    if (identical(_token, token)) _token = null;

    switch (result) {
      case CaptureSucceeded(:final InvoiceRecord record):
        emit(
          InvoiceImageReady(
            recordId: record.id,
            pagePaths: record.imagePaths,
            source: source,
          ),
        );
      case CaptureCancelled():
        emit(const InvoiceScannerInitial());
      case CaptureTooManyPages(:final int maxPages):
        emit(
          InvoiceCaptureFailure(
            reason: CaptureFailureReason.tooManyPages,
            maxPages: maxPages,
          ),
        );
      case CaptureFailed(:final InvoiceFailure failure):
        emit(InvoiceCaptureFailure(reason: _captureReason(failure)));
    }
  }

  CaptureFailureReason _captureReason(InvoiceFailure failure) {
    return switch (failure.debugCode) {
      DebugCodes.cameraPermissionDenied =>
        CaptureFailureReason.cameraPermissionDenied,
      DebugCodes.scannerUnavailable => CaptureFailureReason.scannerUnavailable,
      DebugCodes.rowCorrupt =>
        CaptureFailureReason.storageUnavailable,
      _ => CaptureFailureReason.unknown,
    };
  }

  // --- extraction ------------------------------------------------------

  Future<void> _onExtractRequested(
    ExtractRequested event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final InvoiceScannerState current = state;
    String? recordId;
    List<String>? pages;
    ScanSource? source;
    if (current is InvoiceImageReady) {
      recordId = current.recordId;
      pages = current.pagePaths;
      source = current.source;
    } else if (current is InvoiceExtractionFailure && current.canRetry) {
      recordId = current.recordId;
      pages = current.pagePaths;
      source = current.source;
    }
    if (recordId == null || pages == null || source == null) return;
    await _runExtraction(recordId, pages, source, emit);
  }

  Future<void> _runExtraction(
    String recordId,
    List<String> pages,
    ScanSource source,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final int epoch = _epoch;
    final CancellationToken token = _newToken();
    emit(
      InvoiceExtracting(recordId: recordId, pagePaths: pages, source: source),
    );

    final ExtractionOutcome outcome = await _extractInvoice(
      recordId: recordId,
      fallbackCurrency: _fallbackCurrency(),
      cancel: token,
    );
    if (_stale(epoch)) return;

    switch (outcome) {
      case ExtractionSucceeded(:final InvoiceRecord record):
        _releaseToken(token);
        emit(_fromRecord(record, source: source));
      case ExtractionFailed(
        :final InvoiceRecord record,
        :final InvoiceErrorKind kind,
        :final String? debugCode,
      ):
        _releaseToken(token);
        if (kind == InvoiceErrorKind.cancelled) {
          emit(
            InvoiceImageReady(
              recordId: recordId,
              pagePaths: pages,
              source: source,
            ),
          );
        } else {
          emit(
            _failureState(
              record: record,
              source: source,
              kind: kind,
              debugCode: debugCode,
            ),
          );
        }
      case ExtractionSkipped(:final ExtractionSkipReason reason):
        switch (reason) {
          case ExtractionSkipReason.notFound:
            _releaseToken(token);
            emit(const InvoiceScannerInitial());
          case ExtractionSkipReason.storageUnavailable:
            _releaseToken(token);
            emit(
              InvoiceExtractionFailure(
                recordId: recordId,
                pagePaths: pages,
                source: source,
                kind: InvoiceErrorKind.unknown,
                debugCode: BlocDebugCodes.storageUnavailable,
                canRetry: true,
                suggestsRetake: false,
              ),
            );
          case ExtractionSkipReason.notExtractable:
            await _settleAndEmit(
              recordId: recordId,
              pages: pages,
              source: source,
              epoch: epoch,
              token: token,
              emit: emit,
            );
            _releaseToken(token);
        }
    }
  }

  void _releaseToken(CancellationToken token) {
    if (identical(_token, token)) _token = null;
  }

  Future<void> _settleAndEmit({
    required String recordId,
    required List<String> pages,
    required ScanSource source,
    required int epoch,
    required CancellationToken token,
    required Emitter<InvoiceScannerState> emit,
  }) async {
    final int maxPolls = math.max(
      1,
      settleTimeout.inMicroseconds ~/
          math.max(1, settlePollInterval.inMicroseconds),
    );
    for (int i = 0; i < maxPolls; i++) {
      if (_stale(epoch)) return;
      if (token.isCancelled) {
        emit(
          InvoiceImageReady(
            recordId: recordId,
            pagePaths: pages,
            source: source,
          ),
        );
        return;
      }
      final InvoiceRecord? current = await _tryLoad(recordId);
      if (_stale(epoch)) return;
      if (current == null || current.isDeleted) {
        emit(const InvoiceScannerInitial());
        return;
      }
      if (current.status != InvoiceStatus.extracting) {
        emit(_fromRecord(current, source: source));
        return;
      }
      await _sleep(settlePollInterval);
    }
    if (_stale(epoch)) return;
    emit(
      InvoiceExtractionFailure(
        recordId: recordId,
        pagePaths: pages,
        source: source,
        kind: InvoiceErrorKind.timeout,
        debugCode: BlocDebugCodes.settleTimeout,
        canRetry: true,
        suggestsRetake: false,
      ),
    );
  }

  void _onCancelRequested(
    CancelRequested event,
    Emitter<InvoiceScannerState> emit,
  ) {
    final InvoiceScannerState s = state;
    if (s is InvoiceCapturing ||
        s is InvoicePreprocessing ||
        s is InvoiceExtracting) {
      _token?.cancel();
    }
  }

  // --- leaving or restarting a flow ------------------------------------

  Future<void> _onRetakeRequested(
    RetakeRequested event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final InvoiceScannerState s = state;
    final String? id = _recordIdOf(s);
    if (id == null || s is InvoiceExtracting || s is InvoiceSaving) return;
    final ScanSource source = _sourceOf(s) ?? ScanSource.camera;
    _abandonFlow();
    await _deleteQuietly(id);
    await _runCapture(source, emit);
  }

  Future<void> _onDiscardRequested(
    DiscardRequested event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final String? id = _recordIdOf(state);
    _abandonFlow();
    emit(const InvoiceScannerInitial());
    if (id != null) await _deleteQuietly(id);
  }

  void _onKeepImageRequested(
    KeepImageRequested event,
    Emitter<InvoiceScannerState> emit,
  ) {
    if (state is! InvoiceExtractionFailure) return;
    _abandonFlow();
    emit(const InvoiceScannerInitial());
  }

  void _onResetRequested(
    ResetRequested event,
    Emitter<InvoiceScannerState> emit,
  ) {
    final InvoiceScannerState s = state;
    if (s is! InvoiceSaved && s is! InvoiceCaptureFailure) return;
    _abandonFlow();
    emit(const InvoiceScannerInitial());
  }

  Future<void> _onRecordOpened(
    RecordOpened event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    _abandonFlow();
    final int epoch = _epoch;
    final InvoiceRecord? record = await _tryLoad(event.recordId);
    if (_stale(epoch)) return;
    if (record == null) {
      emit(const InvoiceScannerInitial());
      return;
    }
    emit(_fromRecord(record, source: ScanSource.camera));
    if (!record.isDeleted && record.status == InvoiceStatus.extracting) {
      final CancellationToken token = _newToken();
      await _settleAndEmit(
        recordId: record.id,
        pages: record.imagePaths,
        source: ScanSource.camera,
        epoch: epoch,
        token: token,
        emit: emit,
      );
      _releaseToken(token);
    }
  }

  // --- review ----------------------------------------------------------

  void _onInvoiceEdited(
    InvoiceEdited event,
    Emitter<InvoiceScannerState> emit,
  ) {
    final InvoiceScannerState s = state;
    if (s is InvoiceReviewing) _applyEdit(s, event.invoice, emit);
  }

  void _onFixApplied(FixApplied event, Emitter<InvoiceScannerState> emit) {
    final InvoiceScannerState s = state;
    if (s is InvoiceReviewing) {
      _applyEdit(s, applySuggestedFix(s.invoice, event.fix), emit);
    }
  }

  void _onUnreadableDismissed(
    UnreadableDismissed event,
    Emitter<InvoiceScannerState> emit,
  ) {
    final InvoiceScannerState s = state;
    if (s is InvoiceReviewing) {
      _applyEdit(s, dismissFlag(s.invoice, event.field), emit);
    }
  }

  void _applyEdit(
    InvoiceReviewing s,
    Invoice edited,
    Emitter<InvoiceScannerState> emit,
  ) {
    final Invoice next = pruneResolvedFlags(edited);
    if (next == s.invoice) return;
    emit(_reviewing(s.recordId, s.pagePaths, next));
    _scheduleDraft();
  }

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDebounce, () {
      if (!isClosed) add(const _DraftTick());
    });
  }

  Future<bool> _persistDraft(InvoiceReviewing s) {
    return _updateReviewDraft(recordId: s.recordId, invoice: s.invoice);
  }

  Future<void> _onDraftTick(
    _DraftTick event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final InvoiceScannerState s = state;
    if (s is! InvoiceReviewing) return;
    final int epoch = _epoch;
    final bool saved = await _persistDraft(s);
    if (saved || _stale(epoch)) return;
    final InvoiceScannerState now = state;
    if (now is InvoiceReviewing &&
        now.invoice == s.invoice &&
        now.notice == null) {
      emit(now.withNotice(ReviewNotice.draftNotSaved));
    }
  }

  Future<void> _onAppPaused(
    AppPaused event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final InvoiceScannerState s = state;
    if (s is! InvoiceReviewing) return;
    _draftTimer?.cancel();
    _draftTimer = null;
    final int epoch = _epoch;
    final bool saved = await _persistDraft(s);
    if (saved || _stale(epoch)) return;
    final InvoiceScannerState now = state;
    if (now is InvoiceReviewing && now.invoice == s.invoice) {
      emit(now.withNotice(ReviewNotice.draftNotSaved));
    }
  }

  void _onInvoiceChanged(
    InvoiceChanged event,
    Emitter<InvoiceScannerState> emit,
  ) {
    final InvoiceScannerState s = state;
    if (s is InvoiceReviewing) _applyEdit(s, event.transform(s.invoice), emit);
  }

  Future<void> _onSaveRequested(
    SaveRequested event,
    Emitter<InvoiceScannerState> emit,
  ) async {
    final InvoiceScannerState s = state;
    if (s is! InvoiceReviewing) return;
    final int epoch = _epoch;
    _draftTimer?.cancel();
    _draftTimer = null;
    emit(
      InvoiceSaving(
        recordId: s.recordId,
        pagePaths: s.pagePaths,
        invoice: s.invoice,
      ),
    );

    final SaveOutcome outcome = await _saveInvoice(
      recordId: s.recordId,
      confirmed: s.invoice,
    );
    if (_stale(epoch)) return;

    switch (outcome) {
      case SaveSucceeded():
        emit(InvoiceSaved(recordId: s.recordId, invoice: s.invoice));
      case SaveBlocked():
        emit(s.withNotice(ReviewNotice.saveFailed));
    }
  }

  // --- mapping ---------------------------------------------------------

  InvoiceReviewing _reviewing(
    String recordId,
    List<String> pages,
    Invoice invoice,
  ) {
    return InvoiceReviewing(
      recordId: recordId,
      pagePaths: pages,
      invoice: invoice,
      warnings: validateInvoice(invoice, today: _clock()),
    );
  }

  InvoiceExtractionFailure _failureState({
    required InvoiceRecord record,
    required ScanSource source,
    required InvoiceErrorKind kind,
    String? debugCode,
  }) {
    return InvoiceExtractionFailure(
      recordId: record.id,
      pagePaths: record.imagePaths,
      source: source,
      kind: kind,
      debugCode: debugCode,
      canRetry: kind.canRetrySameImage && debugCode != DebugCodes.imagesMissing,
      suggestsRetake: kind.suggestsRetake,
    );
  }

  InvoiceScannerState _fromRecord(
    InvoiceRecord record, {
    required ScanSource source,
  }) {
    if (record.isDeleted) return const InvoiceScannerInitial();
    switch (record.status) {
      case InvoiceStatus.needsReview:
        final Invoice? invoice = record.invoice;
        if (invoice == null) return const InvoiceScannerInitial();
        return _reviewing(record.id, record.imagePaths, invoice);
      case InvoiceStatus.failed:
        final InvoiceErrorKind kind =
            record.failureKind ?? InvoiceErrorKind.unknown;
        if (kind == InvoiceErrorKind.cancelled) {
          return InvoiceImageReady(
            recordId: record.id,
            pagePaths: record.imagePaths,
            source: source,
          );
        }
        return _failureState(record: record, source: source, kind: kind);
      case InvoiceStatus.pendingExtraction:
        return InvoiceImageReady(
          recordId: record.id,
          pagePaths: record.imagePaths,
          source: source,
        );
      case InvoiceStatus.extracting:
        return InvoiceExtracting(
          recordId: record.id,
          pagePaths: record.imagePaths,
          source: source,
        );
      case InvoiceStatus.saved:
        return InvoiceSaved(recordId: record.id, invoice: record.invoice);
    }
  }

  String? _recordIdOf(InvoiceScannerState s) => switch (s) {
    InvoiceImageReady(:final String recordId) => recordId,
    InvoiceExtracting(:final String recordId) => recordId,
    InvoiceExtractionFailure(:final String recordId) => recordId,
    InvoiceReviewing(:final String recordId) => recordId,
    InvoiceSaving(:final String recordId) => recordId,
    _ => null,
  };

  ScanSource? _sourceOf(InvoiceScannerState s) => switch (s) {
    InvoiceImageReady(:final ScanSource source) => source,
    InvoiceExtracting(:final ScanSource source) => source,
    InvoiceExtractionFailure(:final ScanSource source) => source,
    InvoiceCapturing(:final ScanSource source) => source,
    InvoicePreprocessing(:final ScanSource source) => source,
    _ => null,
  };

  Future<InvoiceRecord?> _tryLoad(String id) async {
    try {
      return await _loadRecord(id);
    } on Exception {
      return null;
    }
  }

  Future<void> _deleteQuietly(String id) async {
    try {
      await _deleteInvoice(id);
    } on Exception {
      // The record stays; the user can delete it from the history list.
    }
  }

  @override
  Future<void> close() {
    _draftTimer?.cancel();
    _token?.cancel();
    final InvoiceScannerState s = state;
    if (s is InvoiceReviewing) {
      unawaited(_persistDraft(s));
    }
    return super.close();
  }
}
