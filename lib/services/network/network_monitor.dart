import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network status
enum NetworkStatus {
  /// Network is available
  online,

  /// Network is unavailable
  offline,
}

/// Service that monitors network status.
///
/// Uses connectivity_plus to detect network connection/disconnection
/// and serves as a trigger for SSH reconnection.
class NetworkMonitor {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _statusController = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.online;

  /// Current network status
  NetworkStatus get currentStatus => _currentStatus;

  /// Stream of network status
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// Whether the network is available
  bool get isOnline => _currentStatus == NetworkStatus.online;

  /// Start monitoring
  Future<void> start() async {
    // Get initial state
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Monitor for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  /// Stop monitoring
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Update status
  void _updateStatus(List<ConnectivityResult> results) {
    final newStatus = _determineStatus(results);

    if (newStatus != _currentStatus) {
      final oldStatus = _currentStatus;
      _currentStatus = newStatus;
      _statusController.add(newStatus);

      // Detect recovery from offline to online
      if (oldStatus == NetworkStatus.offline &&
          newStatus == NetworkStatus.online) {
        // Recovery event is notified via statusStream
      }
    }
  }

  /// Determine NetworkStatus from ConnectivityResult
  NetworkStatus _determineStatus(List<ConnectivityResult> results) {
    // Online if there is any connection other than none
    for (final result in results) {
      if (result != ConnectivityResult.none) {
        return NetworkStatus.online;
      }
    }
    return NetworkStatus.offline;
  }

  /// Release resources
  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }
}

/// Provider for network monitor
final networkMonitorProvider = Provider<NetworkMonitor>((ref) {
  final monitor = NetworkMonitor();

  // Automatically start monitoring
  monitor.start();

  ref.onDispose(() {
    monitor.dispose();
  });

  return monitor;
});

/// Stream provider for network status
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final monitor = ref.watch(networkMonitorProvider);
  return monitor.statusStream;
});
