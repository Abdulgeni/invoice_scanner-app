import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart' as cds;

import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/image_store.dart';

/// File housekeeping over one flat app-private directory of compressed
/// images, plus the scanner plugin's own output.
///
/// `deleteFiles` removes exactly the paths it is given and does not check
/// where they live: the callers are our own records and the scanner's page
/// paths.
class ManagedImageStore implements ImageStore {
  ManagedImageStore({
    required Directory managedDir,
    Future<void> Function()? cleanScannerCache,
  }) : _managedDir = managedDir,
       _cleanScannerCache = cleanScannerCache ?? _pluginCleanCache;

  final Directory _managedDir;
  final Future<void> Function() _cleanScannerCache;

  static Future<void> _pluginCleanCache() async {
    await cds.CunningDocumentScanner.cleanCache();
  }

  @override
  Future<bool> allExist(List<String> paths) async {
    if (paths.isEmpty) return false;
    try {
      for (final String path in paths) {
        final File file = File(path);
        if (!await file.exists() || await file.length() == 0) return false;
      }
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final String path in paths) {
      try {
        final File file = File(path);
        if (await file.exists()) await file.delete();
      } on Exception {
        // Best effort by contract.
      }
    }
  }

  @override
  Future<void> cleanScannerTemp() async {
    try {
      await _cleanScannerCache();
    } on Exception {
      // Best effort by contract.
    }
  }

  /// Compares by file name only: the directory is flat, and stored paths may
  /// differ in form (for example after an iOS container move).
  @override
  Future<void> deleteManagedFilesExcept(Set<String> keep) async {
    final Set<String> keepNames = <String>{
      for (final String path in keep) _baseName(path),
    };
    try {
      if (!await _managedDir.exists()) return;
      await for (final FileSystemEntity entity in _managedDir.list(
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (keepNames.contains(_baseName(entity.path))) continue;
        try {
          await entity.delete();
        } on Exception {
          // Skip files that cannot be deleted.
        }
      }
    } on Exception {
      // Best effort by contract.
    }
  }

  static String _baseName(String path) => path.split(RegExp(r'[\\/]')).last;
}
