import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:invoice_scanner/core/util/clock.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/iso_date.dart';

/// Counts uses per UTC day in a small JSON file. This is a convenience cap
/// for honest users, not abuse protection: clearing app data resets it.
///
/// Operations run one at a time. A missing or damaged file counts as zero
/// uses. If the file cannot be written, the counter fails open (allows the
/// use) rather than locking the user out over a disk problem.
class DailyUsageCounter {
  DailyUsageCounter({required File file, required Clock clock})
      : _file = file,
        _clock = clock;

  final File _file;
  final Clock _clock;
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final Completer<T> out = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        out.complete(await action());
      } catch (error, stack) {
        out.completeError(error, stack);
      }
    });
    return out.future;
  }

  /// Records one use unless today's count has reached [cap]. Returns false,
  /// recording nothing, at the cap. A [cap] of zero or less means "no cap"
  /// and records nothing.
  Future<bool> tryConsume(int cap) {
    if (cap <= 0) return Future<bool>.value(true);
    return _serial<bool>(() async {
      final _Usage usage = _read();
      if (usage.count >= cap) return false;
      _write(_Usage(usage.day, usage.count + 1));
      return true;
    });
  }

  /// Gives back one use (for a request that never reached the server).
  Future<void> release() {
    return _serial<void>(() async {
      final _Usage usage = _read();
      if (usage.count > 0) _write(_Usage(usage.day, usage.count - 1));
    });
  }

  Future<int> countToday() => _serial<int>(() async => _read().count);

  String _today() => formatIsoDate(dateOnly(_clock().toUtc()));

  _Usage _read() {
    final String today = _today();
    try {
      if (!_file.existsSync()) return _Usage(today, 0);
      final Object? decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is Map<String, dynamic> &&
          decoded['day'] == today &&
          decoded['count'] is int &&
          (decoded['count'] as int) >= 0) {
        return _Usage(today, decoded['count'] as int);
      }
    } catch (_) {
      // Damaged file: start again from zero.
    }
    return _Usage(today, 0);
  }

  void _write(_Usage usage) {
    final File tmp = File('${_file.path}.tmp');
    try {
      _file.parent.createSync(recursive: true);
      tmp.writeAsStringSync(
        jsonEncode(<String, Object>{'day': usage.day, 'count': usage.count}),
        flush: true,
      );
      tmp.renameSync(_file.path);
    } on FileSystemException {
      // Fail open: see the class comment.
    }
  }
}

final class _Usage {
  const _Usage(this.day, this.count);

  final String day;
  final int count;
}
