import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:invoice_scanner/core/design_system/fade_in_up.dart';
import 'package:invoice_scanner/core/theme/app_colors.dart';
import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/core/theme/app_typography.dart';
import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/validation/validation_warning.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/currency.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/iso_date.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/money.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/commit_fields.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/currency_picker.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/field_notes.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/field_validity.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/line_item_card.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/zoomable_pages.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

typedef InvoiceChange = void Function(Invoice Function(Invoice current) change);

/// The confirmation screen: every extracted field is editable, findings sit
/// under the field they concern, and saving is never blocked by warnings.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    required this.state,
    required this.newLineId,
    required this.onChange,
    required this.onSave,
    required this.onDiscard,
    this.now = DateTime.now,
    super.key,
  });

  final InvoiceReviewing state;
  final IdGenerator newLineId;

  /// Asks for a change to be applied to the CURRENT invoice.
  final InvoiceChange onChange;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final DateTime Function() now;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final FieldValidity _validity = FieldValidity();
  bool _scanExpanded = true;

  @override
  void dispose() {
    _validity.dispose();
    super.dispose();
  }

  void _change(Invoice Function(Invoice current) change) =>
      widget.onChange(change);

  Map<FieldRef, List<ValidationWarning>> _group() {
    final Map<FieldRef, List<ValidationWarning>> map =
        <FieldRef, List<ValidationWarning>>{};
    for (final ValidationWarning w in widget.state.warnings) {
      map.putIfAbsent(w.field, () => <ValidationWarning>[]).add(w);
    }
    return map;
  }

  void _addLine() {
    _change(
      (Invoice inv) => inv.copyWith(
        lineItems: <InvoiceLineItem>[
          ...inv.lineItems,
          InvoiceLineItem(id: widget.newLineId()),
        ],
      ),
    );
  }

  void _removeLine(int index, InvoiceLineItem item) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    _change(
      (Invoice inv) => inv.copyWith(
        lineItems: <InvoiceLineItem>[
          for (final InvoiceLineItem i in inv.lineItems)
            if (i.id != item.id) i,
        ],
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.lineRemovedNotice(index + 1)),
          action: SnackBarAction(
            label: l10n.undoAction,
            onPressed: () => _change((Invoice inv) {
              if (inv.lineItems.any((InvoiceLineItem i) => i.id == item.id)) {
                return inv;
              }
              final List<InvoiceLineItem> lines = <InvoiceLineItem>[
                ...inv.lineItems,
              ]..insert(math.min(index, inv.lineItems.length), item);
              return inv.copyWith(lineItems: lines);
            }),
          ),
        ),
      );
  }

  Future<void> _pickDate(Invoice invoice) async {
    final DateTime today = dateOnly(widget.now());
    final DateTime last = today.add(const Duration(days: 365));
    final DateTime first = DateTime.utc(2000);
    DateTime initial = invoice.invoiceDate ?? today;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    final DateTime date = dateOnly(picked);
    _change((Invoice inv) => inv.copyWith(invoiceDate: () => date));
  }

  Future<void> _pickCurrency(Invoice invoice) async {
    final Currency? picked = await showCurrencyPicker(
      context,
      current: invoice.currency,
    );
    if (picked == null || !mounted) return;
    _change((Invoice inv) => inv.withCurrency(picked));
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            ScanViewerScreen(pagePaths: widget.state.pagePaths),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Invoice invoice = widget.state.invoice;
    final Map<FieldRef, List<ValidationWarning>> grouped = _group();
    final int warningCount = widget.state.warnings
        .where((ValidationWarning w) => w.severity == WarningSeverity.warning)
        .length;

    Widget notes(FieldRef ref) => FieldNotes(
      warnings: grouped[ref] ?? const <ValidationWarning>[],
      currencyCode: invoice.currency.code,
      onChange: _change,
    );

    Widget buildForm({Widget? panel}) => _FormBody(
      invoice: invoice,
      warningCount: warningCount,
      notes: notes,
      validity: _validity,
      onChange: _change,
      onAddLine: _addLine,
      onRemoveLine: _removeLine,
      onPickDate: () => _pickDate(invoice),
      onPickCurrency: () => _pickCurrency(invoice),
      panel: panel,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onDiscard,
          tooltip: l10n.discardAction,
          icon: const Icon(Icons.close),
        ),
        title: Text(l10n.reviewTitle),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide =
                constraints.maxWidth >= AppSizes.reviewTwoPaneMinWidth;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      child: _WideScanPanel(
                        pagePaths: widget.state.pagePaths,
                        onFullScreen: _openFullScreen,
                      ),
                    ),
                  ),
                  Expanded(child: buildForm()),
                ],
              );
            }
            return buildForm(
              panel: _NarrowScanPanel(
                pagePaths: widget.state.pagePaths,
                expanded: _scanExpanded,
                onToggle: () => setState(() => _scanExpanded = !_scanExpanded),
                onFullScreen: _openFullScreen,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _SaveBar(
        invoice: invoice,
        warningCount: warningCount,
        validity: _validity,
        onSave: widget.onSave,
      ),
    );
  }
}

