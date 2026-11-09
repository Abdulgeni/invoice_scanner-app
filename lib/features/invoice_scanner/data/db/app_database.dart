import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// One row per scanned invoice; also the offline queue.
///
/// Every timestamp column holds UTC microseconds since the epoch.
/// `image_names` is a JSON array of file names inside the managed image
/// directory, never full paths. `remote_synced_at` and `deleted_at` are
/// reserved for the later sync phase.
@DataClassName('InvoiceRow')
class InvoiceRows extends Table {
  @override
  String get tableName => 'invoices';

  TextColumn get id => text()();
  TextColumn get status => text()();
  TextColumn get imageNames => text()();
  IntColumn get attemptCount => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get invoiceJson => text().nullable()();
  TextColumn get extractedJson => text().nullable()();
  TextColumn get failureKind => text().nullable()();
  IntColumn get savedAt => integer().nullable()();
  IntColumn get remoteSyncedAt => integer().nullable()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(tables: <Type>[InvoiceRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_invoices_status_created '
        'ON invoices (status, created_at, id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_invoices_saved_at '
        'ON invoices (saved_at)',
      );
    },
  );
}
