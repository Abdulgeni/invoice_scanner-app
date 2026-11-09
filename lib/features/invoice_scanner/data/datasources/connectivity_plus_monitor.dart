import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:invoice_scanner/features/invoice_scanner/domain/repositories/connectivity_monitor.dart';

class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    try {
      return _hasInterface(await _connectivity.checkConnectivity());
    } on Exception {
      // If the check itself fails, let the queue try; a real outage then
      // surfaces as a normal network failure and stops the pass.
      return true;
    }
  }

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasInterface).distinct();

  static bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}
