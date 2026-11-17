import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'package:invoice_scanner/features/invoice_scanner/data/db/app_database.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/db/invoice_codec.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/entities/invoice_record.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/invoice_repository.dart';
final class _CorruptRow implements Exception {
  const _CorruptRow();
}

/// SQLite persistence for [InvoiceRecord]s.
///
/// - Image paths are stored as file names relative to [managedDirPath] and
///   rebuilt against the current directory on every read, so a moved app
///   container cannot leave stale absolute paths in the database.
/// - Paths passed in must live directly in [managedDirPath]; anything else
///   is a programming error and throws [ArgumentError].
/// - Writing a record with `isDeleted` stores a tombstone: payload columns
///   and image names are erased regardless of what the record holds.
/// - Rows that fail validation are skipped by lists and reported as
///   `InvoiceFailure(unknown, row_corrupt)` by [get] and [mutate].
class DriftInvoiceRepository implements InvoiceRepository {
  DriftInvoiceRepository(this._db, {required String managedDirPath})
    : _dir = managedDirPath;

  final AppDatabase _db;
  final String _dir;

  static final RegExp _namePattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  @override
  Future<bool> insertIfAbsent(InvoiceRecord record) {
    return _db.transaction(() async {
      final InvoiceRow? existing = await _selectOne(record.id);
      if (existing != null) return false;
      await _db.into(_db.invoiceRows).insert(_toCompanion(record));
      return true;
    });
  }

  @override
  Future<InvoiceRecord?> get(String id) async {
    final InvoiceRow? row = await _selectOne(id);
    if (row == null) return null;
    return _decodeOrThrow(row);
  }

  @override
  Future<InvoiceRecord?> mutate(
    String id,
    InvoiceRecord Function(InvoiceRecord current) change,
  ) {
    return _db.transaction(() async {
      final InvoiceRow? row = await _selectOne(id);
      if (row == null) return null;
      final InvoiceRecord next = change(_decodeOrThrow(row));
      if (next.id != id) throw ArgumentError('mutate must keep the id');
      await (_db.update(
        _db.invoiceRows,
      )..where((t) => t.id.equals(id))).write(_toCompanion(next));
      return next;
    });
  }

