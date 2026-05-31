import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background/foreground_task_service.dart';
import '../services/network/network_monitor.dart';
import '../services/ssh/host_key_verifier.dart';
import '../services/ssh/ssh_client.dart';
import '../services/ssh/trusted_host_identity.dart';
import '../services/ssh/trusted_host_store.dart';
import 'connection_provider.dart';

/// Trusted host identifier store (TOFU). Shared between UI and SshNotifier.
final trustedHostStoreProvider = Provider<TrustedHostStore>(
  (ref) => SharedPrefsTrustedHostStore(),
);

/// SSH connection state
class SshState {
  final SshConnectionState connectionState;
  final String? error;
  final String? sessionTitle;
  final bool isReconnecting;
  final int reconnectAttempt;
  final int? reconnectDelayMs;

  /// Whether network is available
  final bool isNetworkAvailable;

  /// Scheduled time for next retry
  final DateTime? nextRetryAt;

  /// Whether reconnection is paused (when network is unavailable)
  final bool isPaused;

  /// Information when host key mismatch is detected (TOFU/FR-004). null if not detected.
  /// While set, automatic reconnection is paused and waits for user to abort or retrust.
  final SshHostKeyChangedError? hostKeyChange;

  const SshState({
    this.connectionState = SshConnectionState.disconnected,
    this.error,
    this.sessionTitle,
    this.isReconnecting = false,
    this.reconnectAttempt = 0,
    this.reconnectDelayMs,
    this.isNetworkAvailable = true,
    this.nextRetryAt,
    this.isPaused = false,
    this.hostKeyChange,
  });

  SshState copyWith({
    SshConnectionState? connectionState,
    String? error,
    String? sessionTitle,
    bool? isReconnecting,
    int? reconnectAttempt,
    int? reconnectDelayMs,
    bool? isNetworkAvailable,
    DateTime? nextRetryAt,
    bool? isPaused,
    SshHostKeyChangedError? hostKeyChange,
    bool clearHostKeyChange = false,
  }) {
    return SshState(
      connectionState: connectionState ?? this.connectionState,
      error: error,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      reconnectDelayMs: reconnectDelayMs,
      isNetworkAvailable: isNetworkAvailable ?? this.isNetworkAvailable,
      nextRetryAt: nextRetryAt,
      isPaused: isPaused ?? this.isPaused,
      hostKeyChange:
          clearHostKeyChange ? null : (hostKeyChange ?? this.hostKeyChange),
    );
  }

  bool get isConnected => connectionState == SshConnectionState.connected;
  bool get isConnecting => connectionState == SshConnectionState.connecting;
  bool get isDisconnected => connectionState == SshConnectionState.disconnected;
  bool get hasError => connectionState == SshConnectionState.error;

  /// Whether waiting offline
  bool get isWaitingForNetwork => isPaused && !isNetworkAvailable;
}

/// Notifier that manages SSH connections
class SshNotifier extends Notifier<SshState> {
  SshClient? _client;
  final SshForegroundTaskService _foregroundService = SshForegroundTaskService();

  // Cache for reconnection
  Connection? _lastConnection;
  SshConnectOptions? _lastOptions;

  // Unlimited retry mode (0 = unlimited)
  static const int _maxReconnectAttempts = 0; // unlimited

  // Exponential backoff (max 60 seconds)
  static const int _baseDelayMs = 1000;
  static const int _maxDelayMs = 60000;
  static const double _backoffMultiplier = 1.5;

  // For monitoring connection state
  StreamSubscription<SshConnectionState>? _connectionStateSubscription;

  // For monitoring network status
  StreamSubscription<NetworkStatus>? _networkStatusSubscription;

  // Reconnection timer
  Timer? _reconnectTimer;

  // Disconnection detection callback (can be set externally)
  void Function()? onDisconnectDetected;

  // Reconnection success callback (can be set externally)
  void Function()? onReconnectSuccess;

