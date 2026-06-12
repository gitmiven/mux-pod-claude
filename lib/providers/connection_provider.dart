import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/logging/app_log.dart';

/// Connection settings
class Connection {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String authMethod; // 'password' | 'key'
  final String? keyId;
  final String? tmuxPath;

  /// Optional non-default tmux socket. A bare name targets `tmux -L <name>`;
  /// a value containing `/` targets `tmux -S <path>`. Null ⇒ default socket.
  final String? tmuxSocket;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;

  /// Identifier for deep linking (shareable with external scripts)
  final String? deepLinkId;

  const Connection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authMethod = 'password',
    this.keyId,
    this.tmuxPath,
    this.tmuxSocket,
    required this.createdAt,
    this.lastConnectedAt,
    this.deepLinkId,
  });

  Connection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? authMethod,
    String? keyId,
    String? tmuxPath,
    String? tmuxSocket,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
    String? deepLinkId,
    bool clearDeepLinkId = false,
  }) {
    return Connection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      keyId: keyId ?? this.keyId,
      tmuxPath: tmuxPath ?? this.tmuxPath,
      tmuxSocket: tmuxSocket ?? this.tmuxSocket,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      deepLinkId: clearDeepLinkId ? null : (deepLinkId ?? this.deepLinkId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'authMethod': authMethod,
      'keyId': keyId,
      'tmuxPath': tmuxPath,
      'tmuxSocket': tmuxSocket,
      'createdAt': createdAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'deepLinkId': deepLinkId,
    };
  }

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      authMethod: json['authMethod'] as String? ?? 'password',
      keyId: json['keyId'] as String?,
      tmuxPath: json['tmuxPath'] as String?,
      tmuxSocket: json['tmuxSocket'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
      deepLinkId: json['deepLinkId'] as String?,
    );
  }
}

/// Connection list state
class ConnectionsState {
  final List<Connection> connections;
  final bool isLoading;
  final String? error;

  const ConnectionsState({
    this.connections = const [],
    this.isLoading = false,
    this.error,
  });

  ConnectionsState copyWith({
    List<Connection>? connections,
    bool? isLoading,
    String? error,
  }) {
    return ConnectionsState(
      connections: connections ?? this.connections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing connections
class ConnectionsNotifier extends Notifier<ConnectionsState> {
  static const String _storageKey = 'connections';

  @override
  ConnectionsState build() {
    // Initial state
    _loadConnections();
    return const ConnectionsState(isLoading: true);
  }

  Future<void> _loadConnections() async {
    AppLog.d('_loadConnections() started', tag: 'ConnectionsProvider');
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      AppLog.d('JSON from storage: ${jsonString != null ? 'exists' : 'null'}', tag: 'ConnectionsProvider');

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final connections = jsonList
            .map((json) => Connection.fromJson(json as Map<String, dynamic>))
            .toList();

        AppLog.d('Loaded ${connections.length} connections from storage', tag: 'ConnectionsProvider');

        // Sort by last connected time (descending)
        connections.sort((a, b) {
          final aTime = a.lastConnectedAt ?? a.createdAt;
          final bTime = b.lastConnectedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });

        state = ConnectionsState(connections: connections);
        AppLog.d('State updated with ${connections.length} connections', tag: 'ConnectionsProvider');
      } else {
        state = const ConnectionsState();
        AppLog.d('No saved connections, initialized empty state', tag: 'ConnectionsProvider');
      }
    } catch (e, stackTrace) {
      AppLog.e('Error loading connections: $e', tag: 'ConnectionsProvider', error: e, stackTrace: stackTrace);
      state = ConnectionsState(error: e.toString());
    }
  }

  Future<void> _saveConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = state.connections.map((c) => c.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Add a connection
  Future<void> add(Connection connection) async {
    AppLog.d('add() called: ${connection.name} (${connection.id})', tag: 'ConnectionsProvider');
    AppLog.d('Current connections count: ${state.connections.length}', tag: 'ConnectionsProvider');

    final connections = [...state.connections, connection];
    AppLog.d('New connections count: ${connections.length}', tag: 'ConnectionsProvider');

    state = state.copyWith(connections: connections);
    AppLog.d('State updated, saving to SharedPreferences...', tag: 'ConnectionsProvider');

    await _saveConnections();
    AppLog.d('Connections saved. Final count: ${state.connections.length}', tag: 'ConnectionsProvider');
  }

  /// Remove a connection
  Future<void> remove(String id) async {
    AppLog.d('remove() called: $id', tag: 'ConnectionsProvider');
    final connections = state.connections.where((c) => c.id != id).toList();
    state = state.copyWith(connections: connections);
    await _saveConnections();
    AppLog.d('Connection removed. Remaining: ${state.connections.length}', tag: 'ConnectionsProvider');
  }

  /// Update a connection
  Future<void> update(Connection connection) async {
    AppLog.d('update() called: ${connection.name} (${connection.id})', tag: 'ConnectionsProvider');
    final connections = state.connections.map((c) {
      return c.id == connection.id ? connection : c;
    }).toList();
    state = state.copyWith(connections: connections);
    await _saveConnections();
    AppLog.d('Connection updated and saved', tag: 'ConnectionsProvider');
  }

  /// Update last connected time
  Future<void> updateLastConnected(String id) async {
    final connections = state.connections.map((c) {
      if (c.id == id) {
        return c.copyWith(lastConnectedAt: DateTime.now());
      }
      return c;
    }).toList();
    state = state.copyWith(connections: connections);
    await _saveConnections();
  }

  /// Get a connection
  Connection? getById(String id) {
    try {
      return state.connections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Search for a server by deepLinkId or connection name
  Connection? findByDeepLinkIdOrName(String serverIdentifier) {
    // First, exact match by deepLinkId
    for (final c in state.connections) {
      if (c.deepLinkId != null && c.deepLinkId == serverIdentifier) {
        return c;
      }
    }
    // Next, exact match by connection name
    for (final c in state.connections) {
      if (c.name == serverIdentifier) {
        return c;
      }
    }
    // Finally, case-insensitive match by connection name
    final lower = serverIdentifier.toLowerCase();
    for (final c in state.connections) {
      if (c.name.toLowerCase() == lower) {
        return c;
      }
    }
    return null;
  }

  /// Reload
  Future<void> reload() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadConnections();
  }
}

/// Connection list provider
final connectionsProvider =
    NotifierProvider<ConnectionsNotifier, ConnectionsState>(() {
  return ConnectionsNotifier();
});

/// Notifier for managing selected connection ID
class SelectedConnectionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = id;
  }
}

/// Notifier for managing search query
class ConnectionSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Search query provider
final connectionSearchProvider =
    NotifierProvider<ConnectionSearchNotifier, String>(() {
  return ConnectionSearchNotifier();
});

/// Sort option
enum ConnectionSortOption {
  nameAsc,
  nameDesc,
  lastConnectedDesc,
  lastConnectedAsc,
  hostAsc,
  hostDesc,
}

/// Notifier for managing sort option
class ConnectionSortNotifier extends Notifier<ConnectionSortOption> {
  @override
  ConnectionSortOption build() => ConnectionSortOption.lastConnectedDesc;