// --- form ------------------------------------------------------------------

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.invoice,
    required this.warningCount,
    required this.notes,
    required this.validity,
    required this.onChange,
    required this.onAddLine,
    required this.onRemoveLine,
    required this.onPickDate,
    required this.onPickCurrency,
    this.panel,
  });

  final Invoice invoice;
  final int warningCount;
  final Widget Function(FieldRef ref) notes;
  final FieldValidity validity;
  final InvoiceChange onChange;
  final VoidCallback onAddLine;
  final void Function(int index, InvoiceLineItem item) onRemoveLine;
  final VoidCallback onPickDate;
  final VoidCallback onPickCurrency;
  final Widget? panel;

  AmountField _money({
    required String part,
    required String label,
    required Money? value,
    required Invoice Function(Invoice, Money?) set,
    TextInputAction action = TextInputAction.next,
  }) {
    final Key key = ValueKey<String>('field:$part:${invoice.currency.code}');
    return AmountField.money(
      key: key,
      label: label,
      money: value,
      currency: invoice.currency,
      textInputAction: action,
      onChanged: (DecimalValue? d) => onChange(
        (Invoice inv) => set(
          inv,
          d == null ? null : Money.tryFromDecimalExact(d, inv.currency),
        ),
      ),
      onValidityChanged: (bool valid) => validity.report(key, valid: valid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    const SizedBox gap = SizedBox(height: AppSpacing.md);

    final Widget details = _SectionCard(
      title: l10n.reviewSectionDetails,
      children: <Widget>[
        TextEntryField(
          key: const ValueKey<String>('field:vendor'),
          label: l10n.vendorLabel,
          value: invoice.vendorName,
          capitalization: TextCapitalization.words,
          onChanged: (String? v) =>
              onChange((Invoice inv) => inv.copyWith(vendorName: () => v)),
        ),
        notes(const FieldRef(InvoiceField.vendorName)),
        gap,
        TextEntryField(
          key: const ValueKey<String>('field:number'),
          label: l10n.invoiceNumberLabel,
          value: invoice.invoiceNumber,
          capitalization: TextCapitalization.characters,
          onChanged: (String? v) =>
              onChange((Invoice inv) => inv.copyWith(invoiceNumber: () => v)),
        ),
        notes(const FieldRef(InvoiceField.invoiceNumber)),
        gap,
        _PickerField(
          label: l10n.invoiceDateLabel,
          value: invoice.invoiceDate == null
              ? null
              : DateFormat.yMMMd(locale).format(invoice.invoiceDate!),
          placeholder: l10n.dateNotSet,
          icon: Icons.calendar_today_outlined,
          onTap: onPickDate,
        ),
        notes(const FieldRef(InvoiceField.invoiceDate)),
        gap,
        _PickerField(
          label: l10n.currencyLabel,
          value: invoice.currency.code,
          placeholder: '',
          icon: Icons.expand_more,
          onTap: onPickCurrency,
        ),
        notes(const FieldRef(InvoiceField.currency)),
      ],
    );

    final Widget lines = _SectionCard(
      title: l10n.reviewSectionLines,
      children: <Widget>[
        notes(const FieldRef(InvoiceField.lineItems)),
        for (int i = 0; i < invoice.lineItems.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
            child: LineItemCard(
              key: ValueKey<String>('line:${invoice.lineItems[i].id}'),
              index: i,
              item: invoice.lineItems[i],
              currency: invoice.currency,
              notes: notes,
              validity: validity,
              onChange: onChange,
              onRemove: () => onRemoveLine(i, invoice.lineItems[i]),
            ),
          ),
        if (invoice.lineItems.isNotEmpty) ...<Widget>[
          gap,
          _LineSum(invoice: invoice),
        ],
        gap,
        OutlinedButton.icon(
          onPressed: onAddLine,
          icon: const Icon(Icons.add),
          label: Text(l10n.addLineAction),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
          ),
        ),
      ],
    );

    final Widget totals = _SectionCard(
      title: l10n.reviewSectionTotals,
      children: <Widget>[
        _money(
          part: 'subtotal',
          label: l10n.subtotalLabel,
          value: invoice.subtotal,
          set: (Invoice inv, Money? m) => inv.copyWith(subtotal: () => m),
        ),
        notes(const FieldRef(InvoiceField.subtotal)),
        gap,
        _money(
          part: 'tax',
          label: l10n.taxLabel,
          value: invoice.tax,
          set: (Invoice inv, Money? m) => inv.copyWith(tax: () => m),
        ),
        notes(const FieldRef(InvoiceField.tax)),
        gap,
        _money(
          part: 'total',
          label: l10n.totalLabel,
          value: invoice.total,
          set: (Invoice inv, Money? m) => inv.copyWith(total: () => m),
          action: TextInputAction.done,
        ),
        notes(const FieldRef(InvoiceField.total)),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: ListView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          children: <Widget>[
            ?panel,
            if (panel != null) gap,
            FadeInUp(child: _Summary(warningCount: warningCount)),
            gap,
            FadeInUp(delay: AppMotion.fast, child: details),
            gap,
            FadeInUp(delay: AppMotion.base, child: lines),
            gap,
            FadeInUp(delay: AppMotion.base, child: totals),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.warningCount});

  final int warningCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSemanticColors semantic = AppSemanticColors.of(context);
    final bool clear = warningCount == 0;
    final Color background = clear
        ? semantic.successContainer
        : semantic.warningContainer;
    final Color foreground = clear
        ? semantic.onSuccessContainer
        : semantic.onWarningContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                clear
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.warningsCount(warningCount),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: foreground),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Looks like a text field, opens a picker when tapped.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String shown = value ?? placeholder;
    return Semantics(
      button: true,
      label: '$label, $shown',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: Icon(icon)),
          child: Text(
            shown,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: value == null ? scheme.onSurfaceVariant : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The running sum of the line totals, so a change is visible as it is made.
class _LineSum extends StatelessWidget {
  const _LineSum({required this.invoice});

  final Invoice invoice;

  Money? _sum() {
    Money? sum = Money.zero(invoice.currency);
    for (final InvoiceLineItem item in invoice.lineItems) {
      final Money? total = item.lineTotal;
      if (total == null || sum == null) return null;
      sum = sum.plus(total);
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final Money? sum = _sum();
    final TextTheme text = Theme.of(context).textTheme;

    if (sum == null) {
      return Text(
        l10n.lineItemsSumUnknown,
        style: text.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final String amount = MoneyFormatter(locale).format(sum);
    return Semantics(
      container: true,
      label: '${l10n.lineItemsSumLabel} $amount',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(l10n.lineItemsSumLabel, style: text.bodyMedium)),
          Text(amount, style: AppMoneyStyles.of(context).title),
        ],
      ),
    );
  }
}

// --- scan panels -------------------------------------------------------------

class _NarrowScanPanel extends StatelessWidget {
  const _NarrowScanPanel({
    required this.pagePaths,
    required this.expanded,
    required this.onToggle,
    required this.onFullScreen,
  });

  final List<String> pagePaths;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                const ExcludeSemantics(child: Icon(Icons.image_outlined)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.scanPanelTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onFullScreen,
                  tooltip: l10n.scanPanelFullScreen,
                  icon: const Icon(Icons.fullscreen),
                ),
                IconButton(
                  onPressed: onToggle,
                  tooltip: expanded ? l10n.scanPanelHide : l10n.scanPanelShow,
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppMotion.resolve(context, AppMotion.base),
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: expanded
                ? SizedBox(
                    height: AppSizes.scanPanelHeight,
                    child: ZoomablePages(
                      pagePaths: pagePaths,
                      padding: AppSpacing.md,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _WideScanPanel extends StatelessWidget {
  const _WideScanPanel({required this.pagePaths, required this.onFullScreen});

  final List<String> pagePaths;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.scanPanelTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onFullScreen,
                  tooltip: l10n.scanPanelFullScreen,
                  icon: const Icon(Icons.fullscreen),
                ),
              ],
            ),
          ),
          Expanded(
            child: ZoomablePages(pagePaths: pagePaths, padding: AppSpacing.md),
          ),
        ],
      ),
    );
  }
}