  @override
  SshState build() {
    // Monitor network status
    _startNetworkMonitoring();

    // Register cleanup
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _connectionStateSubscription?.cancel();
      _networkStatusSubscription?.cancel();
      _client?.dispose();
      _foregroundService.stopService();
    });
    return const SshState();
  }

  /// Start monitoring network status
  void _startNetworkMonitoring() {
    final monitor = ref.read(networkMonitorProvider);
    _networkStatusSubscription = monitor.statusStream.listen(_onNetworkStatusChanged);
  }

  /// Handler for network status changes
  void _onNetworkStatusChanged(NetworkStatus status) {
    final isOnline = status == NetworkStatus.online;

    state = state.copyWith(isNetworkAvailable: isOnline);

    if (isOnline) {
      // When returning from offline to online
      if (state.isPaused && state.isReconnecting) {
        // Attempt immediate reconnection (no delay)
        state = state.copyWith(isPaused: false, reconnectAttempt: 0);
        _reconnectTimer?.cancel();
        // Call _doReconnect directly for immediate reconnection
        _doReconnect();
      }
    } else {
      // When going offline
      if (state.isReconnecting) {
        // Pause reconnection
        state = state.copyWith(isPaused: true);
        _reconnectTimer?.cancel();
      }
    }
  }

  /// Calculate reconnection delay (exponential backoff)
  int _calculateDelay(int attempt) {
    final delay = (_baseDelayMs * _pow(_backoffMultiplier, attempt)).round();
    return delay.clamp(_baseDelayMs, _maxDelayMs);
  }

  /// Power calculation
  double _pow(double base, int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  /// Get SSH client
  SshClient? get client => _client;

  /// Last connection information
  Connection? get lastConnection => _lastConnection;

  /// Last connection options
  SshConnectOptions? get lastOptions => _lastOptions;

  /// Flag to retrust changed host key only once on next connection (after explicit user retrust).
  bool _trustNextHostKey = false;

  /// Generate host key verifier for this endpoint (TOFU).
  /// If user recently chose to retrust, trust the new key only once (FR-005).
  HostKeyVerifier _buildVerifier(Connection connection) {
    final trustNew = _trustNextHostKey;
    _trustNextHostKey = false;
    return HostKeyVerifier(
      store: ref.read(trustedHostStoreProvider),
      host: connection.host,
      port: connection.port,
      trustNewHostKey: trustNew,
    );
  }

  /// Reflect host key mismatch in state and stop automatic reconnection (prevent loops, FR-007).
  void _handleHostKeyChange(SshHostKeyChangedError e) {
    _reconnectTimer?.cancel();
    _client?.dispose();
    _client = null;
    state = state.copyWith(
      connectionState: SshConnectionState.error,
      error: 'Host identity changed',
      isReconnecting: false,
      isPaused: false,
      hostKeyChange: e,
    );
  }

  /// Clear host key mismatch warning (when user chooses to abort).
  void clearHostKeyChange() {
    state = state.copyWith(clearHostKeyChange: true);
  }

  /// Get trusted host identity for specified endpoint (for UI display, FR-008).
  Future<TrustedHostIdentity?> getTrustedHostIdentity(String host, int port) {
    return ref.read(trustedHostStoreProvider).get(host, port);
  }

  /// Forget trust for specified endpoint (next connection treated as first time, FR-009).
  Future<void> forgetHostKey(String host, int port) {
    return ref.read(trustedHostStoreProvider).remove(host, port);
  }

  /// Instruct to explicitly retrust changed host key on next connection and clear warning (FR-005).
  ///
  /// Caller should then re-execute the normal connection/reconnection flow (with full setup).
  void retrustNextConnect() {
    _trustNextHostKey = true;
    state = state.copyWith(clearHostKeyChange: true);
  }

  /// Establish SSH connection (with shell - traditional method)
  Future<void> connect(Connection connection, SshConnectOptions options) async {
    state = state.copyWith(
      connectionState: SshConnectionState.connecting,
      error: null,
    );

    try {
      _client = SshClient();

      await _client!.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
        hostKeyVerifier: _buildVerifier(connection),
      );

      await _client!.startShell();

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
      );

      // Update last connected timestamp
      ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);

      // Start Foreground Service to maintain connection in background
      await _foregroundService.startService(
        connectionName: connection.name,
        host: connection.host,
      );
    } on SshHostKeyChangedError catch (e) {
      // Host key mismatch: transition to warning state and do not auto-reconnect (FR-004/007).
      _handleHostKeyChange(e);
    } on SshConnectionError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } on SshAuthenticationError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.toString(),
      );
      _client?.dispose();
      _client = null;
    }
  }

  /// Establish SSH connection (without shell - for tmux command method)
  ///
  /// Shell is not started since only exec() is used.
  Future<void> connectWithoutShell(Connection connection, SshConnectOptions options) async {
    // Cache for reconnection
    _lastConnection = connection;
    _lastOptions = options;

    // Cancel existing connection state monitoring
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    state = state.copyWith(
      connectionState: SshConnectionState.connecting,
      error: null,
      isReconnecting: false,
      reconnectAttempt: 0,
    );

    try {
      _client = SshClient();

      // Monitor connection state stream (speed up disconnection detection)
      _connectionStateSubscription = _client!.connectionStateStream.listen(
        _onConnectionStateChanged,
      );

      await _client!.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
        hostKeyVerifier: _buildVerifier(connection),
      );

      // Shell is not started (exec only)

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
        isReconnecting: false,
        reconnectAttempt: 0,
      );

      // Update last connected timestamp
      ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);

      // Start Foreground Service to maintain connection in background
      await _foregroundService.startService(
        connectionName: connection.name,
        host: connection.host,
      );
    } on SshHostKeyChangedError catch (e) {
      // Host key mismatch: transition to warning state and do not auto-reconnect (FR-004/007).
      _handleHostKeyChange(e);
    } on SshConnectionError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } on SshAuthenticationError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.toString(),
      );
      _client?.dispose();
      _client = null;
    }
  }

  /// Handler for connection state changes
  ///
  /// Immediately handle disconnection detection from keep-alive or socket.
  void _onConnectionStateChanged(SshConnectionState newState) {
    // When transitioning from connected state to disconnected/error
    if (state.isConnected &&
        (newState == SshConnectionState.error ||
         newState == SshConnectionState.disconnected)) {
      // Update state
      state = state.copyWith(
        connectionState: newState,
        error: newState == SshConnectionState.error ? 'Connection lost' : null,
      );

      // Call disconnection detection callback
      onDisconnectDetected?.call();

      // Attempt automatic reconnection (if not already reconnecting)
      if (!state.isReconnecting) {
        reconnect();
      }
    }
  }

  /// Attempt reconnection
  ///
  /// For automatic reconnection. Retry unlimited with exponential backoff.
  /// Pause if network is offline, auto-resume on recovery.
  Future<bool> reconnect() async {
    if (_lastConnection == null || _lastOptions == null) {
      return false;
    }

    // Pause if network is offline
    if (!state.isNetworkAvailable) {
      state = state.copyWith(
        isReconnecting: true,
        isPaused: true,
        error: 'Waiting for network...',
      );
      return false;
    }

    final attempt = state.reconnectAttempt;

    // Check max attempts only if not unlimited retry
    if (_maxReconnectAttempts > 0 && attempt >= _maxReconnectAttempts) {
      state = state.copyWith(
        isReconnecting: false,
        error: 'Max reconnect attempts reached',
      );
      return false;
    }

    final delayMs = _calculateDelay(attempt);
    final nextRetry = DateTime.now().add(Duration(milliseconds: delayMs));

    state = state.copyWith(
      isReconnecting: true,
      isPaused: false,
      reconnectAttempt: attempt + 1,
      reconnectDelayMs: delayMs,
      nextRetryAt: nextRetry,
    );

    // Reconnect after delay
    final completer = Completer<bool>();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      final result = await _doReconnect();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    });

    return completer.future;
  }

  /// Actual reconnection processing
  Future<bool> _doReconnect() async {
    if (_lastConnection == null || _lastOptions == null) {
      return false;
    }

    // Abort if network is offline
    if (!state.isNetworkAvailable) {
      state = state.copyWith(isPaused: true);
      return false;
    }

    try {
      // Cancel existing connection state monitoring
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      // Clean up old client
      _client?.dispose();
      _client = SshClient();

      // Monitor connection state stream (speed up disconnection detection)
      _connectionStateSubscription = _client!.connectionStateStream.listen(
        _onConnectionStateChanged,
      );

      await _client!.connect(
        host: _lastConnection!.host,
        port: _lastConnection!.port,
        username: _lastConnection!.username,
        options: _lastOptions!,
        hostKeyVerifier: _buildVerifier(_lastConnection!),
      );

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
        isReconnecting: false,
        isPaused: false,
        reconnectAttempt: 0,
        error: null,
        nextRetryAt: null,
        clearHostKeyChange: true,
      );

      // Reconnection success callback
      onReconnectSuccess?.call();

      return true;
    } on SshHostKeyChangedError catch (e) {
      // If host key changes during automatic reconnection: silently do not retrust and do not loop (FR-007).
      _handleHostKeyChange(e);
      return false;
    } catch (e) {
      // Reconnection failed, schedule next attempt
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: 'Reconnect failed: $e',
      );

      // Automatically schedule next attempt (for unlimited retry)
      if (_maxReconnectAttempts == 0 || state.reconnectAttempt < _maxReconnectAttempts) {
        // Schedule next reconnection asynchronously
        Future.microtask(() => reconnect());
      }

      return false;
    }
  }

  /// Attempt immediate reconnection now (for user action)
  Future<bool> reconnectNow() async {
    _reconnectTimer?.cancel();
    state = state.copyWith(
      reconnectAttempt: 0,
      isPaused: false,
    );
    return _doReconnect();
  }

  /// Check if connection is active
  bool checkConnection() {
    return _client != null && _client!.isConnected;
  }

  /// Reset reconnection state
  void resetReconnect() {
    _reconnectTimer?.cancel();
    state = state.copyWith(
      isReconnecting: false,
      isPaused: false,
      reconnectAttempt: 0,
      reconnectDelayMs: null,
      nextRetryAt: null,
    );
  }

  /// Disconnect
  Future<void> disconnect() async {
    // Cancel reconnection timer
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Cancel connection state monitoring
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    // Stop Foreground Service
    await _foregroundService.stopService();

    await _client?.disconnect();
    _client = null;
    state = state.copyWith(
      connectionState: SshConnectionState.disconnected,
      error: null,
      sessionTitle: null,
      isReconnecting: false,
      isPaused: false,
      reconnectAttempt: 0,
      nextRetryAt: null,
    );
  }

  /// Update session title
  void updateSessionTitle(String title) {
    state = state.copyWith(sessionTitle: title);
  }

  /// Send data
  void write(String data) {
    _client?.write(data);
  }

  /// Change terminal size
  void resize(int cols, int rows) {
    _client?.resize(cols, rows);
  }
}

/// SSH provider
final sshProvider = NotifierProvider<SshNotifier, SshState>(() {
  return SshNotifier();
});
