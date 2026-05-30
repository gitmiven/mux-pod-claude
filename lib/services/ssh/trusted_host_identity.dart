/// 信頼済みホスト識別子（TOFU: trust-on-first-use）。
///
/// あるサーバーエンドポイント（host:port）のホスト鍵 identity を信頼したという記録。
/// エンドポイントごとに1件。接続時にこの記録と提示されたフィンガープリントを比較する。
class TrustedHostIdentity {
  /// 接続先ホスト名またはIP（[Connection] と同じ値）。
  final String host;

  /// SSHポート。`host:port` が identity のキー（spec: エンドポイント単位）。
  final int port;

  /// 人間が比較可能なホスト鍵フィンガープリント（例 `MD5:16:27:ac:...`）。
  final String fingerprint;

  /// ネゴシエートされたホスト鍵アルゴリズム（例 `ssh-ed25519`, `rsa-sha2-256`）。
  final String keyType;

  /// 初めて信頼した日時。
  final DateTime firstTrustedAt;

  /// 直近で一致を確認した日時。
  final DateTime lastVerifiedAt;

  const TrustedHostIdentity({
    required this.host,
    required this.port,
    required this.fingerprint,
    required this.keyType,
    required this.firstTrustedAt,
    required this.lastVerifiedAt,
  });

  /// エンドポイントキー（`host:port`）。
  String get endpointKey => '$host:$port';

  TrustedHostIdentity copyWith({
    String? host,
    int? port,
    String? fingerprint,
    String? keyType,
    DateTime? firstTrustedAt,
    DateTime? lastVerifiedAt,
  }) {
    return TrustedHostIdentity(
      host: host ?? this.host,
      port: port ?? this.port,
      fingerprint: fingerprint ?? this.fingerprint,
      keyType: keyType ?? this.keyType,
      firstTrustedAt: firstTrustedAt ?? this.firstTrustedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'fingerprint': fingerprint,
      'keyType': keyType,
      'firstTrustedAt': firstTrustedAt.toIso8601String(),
      'lastVerifiedAt': lastVerifiedAt.toIso8601String(),
    };
  }

  factory TrustedHostIdentity.fromJson(Map<String, dynamic> json) {
    return TrustedHostIdentity(
      host: json['host'] as String,
      port: json['port'] as int,
      fingerprint: json['fingerprint'] as String,
      keyType: json['keyType'] as String,
      firstTrustedAt: DateTime.parse(json['firstTrustedAt'] as String),
      lastVerifiedAt: DateTime.parse(json['lastVerifiedAt'] as String),
    );
  }
}
