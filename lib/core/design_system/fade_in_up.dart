import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';

/// Fades and lifts [child] into place on first build, optionally after
/// [delay]. Shows the child immediately when reduce-motion is on.
class FadeInUp extends StatelessWidget {
  const FadeInUp({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final Duration total = AppMotion.resolve(context, AppMotion.slow + delay);
    if (total == Duration.zero) return child;

    final double begin = math.max(
      0.0,
      math.min(delay.inMicroseconds / total.inMicroseconds, 1.0),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(begin, 1, curve: AppMotion.standard),
      child: child,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * AppSpacing.lg),
            child: child,
          ),
        );
      },
    );
  }
}
