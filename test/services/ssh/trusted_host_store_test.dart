import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_muxpod/services/ssh/trusted_host_identity.dart';
import 'package:flutter_muxpod/services/ssh/trusted_host_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TrustedHostIdentity identity(
    String host,
    int port,
    String fp, {
    String keyType = 'ssh-ed25519',
  }) {
    return TrustedHostIdentity(
      host: host,
      port: port,
      fingerprint: fp,
      keyType: keyType,
      firstTrustedAt: DateTime.utc(2026, 5, 30),
      lastVerifiedAt: DateTime.utc(2026, 5, 30),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsTrustedHostStore', () {
    test('get returns null when nothing stored (first use)', () async {
      final store = SharedPrefsTrustedHostStore();
      expect(await store.get('example.com', 22), isNull);
    });

    test('save then get round-trips the identity', () async {
      final store = SharedPrefsTrustedHostStore();
      await store.save(identity('example.com', 22, 'MD5:aa:bb'));

      final got = await store.get('example.com', 22);
      expect(got, isNotNull);
      expect(got!.fingerprint, 'MD5:aa:bb');
      expect(got.endpointKey, 'example.com:22');
    });

    test('save upserts (replaces) by endpoint key', () async {
      final store = SharedPrefsTrustedHostStore();
      await store.save(identity('example.com', 22, 'MD5:old'));
      await store.save(
        identity('example.com', 22, 'MD5:new', keyType: 'rsa-sha2-256'),
      );

      final got = await store.get('example.com', 22);
      expect(got!.fingerprint, 'MD5:new');
      expect(got.keyType, 'rsa-sha2-256');
      expect((await store.getAll()).length, 1);
    });

    test('same host different port are distinct endpoints', () async {
      final store = SharedPrefsTrustedHostStore();
      await store.save(identity('example.com', 22, 'MD5:p22'));
      await store.save(identity('example.com', 2222, 'MD5:p2222'));

      expect((await store.get('example.com', 22))!.fingerprint, 'MD5:p22');
      expect((await store.get('example.com', 2222))!.fingerprint, 'MD5:p2222');
      expect((await store.getAll()).length, 2);
    });

    test('remove forgets the identity (next get is first-use)', () async {
      final store = SharedPrefsTrustedHostStore();
      await store.save(identity('example.com', 22, 'MD5:aa'));
      await store.remove('example.com', 22);
      expect(await store.get('example.com', 22), isNull);
    });

    test('persists across store instances (shared storage)', () async {
      await SharedPrefsTrustedHostStore().save(identity('h', 22, 'MD5:zz'));
      // A fresh instance reads the same SharedPreferences backing.
      final got = await SharedPrefsTrustedHostStore().get('h', 22);
      expect(got!.fingerprint, 'MD5:zz');
    });

    test('does not store fingerprints under the connections key', () async {
      await SharedPrefsTrustedHostStore().save(identity('h', 22, 'MD5:zz'));
      final prefs = await SharedPreferences.getInstance();
      // Dedicated namespace (FR-010): not co-mingled with connection JSON.
      expect(prefs.getString('connections'), isNull);
      expect(prefs.getString('trusted_host_identities'), isNotNull);
    });
  });
}
