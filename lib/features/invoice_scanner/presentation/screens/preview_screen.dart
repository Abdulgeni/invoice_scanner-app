import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// The captured pages, waiting for the user's "Read invoice" or "Retake".
/// Pages swipe horizontally and pinch-zoom; swiping is disabled while a
/// page is zoomed so panning never changes the page.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    required this.pagePaths,
    required this.onRead,
    required this.onRetake,
    required this.onDiscard,
    super.key,
  });

  final List<String> pagePaths;
  final VoidCallback onRead;
  final VoidCallback onRetake;
  final VoidCallback onDiscard;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = widget.pagePaths.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onDiscard,
          tooltip: l10n.discardAction,
          icon: const Icon(Icons.close),
        ),
        title: Text(l10n.previewTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: Column(
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
                            padding: const EdgeInsetsDirectional.all(
                              AppSpacing.lg,
                            ),
                            child: _ZoomablePage(
                              key: ValueKey<String>(widget.pagePaths[index]),
                              path: widget.pagePaths[index],
                              semanticLabel: l10n.previewPageSemantics(
                                index + 1,
                                total,
                              ),
                              onZoomChanged: (bool zoomed) {
                                if (zoomed != _zoomed) {
                                  setState(() => _zoomed = zoomed);
                                }
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
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    l10n.previewHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onRetake,
                          icon: const Icon(Icons.replay),
                          label: Text(l10n.retakeAction),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.onRead,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(l10n.readInvoiceAction),
                        ),
                      ),
                    ],
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
  static const int _maxDecodeWidth = 2400;

  final TransformationController _transform = TransformationController();
  bool _zoomed = false;
  Uint8List? _bytes;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _load();
  }

  @override
  void didUpdateWidget(_ZoomablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  void _load() {
    try {
      _bytes = File(widget.path).readAsBytesSync();
      _loadFailed = false;
    } on FileSystemException {
      _bytes = null;
      _loadFailed = true;
    }
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
                if (_loadFailed) return _errorView(scheme, l10n);
                final Uint8List? bytes = _bytes;
                if (bytes == null) return const SizedBox.shrink();
                final double dpr = MediaQuery.devicePixelRatioOf(context);
                final int decodeWidth = math.min(
                  _maxDecodeWidth,
                  math.max(1, (constraints.maxWidth * dpr * 2).round()),
                );
                return Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  cacheWidth: decodeWidth,
                  filterQuality: FilterQuality.medium,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) =>
                          _errorView(scheme, l10n),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(ColorScheme scheme, AppLocalizations l10n) {
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
