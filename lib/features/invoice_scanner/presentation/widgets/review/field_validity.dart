import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tracks which review fields currently hold text that cannot be turned into
/// a value. The set changes immediately; listeners are told a moment later,
/// so a field disappearing during a rebuild can report safely.
class FieldValidity extends ChangeNotifier {
  final Set<Object> _invalid = <Object>{};
  bool _disposed = false;

  bool get hasInvalid => _invalid.isNotEmpty;

  void report(Object key, {required bool valid}) {
    final bool changed = valid ? _invalid.remove(key) : _invalid.add(key);
    if (changed) {
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
