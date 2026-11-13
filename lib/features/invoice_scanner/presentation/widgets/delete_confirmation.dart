import 'package:flutter/material.dart';

import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Deleting is permanent (the invoice data and images are erased), so it
/// always asks first and has no undo.
Future<bool> confirmDeleteInvoice(BuildContext context) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(l10n.deleteInvoiceTitle),
      content: Text(l10n.deleteInvoiceBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
