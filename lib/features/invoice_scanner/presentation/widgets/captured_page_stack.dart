import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/scan_sweep.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// The captured pages as a small stack of paper, the first page on top.
/// Always shows something: while an image loads or if it cannot be read, the
/// card stays on screen. Fills the width (or height) it is given.
class CapturedPageStack extends StatelessWidget {
  const CapturedPageStack({
    required this.pagePaths,
    this.sweeping = false,
    this.dimmed = false,
    super.key,
  });

  final List<String> pagePaths;

  /// Draws the scan sweep over the top page.
  final bool sweeping;

  /// Fades the stack back (used behind an error card).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int count = pagePaths.length;
    final int behind = math.max(
      0,
      math.min(count, AppSizes.pageStackMaxVisible) - 1,
    );
    const double offset = AppSizes.pageStackOffset;
    final String pages = l10n.capturedPagesLabel(math.max(count, 1));

    return Semantics(
      image: true,
      label: l10n.capturedInvoiceSemantics(pages),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          end: behind * offset,
          bottom: behind * offset,
        ),
        child: AspectRatio(
          aspectRatio: AppSizes.pageAspectRatio,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int i = behind; i >= 1; i--)
                PositionedDirectional(
                  top: i * offset,
                  start: i * offset,
                  end: -i * offset,
                  bottom: -i * offset,
                  child: const _BackCard(),
                ),
              Positioned.fill(
                child: _FrontCard(
                  path: pagePaths.isEmpty ? null : pagePaths.first,
                  sweeping: sweeping,
                  dimmed: dimmed,
                ),
              ),
              if (count > 1)
                PositionedDirectional(
                  bottom: AppSpacing.md,
                  start: AppSpacing.md,
                  child: _CountPill(text: pages),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({
    required this.path,
    required this.sweeping,
    required this.dimmed,
  });

  final String? path;
  final bool sweeping;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? file = path;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadii.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.lgAll,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: scheme.surfaceContainerHigh),
            if (file != null)
              ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final double dpr = MediaQuery.devicePixelRatioOf(context);
                    final int decodeWidth = math.min(
                      1600,
                      math.max(1, (c.maxWidth * dpr).round()),
                    );
                    return Image.file(
                      File(file),
                      fit: BoxFit.contain,
                      cacheWidth: decodeWidth,
                      filterQuality: FilterQuality.medium,
                      frameBuilder: (
                        BuildContext context,
                        Widget child,
                        int? frame,
                        bool wasSynchronouslyLoaded,
                      ) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration:
                              AppMotion.resolve(context, AppMotion.base),
                          curve: AppMotion.standard,
                          child: child,
                        );
                      },
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stack,
                      ) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: AppSizes.iconLg,
                            color: scheme.onSurfaceVariant,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            if (dimmed)
              ColoredBox(
                color: scheme.surface.withValues(alpha: AppOpacity.dimScrim),
              ),
            if (sweeping) const ScanSweep(),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadii.pillAll,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onInverseSurface),
          ),
        ),
      ),
    );
  }
}
