import 'package:flutter/material.dart';

import 'package:invoice_scanner/l10n/app_localizations.dart';

/// Shown for the moment between "Confirm & Save" and the success screen.
class SavingView extends StatelessWidget {
  const SavingView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(l10n.savingLabel)),
          ],
        ),
      ),
    );
  }
}
