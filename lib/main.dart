import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:invoice_scanner/app/app_composition.dart';
import 'package:invoice_scanner/core/theme/app_theme.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/bloc/invoice_scanner_bloc.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/screens/scanner_flow_screen.dart';
import 'package:invoice_scanner/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppScope scope = await createDemoScope();
  runApp(InvoiceScannerApp(scope: scope));
}

class InvoiceScannerApp extends StatefulWidget {
  const InvoiceScannerApp({required this.scope, super.key});

  final AppScope scope;

  @override
  State<InvoiceScannerApp> createState() => _InvoiceScannerAppState();
}

class _InvoiceScannerAppState extends State<InvoiceScannerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.scope.kickQueue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.scope.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppScope scope = widget.scope;
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
          history: scope.history,
        ),
      ),
    );
  }
}
