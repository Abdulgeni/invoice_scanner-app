import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';

class ScanSweep extends StatefulWidget {
  const ScanSweep({super.key});

  @override
  State<ScanSweep> createState() => _ScanSweepState();
}

class _ScanSweepState extends State<ScanSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.sweepCycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return const SizedBox.shrink();
    final Color color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _SweepPainter(progress: _controller, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double t = Curves.easeInOut.transform(progress.value);
    final double band = size.height * AppSizes.sweepBandFraction;
    final double lead = (size.height + band) * t;
    final double top = lead - band;

    final Paint trail = Paint()
      ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, lead), <Color>[
        color.withValues(alpha: 0),
        color.withValues(alpha: AppOpacity.sweepTrail),
      ]);
    canvas.drawRect(Rect.fromLTRB(0, top, size.width, lead), trail);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        lead - AppSizes.sweepLineWidth,
        size.width,
        AppSizes.sweepLineWidth,
      ),
      Paint()..color = color.withValues(alpha: AppOpacity.sweepLine),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
