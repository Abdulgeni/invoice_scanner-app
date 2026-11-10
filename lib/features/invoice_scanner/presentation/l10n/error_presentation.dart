import 'package:flutter/material.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/l10n/error_messages.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

enum ErrorTone { calm, serious }

final class ErrorPresentation {
  const ErrorPresentation({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String message;
  final IconData icon;
  final ErrorTone tone;
}

ErrorPresentation presentationFor(
  AppLocalizations l10n,
  InvoiceErrorKind kind,
) {
  final String message = extractionErrorMessage(l10n, kind);
  return switch (kind) {
    InvoiceErrorKind.network => ErrorPresentation(
      title: l10n.errorTitleNetwork,
      message: message,
      icon: Icons.wifi_off_outlined,
      tone: ErrorTone.calm,
    ),
    InvoiceErrorKind.timeout => ErrorPresentation(
      title: l10n.errorTitleTimeout,
      message: message,
      icon: Icons.hourglass_bottom,
      tone: ErrorTone.calm,
    ),
    InvoiceErrorKind.quotaExceeded => ErrorPresentation(
      title: l10n.errorTitleQuota,
      message: message,
      icon: Icons.speed,
      tone: ErrorTone.calm,
    ),
    InvoiceErrorKind.appCheckFailed => ErrorPresentation(
      title: l10n.errorTitleAppCheck,
      message: message,
      icon: Icons.system_update_alt,
      tone: ErrorTone.serious,
    ),
    InvoiceErrorKind.safetyBlock => ErrorPresentation(
      title: l10n.errorTitleSafety,
      message: message,
      icon: Icons.block,
      tone: ErrorTone.serious,
    ),
    InvoiceErrorKind.emptyResponse => ErrorPresentation(
      title: l10n.errorTitleEmpty,
      message: message,
      icon: Icons.search_off,
      tone: ErrorTone.calm,
    ),
    InvoiceErrorKind.malformedJson => ErrorPresentation(
      title: l10n.errorTitleMalformed,
      message: message,
      icon: Icons.sync_problem_outlined,
      tone: ErrorTone.calm,
    ),
    InvoiceErrorKind.notAnInvoice => ErrorPresentation(
      title: l10n.errorTitleNotInvoice,
      message: message,
      icon: Icons.description_outlined,
      tone: ErrorTone.calm,
    ),
    InvoiceErrorKind.cancelled => ErrorPresentation(
      title: l10n.errorTitleCancelled,
      message: message,
      icon: Icons.cancel_outlined,
      tone: ErrorTone.calm,
    ),
    InvoiceErrorKind.unknown => ErrorPresentation(
      title: l10n.errorTitleUnknown,
      message: message,
      icon: Icons.error_outline,
      tone: ErrorTone.serious,
    ),
  };
}

enum ErrorAction { retry, retake }

final class ErrorPlan {
  const ErrorPlan({this.primary, this.secondary});

  final ErrorAction? primary;
  final ErrorAction? secondary;
}

ErrorPlan planErrorActions({
  required bool canRetry,
  required bool suggestsRetake,
}) {
  if (suggestsRetake) {
    return ErrorPlan(
      primary: ErrorAction.retake,
      secondary: canRetry ? ErrorAction.retry : null,
    );
  }
  if (canRetry) return const ErrorPlan(primary: ErrorAction.retry);
  return const ErrorPlan();
}
