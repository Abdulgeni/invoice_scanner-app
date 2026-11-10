import 'package:flutter/material.dart';

import 'package:invoice_scanner/core/theme/app_tokens.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/captured_page_stack.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/stage_progress.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({
    required this.stage,
    required this.pagePaths,
    this.onCancel,
    super.key,
  });

  final ProcessingStage stage;
  final List<String> pagePaths;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: CapturedPageStack(
                        pagePaths: pagePaths,
                        sweeping: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  StageProgress(stage: stage),
                  const SizedBox(height: AppSpacing.lg),
                  Visibility(
                    visible: onCancel != null,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: onCancel,
                      child: Text(l10n.cancelAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
