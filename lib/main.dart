import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:invoice_scanner/app/demo_composition.dart';
import 'package:invoice_scanner/core/theme/app_theme.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/scanner_flow_screen.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppScope scope = await createDemoScope();
  runApp(InvoiceScannerApp(scope: scope));
}

class InvoiceScannerApp extends StatelessWidget {
  const InvoiceScannerApp({required this.scope, super.key});

  final AppScope scope;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: BlocProvider<InvoiceScannerBloc>(
        create: (BuildContext context) => scope.createBloc(),
        child: ScannerFlowScreen(
          watchRecent: scope.watchRecent,
          newLineId: scope.newId,
        ),
      ),
    );
  }
}
