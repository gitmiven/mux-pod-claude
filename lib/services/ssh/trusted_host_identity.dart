/// Trusted host identifier (TOFU: trust-on-first-use).
///
/// A record of trusting the host key identity for a server endpoint (host:port).
/// One record per endpoint. On connection, the fingerprint presented is compared with this record.
class TrustedHostIdentity {
  /// Destination host name or IP (same value as [Connection]).
  final String host;

  /// SSH port. `host:port` is the identity key (spec: per-endpoint).
  final int port;

  /// Human-comparable host key fingerprint (example `MD5:16:27:ac:...`).
  final String fingerprint;

  /// Negotiated host key algorithm (example `ssh-ed25519`, `rsa-sha2-256`).
  final String keyType;

  /// Date and time when first trusted.
  final DateTime firstTrustedAt;

  /// Date and time of most recent verification.
  final DateTime lastVerifiedAt;

  const TrustedHostIdentity({
    required this.host,
    required this.port,
    required this.fingerprint,
    required this.keyType,
    required this.firstTrustedAt,
    required this.lastVerifiedAt,
  });

  /// Endpoint key (`host:port`).
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
