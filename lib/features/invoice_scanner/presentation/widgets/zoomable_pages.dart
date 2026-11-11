import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Swipeable, pinch-zoomable pages. Swiping is disabled while a page is
/// zoomed so panning never turns the page. Needs a bounded height.
class ZoomablePages extends StatefulWidget {
  const ZoomablePages({
    required this.pagePaths,
    this.padding = AppSpacing.lg,
    super.key,
  });

  final List<String> pagePaths;
  final double padding;

  @override
  State<ZoomablePages> createState() => _ZoomablePagesState();
}

class _ZoomablePagesState extends State<ZoomablePages> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int total = widget.pagePaths.length;
    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: total,
                onPageChanged: (int index) => setState(() {
                  _page = index;
                  _zoomed = false;
                }),
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: EdgeInsetsDirectional.all(widget.padding),
                    child: _ZoomablePage(
                      key: ValueKey<String>(widget.pagePaths[index]),
                      path: widget.pagePaths[index],
                      semanticLabel: l10n.previewPageSemantics(
                        index + 1,
                        total,
                      ),
                      onZoomChanged: (bool zoomed) {
                        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                      },
                    ),
                  );
                },
              ),
              if (total > 1)
                PositionedDirectional(
                  top: AppSpacing.xl,
                  start: AppSpacing.xl,
                  child: _CounterPill(
                    text: l10n.previewPageCounter(_page + 1, total),
                  ),
                ),
            ],
          ),
        ),
        if (total > 1) _Dots(count: total, index: _page),
      ],
    );
  }
}

class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    required this.path,
    required this.semanticLabel,
    required this.onZoomChanged,
    super.key,
  });

  final String path;
  final String semanticLabel;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  /// Decode at up to this width so zooming stays legible without holding a
  /// full-resolution bitmap per page.
  static const int _maxDecodeWidth = 2400;

  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    final bool zoomed =
        _transform.value.getMaxScaleOnAxis() > AppZoom.min + AppZoom.epsilon;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: ClipRRect(
        borderRadius: AppRadii.lgAll,
        child: ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: AppZoom.min,
            maxScale: AppZoom.max,
            panEnabled: _zoomed,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double dpr = MediaQuery.devicePixelRatioOf(context);
                final int decodeWidth = math.min(
                  _maxDecodeWidth,
                  math.max(1, (constraints.maxWidth * dpr * 2).round()),
                );
                return Image.file(
                  File(widget.path),
                  fit: BoxFit.contain,
                  cacheWidth: decodeWidth,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (BuildContext c, Object e, StackTrace? s) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.broken_image_outlined,
                            size: AppSizes.iconLg,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.previewImageUnavailable),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
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
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: scheme.onInverseSurface),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Duration duration = AppMotion.resolve(context, AppMotion.fast);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: AppMotion.standard,
              margin: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xxs,
              ),
              width: i == index ? AppSizes.pageDotActive : AppSizes.pageDot,
              height: AppSizes.pageDot,
              decoration: BoxDecoration(
                color: i == index ? scheme.primary : scheme.outlineVariant,
                borderRadius: AppRadii.pillAll,
              ),
            ),
        ],
      ),
    );
  }
}
