import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'trusted_host_identity.dart';

/// 信頼済みホスト識別子の永続化境界（DIP: 注入可能な抽象）。
///
/// エンドポイント（`host:port`）ごとに1件の [TrustedHostIdentity] を保存・取得・削除する。
abstract class TrustedHostStore {
  /// 指定エンドポイントの信頼済み identity を返す（無ければ null = 初回接続）。
  Future<TrustedHostIdentity?> get(String host, int port);

  /// 保存済みの全 identity を返す。
  Future<List<TrustedHostIdentity>> getAll();

  /// identity を upsert する（`endpointKey` で既存を置換）。
  Future<void> save(TrustedHostIdentity identity);

  /// 指定エンドポイントの identity を忘れる（FR-009）。
  Future<void> remove(String host, int port);
}

/// `shared_preferences` 上に実装した [TrustedHostStore]。
///
/// フィンガープリントは秘密情報ではない公開データのため、`flutter_secure_storage` ではなく
/// 専用キー `trusted_host_identities` 配下に独立した名前空間で保持する（FR-010）。
/// 接続リスト（`connections`）とは混在させず、ログにも出力しない。
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
