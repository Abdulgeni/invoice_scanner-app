/// Coarse network state for the offline queue. "Online" means a network
/// interface is up, not that a request will succeed; real failures still
/// surface as `network` errors from the extractor.
abstract interface class ConnectivityMonitor {
  Future<bool> isOnline();

  /// Emits whenever the online state may have changed. Implementations
  /// should emit only distinct values, but callers must tolerate repeats.
  Stream<bool> get onlineChanges;
}