  void setSort(ConnectionSortOption option) {
    state = option;
  }
}

/// Sort option provider
final connectionSortProvider =
    NotifierProvider<ConnectionSortNotifier, ConnectionSortOption>(() {
  return ConnectionSortNotifier();
});

/// Filtered and sorted connection list provider
final filteredConnectionsProvider = Provider<List<Connection>>((ref) {
  final connectionsState = ref.watch(connectionsProvider);
  final searchQuery = ref.watch(connectionSearchProvider).toLowerCase();
  final sortOption = ref.watch(connectionSortProvider);

  // Search filtering (create a copy to avoid modifying the original list)
  var connections = List.of(connectionsState.connections);
  if (searchQuery.isNotEmpty) {
    connections = connections.where((c) {
      return c.name.toLowerCase().contains(searchQuery) ||
          c.host.toLowerCase().contains(searchQuery) ||
          c.username.toLowerCase().contains(searchQuery) ||
          (c.deepLinkId?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();
  }

  // Sort
  switch (sortOption) {
    case ConnectionSortOption.nameAsc:
      connections.sort((a, b) => a.name.compareTo(b.name));
    case ConnectionSortOption.nameDesc:
      connections.sort((a, b) => b.name.compareTo(a.name));
    case ConnectionSortOption.lastConnectedDesc:
      connections.sort((a, b) {
        final aTime = a.lastConnectedAt ?? a.createdAt;
        final bTime = b.lastConnectedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    case ConnectionSortOption.lastConnectedAsc:
      connections.sort((a, b) {
        final aTime = a.lastConnectedAt ?? a.createdAt;
        final bTime = b.lastConnectedAt ?? b.createdAt;
        return aTime.compareTo(bTime);
      });
    case ConnectionSortOption.hostAsc:
      connections.sort((a, b) => a.host.compareTo(b.host));
    case ConnectionSortOption.hostDesc:
      connections.sort((a, b) => b.host.compareTo(a.host));
  }

  return connections;
});

/// Currently selected connection ID provider
final selectedConnectionIdProvider =
    NotifierProvider<SelectedConnectionIdNotifier, String?>(() {
  return SelectedConnectionIdNotifier();
});

/// Currently selected connection provider
final selectedConnectionProvider = Provider<Connection?>((ref) {
  final id = ref.watch(selectedConnectionIdProvider);
  if (id == null) return null;

  final state = ref.watch(connectionsProvider);
  try {
    return state.connections.firstWhere((c) => c.id == id);
  } catch (e) {
    return null;
  }
});
