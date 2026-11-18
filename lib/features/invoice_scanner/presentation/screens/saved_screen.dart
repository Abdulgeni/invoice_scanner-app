import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/money_formatter.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// A short, quiet celebration: a badge pops in, a check draws itself, and
/// the device gives one medium tap. Under reduce-motion the finished check
/// is simply there; the haptic is not motion and still plays.
class SavedScreen extends StatefulWidget {
  const SavedScreen({
    required this.invoice,
    required this.onDone,
    required this.onScanAnother,
    super.key,
  });

  final Invoice? invoice;
  final VoidCallback onDone;
  final VoidCallback onScanAnother;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.checkDraw,
  );

  @override
  void initState() {
    super.initState();
    unawaited(HapticFeedback.mediumImpact());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).toString();

    final Invoice? invoice = widget.invoice;
    String? summary;
    if (invoice != null) {
      final String vendor = (invoice.vendorName ?? '').trim().isEmpty
          ? l10n.invoiceUnnamed
          : invoice.vendorName!.trim();
      final String total = invoice.total == null
          ? l10n.recentNoTotal
          : MoneyFormatter(locale).format(invoice.total!);
      summary = l10n.savedSummary(vendor, total);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: const Size.square(AppSizes.checkBadge),
                        painter: _CheckPainter(
                          progress: _controller,
                          badge: scheme.primaryContainer,
                          stroke: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    liveRegion: true,
                    header: true,
                    child: Text(l10n.savedTitle, style: text.headlineSmall),
                  ),
                  if (summary != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      summary,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  FilledButton.icon(
                    onPressed: widget.onScanAnother,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(l10n.savedScanAnother),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSizes.minTouchTarget,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: widget.onDone,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSizes.minTouchTarget,
                      ),
                    ),
                    child: Text(l10n.doneAction),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.badge,
    required this.stroke,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color badge;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    final double pop = Curves.easeOutBack.transform((t / 0.4).clamp(0.0, 1.0));
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 * pop,
      Paint()..color = badge,
    );

    final double draw = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    if (draw <= 0) return;
    final Path check = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    final PathMetric metric = check.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * Curves.easeOut.transform(draw)),
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.badge != badge ||
      oldDelegate.stroke != stroke ||
      oldDelegate.progress != progress;
}
