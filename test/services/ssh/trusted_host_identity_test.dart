import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/ssh/trusted_host_identity.dart';

void main() {
  group('TrustedHostIdentity', () {
    final base = TrustedHostIdentity(
      host: 'example.com',
      port: 22,
      fingerprint: 'MD5:16:27:ac:4f',
      keyType: 'ssh-ed25519',
      firstTrustedAt: DateTime.utc(2026, 5, 30, 12, 0, 0),
      lastVerifiedAt: DateTime.utc(2026, 5, 30, 12, 0, 0),
    );

    test('endpointKey combines host and port', () {
      expect(base.endpointKey, 'example.com:22');
      expect(base.copyWith(port: 2222).endpointKey, 'example.com:2222');
    });

    test('toJson/fromJson round-trips', () {
      final json = base.toJson();
      final restored = TrustedHostIdentity.fromJson(json);
      expect(restored.host, base.host);
      expect(restored.port, base.port);
      expect(restored.fingerprint, base.fingerprint);
      expect(restored.keyType, base.keyType);
      expect(restored.firstTrustedAt, base.firstTrustedAt);
      expect(restored.lastVerifiedAt, base.lastVerifiedAt);
    });

    test('copyWith replaces only provided fields', () {
      final updated = base.copyWith(
        fingerprint: 'MD5:aa:bb',
        keyType: 'rsa-sha2-256',
      );
      expect(updated.fingerprint, 'MD5:aa:bb');
      expect(updated.keyType, 'rsa-sha2-256');
      expect(updated.host, base.host);
      expect(updated.firstTrustedAt, base.firstTrustedAt);
    });

    test('dates serialise as ISO-8601 strings', () {
      final json = base.toJson();
      expect(json['firstTrustedAt'], '2026-05-30T12:00:00.000Z');
      expect(json['lastVerifiedAt'], '2026-05-30T12:00:00.000Z');
    });
  });
}
