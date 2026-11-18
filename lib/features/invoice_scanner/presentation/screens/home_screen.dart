import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:invoice_scanner/core/design_system/fade_in_up.dart';
import 'package:invoice_scanner/core/design_system/pressable.dart';
import 'package:invoice_scanner/core/theme/app_colors.dart';
import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/core/theme/app_typography.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.watchRecent,
    required this.onScan,
    required this.onImport,
    required this.onShowTips,
    required this.onViewAll,
    this.onOpenInvoice,
    super.key,
  });

  final Stream<List<InvoiceRecord>> Function() watchRecent;
  final VoidCallback onScan;
  final VoidCallback onImport;
  final VoidCallback onShowTips;
  final VoidCallback onViewAll;
  final void Function(InvoiceRecord record)? onOpenInvoice;

  static const int maxRecent = 5;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<InvoiceRecord>> _recent = widget.watchRecent();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              children: <Widget>[
                FadeInUp(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(l10n.appTitle, style: text.titleLarge),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onShowTips,
                        tooltip: l10n.homeTipsTitle,
                        icon: const Icon(Icons.lightbulb_outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeInUp(
                  delay: AppMotion.fast,
                  child: _HeroCard(
                    onScan: widget.onScan,
                    onImport: widget.onImport,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeInUp(
                  delay: AppMotion.base,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.recentInvoicesTitle,
                            style: text.titleMedium,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onViewAll,
                        child: Text(l10n.historyViewAll),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeInUp(
                  delay: AppMotion.base,
                  child: StreamBuilder<List<InvoiceRecord>>(
                    stream: _recent,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<InvoiceRecord>> snapshot,
                        ) {
                          final List<InvoiceRecord> items =
                              (snapshot.data ?? const <InvoiceRecord>[])
                                  .take(HomeScreen.maxRecent)
                                  .toList();
                          if (items.isEmpty) return const _EmptyRecent();
                          return Column(
                            children: <Widget>[
                              for (final InvoiceRecord record in items)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: _RecentTile(
                                    record: record,
                                    onOpen: widget.onOpenInvoice,
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onScan, required this.onImport});

  final VoidCallback onScan;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSemanticColors colors = AppSemanticColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    const Size fullWidth = Size.fromHeight(AppSizes.minTouchTarget);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.heroGradient,
        borderRadius: AppRadii.xlAll,
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.document_scanner_outlined,
                size: AppSizes.iconXl,
                color: colors.onHero,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.homeHeroTitle,
              style: text.headlineSmall?.copyWith(
                color: colors.onHero,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.homeHeroBody,
              style: text.bodyMedium?.copyWith(color: colors.onHero),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.scanInvoiceAction),
              style: FilledButton.styleFrom(
                backgroundColor: colors.onHero,
                foregroundColor: colors.heroEnd,
                minimumSize: fullWidth,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.importFromGallery),
              style: TextButton.styleFrom(
                foregroundColor: colors.onHero,
                minimumSize: fullWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.receipt_long_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.recentInvoicesEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.record, this.onOpen});

  final InvoiceRecord record;
  final void Function(InvoiceRecord record)? onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();

    final Invoice? invoice = record.invoice;
    final String? rawVendor = invoice?.vendorName?.trim();
    final String vendor = (rawVendor == null || rawVendor.isEmpty)
        ? l10n.invoiceUnnamed
        : rawVendor;
    final DateTime? date = invoice?.invoiceDate;
    final String dateText = date == null
        ? l10n.recentNoDate
        : DateFormat.yMMMd(locale).format(date);
    final Money? total = invoice?.total;
    final String totalText = total == null
        ? l10n.recentNoTotal
        : MoneyFormatter(locale).format(total);
    final String label = '$vendor, $dateText, $totalText';

    final Widget card = Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    vendor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    dateText,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(totalText, style: AppMoneyStyles.of(context).title),
          ],
        ),
      ),
    );

    final void Function(InvoiceRecord)? open = onOpen;
    if (open == null) {
      return Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: card,
      );
    }
    return Pressable(
      semanticLabel: label,
      onPressed: () => open(record),
      borderRadius: AppRadii.lgAll,
      child: card,
    );
  }
}
