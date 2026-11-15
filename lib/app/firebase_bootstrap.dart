import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'package:invoice_scanner/app/app_config.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/auth/anonymous_auth_gate.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/datasources/gemini_invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/datasources/guarded_invoice_extractor.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/firebase_ai_model_invoker.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/model_name_resolver.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/usage/daily_usage_counter.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_extractor.dart';
import 'package:invoice_scanner/firebase_options.dart';

class FirebaseServices {
  const FirebaseServices({required this.auth, required this.models});

  final AnonymousAuthGate auth;
  final RemoteConfigModelNameSource models;
}

/// Starts Firebase, App Check, Remote Config and anonymous sign-in.
///
/// Returns null, instead of throwing, when anything fails (a missing or
/// placeholder `firebase_options.dart`, no Play services, ...), so the app
/// still starts. Order matters: App Check is activated before any other
/// Firebase service is used.
Future<FirebaseServices?> initializeFirebase(AppConfig config) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final AndroidAppCheckProvider provider = config.useAppCheckDebugProvider
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider();
    await FirebaseAppCheck.instance.activate(providerAndroid: provider);

    final RemoteConfigModelNameSource models =
        await RemoteConfigModelNameSource.initialize(
          FirebaseRemoteConfig.instance,
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 1)
              : const Duration(minutes: 1),
        );

    final AnonymousAuthGate auth = AnonymousAuthGate.fromFirebase(
      FirebaseAuth.instance,
    );
    unawaited(_warmUp(auth));
    return FirebaseServices(auth: auth, models: models);
  } on Object catch (error) {
    // Startup boundary: degrade instead of crashing. No invoice data is
    // involved here, so printing is safe in debug builds.
    if (kDebugMode) debugPrint('Firebase setup failed: $error');
    return null;
  }
}

Future<void> _warmUp(AnonymousAuthGate auth) async {
  try {
    await auth.ensureSignedIn();
  } on Object {
    // Offline at launch is normal; the first read signs in again.
  }
}

/// The production extractor: sign-in, then the daily cap, then the model.
/// The cap sits inside the sign-in so a sign-in failure never uses it up.
InvoiceExtractor buildFirebaseExtractor({
  required FirebaseServices? services,
  required AppConfig config,
  required String Function() newId,
  required DailyUsageCounter counter,
}) {
  if (services == null) return const UnavailableInvoiceExtractor();

  FirebaseAI backend() {
    final FirebaseAI ai = config.useDeveloperApi
        ? FirebaseAI.googleAI(
            useLimitedUseAppCheckTokens: config.limitedUseAppCheckTokens,
          )
        : FirebaseAI.agentPlatform(
            location: config.location,
            useLimitedUseAppCheckTokens: config.limitedUseAppCheckTokens,
          );
    // Set explicitly: the docs don't say these are filled in automatically.
    ai
      ..appCheck = FirebaseAppCheck.instance
      ..auth = FirebaseAuth.instance;
    return ai;
  }

  final GeminiInvoiceExtractor gemini = GeminiInvoiceExtractor(
    invoker: FirebaseAiModelInvoker(backend: backend).call,
    models: ModelNameResolver(readRemote: services.models.read),
    newLineId: newId,
  );
  return AuthGatedInvoiceExtractor(
    inner: CappedInvoiceExtractor(
      inner: gemini,
      counter: counter,
      cap: config.dailyExtractionCap,
    ),
    ensureSignedIn: services.auth.ensureSignedIn,
  );
}
