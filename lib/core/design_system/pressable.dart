import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';

/// Tappable surface with a press-scale micro-interaction, ripple, keyboard
/// focus, a 48dp minimum target, and a mandatory semantic label.
///
/// [Pressable] must wrap non-interactive children only. Nesting it around a
/// button or another [InkWell] produces a double ripple and duplicate focus
/// targets. For a button-with-label, put the label inside [child].
class Pressable extends StatefulWidget {
  const Pressable({
    required this.onPressed,
    required this.semanticLabel,
    required this.child,
    this.borderRadius = AppRadii.mdAll,
    this.haptics = kHapticsEnabled,
    super.key,
  });

  /// Null disables the control.
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Widget child;
  final BorderRadius borderRadius;
  final bool haptics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _handleTap() {
    if (widget.haptics) {
      unawaited(HapticFeedback.selectionClick());
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final bool reduced = AppMotion.reduced(context);
    final double scale = (_pressed && !reduced) ? AppMotion.pressScale : 1;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: enabled ? _handleTap : null,
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.standard,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? _handleTap : null,
            onHighlightChanged: (bool value) {
              if (_pressed != value) setState(() => _pressed = value);
            },
            borderRadius: widget.borderRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppSizes.minTouchTarget,
                minHeight: AppSizes.minTouchTarget,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
