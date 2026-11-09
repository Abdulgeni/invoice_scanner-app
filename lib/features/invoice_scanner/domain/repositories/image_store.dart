/// File housekeeping for invoice images. All methods deal in paths exactly
/// as the preprocessor returned them; comparisons are by string equality.
abstract interface class ImageStore {
  /// True when every path is an existing, non-empty file. An empty list
  /// returns false.
  Future<bool> allExist(List<String> paths);

  /// Best-effort delete. Missing files are fine. Never throws.
  Future<void> deleteFiles(Iterable<String> paths);

  /// Deletes the scanner plugin's temporary output. Never touches managed
  /// invoice images. Best-effort, never throws.
  Future<void> cleanScannerTemp();

  /// Deletes every managed (compressed) invoice image whose path is not in
  /// [keep]. Sweeps orphans left by crashes. Best-effort, never throws.
  Future<void> deleteManagedFilesExcept(Set<String> keep);
}