  @override
  Future<List<InvoiceRecord>> listByStatus(Set<InvoiceStatus> statuses) async {
    if (statuses.isEmpty) return const <InvoiceRecord>[];
    final List<String> names = statuses
        .map((InvoiceStatus s) => s.name)
        .toList();
    final List<InvoiceRow> rows =
        await (_db.select(_db.invoiceRows)
              ..where((t) => t.status.isIn(names) & t.deletedAt.isNull())
              ..orderBy(<OrderingTerm Function($InvoiceRowsTable)>[
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return _decodeAll(rows);
  }

  @override
  Stream<List<InvoiceRecord>> watchSaved() {
    final query = _db.select(_db.invoiceRows)
      ..where(
        (t) => t.status.equals(InvoiceStatus.saved.name) & t.deletedAt.isNull(),
      )
      ..orderBy(<OrderingTerm Function($InvoiceRowsTable)>[
        (t) => OrderingTerm.desc(t.savedAt),
      ]);
    return query.watch().map(_decodeAll);
  }

  @override
  Stream<List<InvoiceRecord>> watchLive() {
    final query = _db.select(_db.invoiceRows)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy(<OrderingTerm Function($InvoiceRowsTable)>[
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.watch().map(_decodeAll);
  }

  Future<InvoiceRow?> _selectOne(String id) {
    return (_db.select(
      _db.invoiceRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  List<InvoiceRecord> _decodeAll(List<InvoiceRow> rows) {
    final List<InvoiceRecord> out = <InvoiceRecord>[];
    for (final InvoiceRow row in rows) {
      try {
        out.add(_decode(row));
      } on _CorruptRow {
        // Skipped: a damaged row must not take the whole list down.
      }
    }
    return out;
  }

  InvoiceRecord _decodeOrThrow(InvoiceRow row) {
    try {
      return _decode(row);
    } on _CorruptRow {
      throw const InvoiceFailure(
        InvoiceErrorKind.unknown,
        debugCode: DebugCodes.rowCorrupt,
      );
    }
  }

  InvoiceRecord _decode(InvoiceRow row) {
    try {
      final InvoiceStatus status = InvoiceStatus.values.byName(row.status);
      final String? invoiceJson = row.invoiceJson;
      final String? extractedJson = row.extractedJson;
      final String? kindName = row.failureKind;
      final Invoice? invoice = invoiceJson == null
          ? null
          : decodeInvoice(invoiceJson);
      final Invoice? extracted = extractedJson == null
          ? null
          : decodeInvoice(extractedJson);
      final InvoiceErrorKind? failureKind = kindName == null
          ? null
          : InvoiceErrorKind.values.byName(kindName);
      final DateTime? deletedAt = _timeOrNull(row.deletedAt);

      if (deletedAt == null) {
        final bool needsInvoice =
            status == InvoiceStatus.needsReview ||
            status == InvoiceStatus.saved;
        if ((needsInvoice && invoice == null) ||
            (status == InvoiceStatus.failed && failureKind == null)) {
          throw const _CorruptRow();
        }
      }
      if (row.attemptCount < 0) throw const _CorruptRow();

      return InvoiceRecord(
        id: row.id,
        status: status,
        imagePaths: List<String>.unmodifiable(
          _decodeNames(row.imageNames).map(_toPath),
        ),
        attemptCount: row.attemptCount,
        createdAt: _time(row.createdAt),
        updatedAt: _time(row.updatedAt),
        invoice: invoice,
        extractedInvoice: extracted,
        failureKind: failureKind,
        savedAt: _timeOrNull(row.savedAt),
        remoteSyncedAt: _timeOrNull(row.remoteSyncedAt),
        deletedAt: deletedAt,
      );
    } on FormatException {
      throw const _CorruptRow();
    } on ArgumentError {
      throw const _CorruptRow();
    }
  }

  InvoiceRowsCompanion _toCompanion(InvoiceRecord r) {
    final bool tombstone = r.isDeleted;
    final Invoice? invoice = tombstone ? null : r.invoice;
    final Invoice? extracted = tombstone ? null : r.extractedInvoice;
    return InvoiceRowsCompanion(
      id: Value<String>(r.id),
      status: Value<String>(r.status.name),
      imageNames: Value<String>(
        jsonEncode(
          tombstone ? const <String>[] : r.imagePaths.map(_toName).toList(),
        ),
      ),
      attemptCount: Value<int>(r.attemptCount),
      createdAt: Value<int>(_us(r.createdAt)),
      updatedAt: Value<int>(_us(r.updatedAt)),
      invoiceJson: Value<String?>(
        invoice == null ? null : encodeInvoice(invoice),
      ),
      extractedJson: Value<String?>(
        extracted == null ? null : encodeInvoice(extracted),
      ),
      failureKind: Value<String?>(tombstone ? null : r.failureKind?.name),
      savedAt: Value<int?>(_usOrNull(r.savedAt)),
      remoteSyncedAt: Value<int?>(_usOrNull(r.remoteSyncedAt)),
      deletedAt: Value<int?>(_usOrNull(r.deletedAt)),
    );
  }

  // --- paths -----------------------------------------------------------

  String _toName(String path) {
    final String normalized = path.replaceAll('\\', '/');
    final String dir = _dir.replaceAll('\\', '/');
    if (!normalized.startsWith('$dir/')) {
      throw ArgumentError('image path is outside the managed directory');
    }
    final String name = normalized.substring(dir.length + 1);
    if (!_namePattern.hasMatch(name)) {
      throw ArgumentError('image path is not a plain file name');
    }
    return name;
  }

  String _toPath(String name) => '$_dir${Platform.pathSeparator}$name';

  List<String> _decodeNames(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! List<dynamic>) throw const _CorruptRow();
    final List<String> names = <String>[];
    for (final dynamic element in decoded) {
      if (element is! String || !_namePattern.hasMatch(element)) {
        throw const _CorruptRow();
      }
      names.add(element);
    }
    return names;
  }

  // --- time ------------------------------------------------------------

  static int _us(DateTime value) => value.toUtc().microsecondsSinceEpoch;
  static int? _usOrNull(DateTime? value) => value == null ? null : _us(value);
  static DateTime _time(int micros) =>
      DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  static DateTime? _timeOrNull(int? micros) =>
      micros == null ? null : _time(micros);
}
