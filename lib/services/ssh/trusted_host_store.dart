import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'trusted_host_identity.dart';

/// Persistence boundary for trusted host identifiers (DIP: dependency injection principle, injectable abstraction).
///
/// Stores, retrieves, and removes one [TrustedHostIdentity] per endpoint (`host:port`).
abstract class TrustedHostStore {
  /// Returns the trusted identity for the specified endpoint (null if none = first connection).
  Future<TrustedHostIdentity?> get(String host, int port);

  /// Returns all stored identities.
  Future<List<TrustedHostIdentity>> getAll();

  /// Upserts an identity (replaces existing entry via `endpointKey`).
  Future<void> save(TrustedHostIdentity identity);

  /// Removes the identity for the specified endpoint (FR-009).
  Future<void> remove(String host, int port);
}

/// Implementation of [TrustedHostStore] using `shared_preferences`.
///
/// Fingerprints are public data and not secrets, so they are stored in a dedicated key `trusted_host_identities`
/// with an independent namespace rather than in `flutter_secure_storage` (FR-010).
/// They are kept separate from the connection list (`connections`) and not logged.
class SharedPrefsTrustedHostStore implements TrustedHostStore {
  static const String storageKey = 'trusted_host_identities';

  static String _endpointKey(String host, int port) => '$host:$port';

  Future<Map<String, dynamic>> _readMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(map));
  }

  @override
  Future<TrustedHostIdentity?> get(String host, int port) async {
    final map = await _readMap();
    final value = map[_endpointKey(host, port)];
    if (value is Map<String, dynamic>) {
      return TrustedHostIdentity.fromJson(value);
    }
    return null;
  }

  @override
  Future<List<TrustedHostIdentity>> getAll() async {
    final map = await _readMap();
    return map.values
        .whereType<Map<String, dynamic>>()
        .map(TrustedHostIdentity.fromJson)
        .toList();
  }

  @override
  Future<void> save(TrustedHostIdentity identity) async {
    final map = await _readMap();
    map[identity.endpointKey] = identity.toJson();
    await _writeMap(map);
  }

  @override
  Future<void> remove(String host, int port) async {
    final map = await _readMap();
    map.remove(_endpointKey(host, port));
    await _writeMap(map);
  }
}
