import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

enum ProcessingStage { optimizing, reading, validating }

class StageProgress extends StatelessWidget {
  const StageProgress({required this.stage, super.key});

  final ProcessingStage stage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool reduced = AppMotion.reduced(context);

    final int total = ProcessingStage.values.length;
    final String label = switch (stage) {
      ProcessingStage.optimizing => l10n.stageOptimizing,
      ProcessingStage.reading => l10n.stageReading,
      ProcessingStage.validating => l10n.stageValidating,
    };
    final String step = l10n.stageStepCounter(stage.index + 1, total);

    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.stageSemantics(step, label),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AnimatedSwitcher(
            duration: AppMotion.resolve(context, AppMotion.base),
            child: Text(
              label,
              key: ValueKey<ProcessingStage>(stage),
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            step,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (int i = 0; i < total; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Segment(
                    value: i < stage.index
                        ? 1.0
                        : i == stage.index
                        ? (reduced ? 0.5 : null)
                        : 0.0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: AppRadii.pillAll,
      child: LinearProgressIndicator(
        value: value,
        minHeight: AppSizes.stageSegmentHeight,
        backgroundColor: scheme.outlineVariant,
        color: scheme.primary,
      ),
    );
  }
}
