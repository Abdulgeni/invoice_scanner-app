import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Decides which model names to try, in order.
///
/// 1. The Remote Config value, if it is a well-formed name that has not
///    already failed with "not found" this session.
/// 2. The last name that worked this session.
/// 3. The hardcoded [fallback], always, as the final candidate.
///
/// Remote Config itself keeps the last activated value across app restarts
/// and falls back to its in-app default, which is how a bad or missing
/// remote value is survived on a cold start.
class ModelNameResolver {
  ModelNameResolver({
    required String? Function() readRemote,
    this.fallback = defaultFallbackModel,
  }) : _readRemote = readRemote;

  static const String remoteKey = 'model_name';

  /// Firebase's documented default. Review it when models are retired.
  static const String defaultFallbackModel = 'gemini-3.8-flash';

  static final RegExp _valid = RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$');

  final String? Function() _readRemote;
  final String fallback;
  final Set<String> _unavailable = <String>{};
  String? _lastKnownGood;

  List<String> candidates() {
    final List<String> ordered = <String>[];
    void add(String? name) {
      if (name == null || !_valid.hasMatch(name)) return;
      if (_unavailable.contains(name) || ordered.contains(name)) return;
      ordered.add(name);
    }

    String? remote;
    try {
      remote = _readRemote()?.trim();
    } on Exception {
      remote = null;
    }
    add(remote);
    add(_lastKnownGood);
    if (!ordered.contains(fallback)) ordered.add(fallback);
    return List<String>.unmodifiable(ordered);
  }

  void markGood(String name) {
    _lastKnownGood = name;
    _unavailable.remove(name);
  }

  void markUnavailable(String name) {
    _unavailable.add(name);
    if (_lastKnownGood == name) _lastKnownGood = null;
  }
}

/// Remote Config wiring for [ModelNameResolver.remoteKey].
class RemoteConfigModelNameSource {
  RemoteConfigModelNameSource._(this._config);

  final FirebaseRemoteConfig _config;

  /// Applies settings and defaults, then starts a background fetch so
  /// startup is never blocked. Until the fetch lands, the previously
  /// activated value (or the in-app default) is used.
  ///
  /// Use a short [minimumFetchInterval] while developing.
  static Future<RemoteConfigModelNameSource> initialize(
    FirebaseRemoteConfig config, {
    Duration minimumFetchInterval = const Duration(hours: 1),
    Duration fetchTimeout = const Duration(seconds: 10),
  }) async {
    await config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: fetchTimeout,
        minimumFetchInterval: minimumFetchInterval,
      ),
    );
    await config.setDefaults(<String, dynamic>{
      ModelNameResolver.remoteKey: ModelNameResolver.defaultFallbackModel,
    });
    unawaited(_refresh(config));
    return RemoteConfigModelNameSource._(config);
  }

  static Future<void> _refresh(FirebaseRemoteConfig config) async {
    try {
      await config.fetchAndActivate();
    } on Exception {
      // Keep the last activated value or the default.
    }
  }

  /// The current value, or null when empty.
  String? read() {
    final String value = _config.getString(ModelNameResolver.remoteKey).trim();
    return value.isEmpty ? null : value;
  }
}
