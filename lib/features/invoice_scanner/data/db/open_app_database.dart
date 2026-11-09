import 'package:drift_flutter/drift_flutter.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/db/app_database.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the production database in the application-support directory
/// (not the documents directory, which is the package default).
AppDatabase openAppDatabase() {
  return AppDatabase(
    driftDatabase(
      name: 'invoice_scanner',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
  );
}
