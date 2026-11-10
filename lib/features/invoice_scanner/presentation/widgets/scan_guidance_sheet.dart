import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/invoice_limits.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Remembers, for this app session only, that the user has seen the
/// guidance. A persisted version needs a preferences store.
class ScanGuidancePolicy {
  bool _shown = false;

  bool get shouldShow => !_shown;

  void markShown() => _shown = true;
}

/// Returns true when the user chose to start scanning. With
/// `showStart: false` the sheet is informational and always returns false.
Future<bool> showScanGuidanceSheet(
  BuildContext context, {
  required bool showStart,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
    builder: (BuildContext context) => ScanGuidanceSheet(showStart: showStart),
  );
  return result ?? false;
}

class ScanGuidanceSheet extends StatelessWidget {
  const ScanGuidanceSheet({required this.showStart, super.key});

  final bool showStart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    final List<(IconData, String)> tips = <(IconData, String)>[
      (Icons.light_mode_outlined, l10n.guidanceLighting),
      (Icons.layers_outlined, l10n.guidanceFlat),
      (Icons.crop_free, l10n.guidanceFrame),
      (
        Icons.collections_outlined,
        l10n.guidanceMultiPage(InvoiceLimits.maxPages),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.guidanceTitle, style: text.titleLarge),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (IconData icon, String tip) in tips)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
              child: _Tip(icon: icon, text: tip),
            ),
          if (showStart) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.guidanceStart),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
              child: Icon(
                icon,
                size: AppSizes.iconMd,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }
}
