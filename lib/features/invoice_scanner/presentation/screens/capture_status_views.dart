import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/error_messages.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Shown while the native scanner is open.
class CaptureProgressView extends StatelessWidget {
  const CaptureProgressView({required this.onCancel, super.key});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _PulsingIcon(),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.capturingOpening,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                TextButton(onPressed: onCancel, child: Text(l10n.cancelAction)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow * 3,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ScaleTransition(
          scale: Tween<double>(begin: AppMotion.pulseMinScale, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: AppMotion.emphasized),
          ),
          child: Icon(
            Icons.document_scanner_outlined,
            size: AppSizes.iconXl,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class CaptureFailureView extends StatelessWidget {
  const CaptureFailureView({
    required this.reason,
    required this.onRetry,
    required this.onDone,
    this.maxPages,
    super.key,
  });

  final CaptureFailureReason reason;
  final int? maxPages;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.all(
                            AppSpacing.lg,
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: AppSizes.iconLg,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.captureErrorTitle,
                        style: text.titleLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      captureErrorMessage(l10n, reason, maxPages: maxPages),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppSizes.minTouchTarget,
                        ),
                      ),
                      child: Text(l10n.retryAction),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: onDone,
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
