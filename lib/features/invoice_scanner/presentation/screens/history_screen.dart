import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/core/theme/app_typography.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/history_sections.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/history_cubit.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/record_labels.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/delete_confirmation.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/privacy_sheet.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Every live invoice: unfinished ones first, then saved ones. Needs a
/// [HistoryCubit] above it.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    required this.onResume,
    required this.onOpenSaved,
    super.key,
  });

  /// Continue an unfinished invoice where it left off.
  final void Function(InvoiceRecord record) onResume;

  /// Show a saved invoice.
  final void Function(InvoiceRecord record) onOpenSaved;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return BlocConsumer<HistoryCubit, HistoryState>(
      listenWhen: (HistoryState previous, HistoryState current) =>
          current is HistoryLoaded &&
          current.notice != null &&
          !(previous is HistoryLoaded && previous.notice == current.notice),
      listener: (BuildContext context, HistoryState state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.deleteFailedNotice)));
        context.read<HistoryCubit>().noticeShown();
      },
      builder: (BuildContext context, HistoryState state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.historyTitle),
            actions: <Widget>[
              IconButton(
                onPressed: () => showPrivacySheet(context),
                tooltip: l10n.privacyTooltip,
                icon: const Icon(Icons.shield_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: switch (state) {
              HistoryLoading() =>
                const Center(child: CircularProgressIndicator()),
              HistoryFailed() => _FailedView(
                  onRetry: () => context.read<HistoryCubit>().retry(),
                ),
              HistoryLoaded(:final HistorySections sections) =>
                sections.isEmpty
                    ? const _EmptyView()
                    : _HistoryList(
                        sections: sections,
                        onResume: onResume,
                        onOpenSaved: onOpenSaved,
                      ),
            },
          ),
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.sections,
    required this.onResume,
    required this.onOpenSaved,
  });

  final HistorySections sections;
  final void Function(InvoiceRecord record) onResume;
  final void Function(InvoiceRecord record) onOpenSaved;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Widget> children = <Widget>[];

    void section(String title, List<InvoiceRecord> items, bool saved) {
      if (items.isEmpty) return;
      children.add(_SectionHeader(title));
      for (final InvoiceRecord record in items) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: _HistoryTile(
              key: ValueKey<String>('history:${record.id}'),
              record: record,
              onOpen: () => saved ? onOpenSaved(record) : onResume(record),
              onDelete: () async {
                if (await confirmDeleteInvoice(context) && context.mounted) {
                  await context.read<HistoryCubit>().delete(record.id);
                }
              },
            ),
          ),
        );
      }
    }

    section(l10n.historyAttentionTitle, sections.attention, false);
    section(l10n.historySavedTitle, sections.saved, true);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: ListView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          children: children,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final InvoiceRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();

    final bool saved = record.status == InvoiceStatus.saved;
    final String title = recordTitle(l10n, record);
    final DateTime? date = record.invoice?.invoiceDate;
    final String dateText =
        date == null ? l10n.recentNoDate : DateFormat.yMMMd(locale).format(date);
    final String subtitle = saved ? dateText : recordStatus(l10n, record);
    final String? hint = saved ? null : l10n.historyContinueHint;
    final Money? total = record.invoice?.total;
    final String? amount = total != null
        ? MoneyFormatter(locale).format(total)
        : (saved ? l10n.recentNoTotal : null);

    final String label = <String?>[title, subtitle, hint, amount]
        .whereType<String>()
        .join(', ');

    return Card(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              button: true,
              container: true,
              label: label,
              excludeSemantics: true,
              onTap: onOpen,
              child: InkWell(
                onTap: onOpen,
                borderRadius: AppRadii.lgAll,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      _Thumb(
                        path: record.imagePaths.isEmpty
                            ? null
                            : record.imagePaths.first,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium,
                            ),
                            Text(
                              subtitle,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (hint != null)
                              Text(
                                hint,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (amount != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            amount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppMoneyStyles.of(context).title,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: l10n.deleteInvoiceTooltip(title),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? file = path;
    final Widget icon = Icon(
      Icons.receipt_long_outlined,
      color: scheme.onSurfaceVariant,
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadii.mdAll,
        child: SizedBox.square(
          dimension: 56,
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: file == null
                ? icon
                : Image.file(
                    File(file),
                    fit: BoxFit.cover,
                    cacheWidth: (56 * 2).round(),
                    errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                        icon,
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.receipt_long_outlined,
                size: AppSizes.iconXl,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.historyEmptyTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.historyEmptyBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.historyLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ),
      ),
    );
  }
}