/// The scan on its own, for reading small print.
class ScanViewerScreen extends StatelessWidget {
  const ScanViewerScreen({required this.pagePaths, super.key});

  final List<String> pagePaths;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanPanelTitle)),
      body: SafeArea(child: ZoomablePages(pagePaths: pagePaths)),
    );
  }
}

// --- save bar ----------------------------------------------------------------

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.invoice,
    required this.warningCount,
    required this.validity,
    required this.onSave,
  });

  final Invoice invoice;
  final int warningCount;
  final FieldValidity validity;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();
    final Money? total = invoice.total;
    final String totalText = total == null
        ? l10n.recentNoTotal
        : MoneyFormatter(locale).format(total);

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: AppElevation.overlay,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: ListenableBuilder(
                listenable: validity,
                builder: (BuildContext context, Widget? _) {
                  final bool blocked = validity.hasInvalid;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Semantics(
                              container: true,
                              label: '${l10n.totalLabel} $totalText',
                              excludeSemantics: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    l10n.totalLabel,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    totalText,
                                    style: AppMoneyStyles.of(context).display,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            l10n.warningsCount(warningCount),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (blocked) ...<Widget>[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.saveBlockedInvalid,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.error),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      FilledButton.icon(
                        onPressed: blocked ? null : onSave,
                        icon: const Icon(Icons.check),
                        label: Text(l10n.confirmAndSaveAction),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppSizes.minTouchTarget,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
