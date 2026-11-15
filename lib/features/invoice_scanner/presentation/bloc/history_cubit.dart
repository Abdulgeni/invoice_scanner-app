import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/entities/history_sections.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/usecases/delete_invoice.dart';

/// What the history screens need from the app, without the use cases.
class HistoryDependencies {
  const HistoryDependencies({required this.watchLive, required this.delete});

  final Stream<List<InvoiceRecord>> Function() watchLive;
  final Future<DeleteOutcome> Function(String id) delete;
}

enum HistoryNotice { deleteFailed }

sealed class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

final class HistoryFailed extends HistoryState {
  const HistoryFailed();
}

final class HistoryLoaded extends HistoryState {
  const HistoryLoaded(this.sections, {this.notice});

  final HistorySections sections;

  /// A one-shot message; cleared with [HistoryCubit.noticeShown].
  final HistoryNotice? notice;

  @override
  List<Object?> get props => <Object?>[sections, notice];
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({
    required Stream<List<InvoiceRecord>> Function() watchLive,
    required Future<DeleteOutcome> Function(String id) deleteInvoice,
  }) : _watchLive = watchLive,
       _delete = deleteInvoice,
       super(const HistoryLoading()) {
    _subscribe();
  }

  final Stream<List<InvoiceRecord>> Function() _watchLive;
  final Future<DeleteOutcome> Function(String id) _delete;

  StreamSubscription<List<InvoiceRecord>>? _subscription;
  HistorySections _sections = HistorySections.empty;

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _watchLive().listen(
      (List<InvoiceRecord> records) {
        if (isClosed) return;
        _sections = groupHistory(records);
        emit(HistoryLoaded(_sections));
      },
      onError: (Object _) {
        if (!isClosed) emit(const HistoryFailed());
      },
    );
  }

  void retry() {
    emit(const HistoryLoading());
    _subscribe();
  }

  /// The list updates itself from the stream; only a failure is reported.
  Future<void> delete(String id) async {
    final DeleteOutcome outcome = await _delete(id);
    if (isClosed) return;
    if (outcome == DeleteOutcome.storageUnavailable) {
      emit(HistoryLoaded(_sections, notice: HistoryNotice.deleteFailed));
    }
  }

  void noticeShown() {
    final HistoryState s = state;
    if (s is HistoryLoaded && s.notice != null) emit(HistoryLoaded(s.sections));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
