import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/ssh/host_key_fingerprint.dart';
import 'package:flutter_muxpod/services/ssh/host_key_verifier.dart';
import 'package:flutter_muxpod/services/ssh/trusted_host_identity.dart';
import 'package:flutter_muxpod/services/ssh/trusted_host_store.dart';

/// In-memory store for unit-testing the verifier in isolation.
class _FakeStore implements TrustedHostStore {
  final Map<String, TrustedHostIdentity> _data = {};

  @override
  Future<TrustedHostIdentity?> get(String host, int port) async =>
      _data['$host:$port'];

  @override
  Future<List<TrustedHostIdentity>> getAll() async => _data.values.toList();

  @override
  Future<void> save(TrustedHostIdentity identity) async =>
      _data[identity.endpointKey] = identity;

  @override
  Future<void> remove(String host, int port) async =>
      _data.remove('$host:$port');
}

void main() {
  final md5A = Uint8List.fromList([0xaa, 0xbb, 0xcc]);
  final md5B = Uint8List.fromList([0x11, 0x22, 0x33]);
  final fpA = HostKeyFingerprint.formatMd5(md5A);
  final fpB = HostKeyFingerprint.formatMd5(md5B);

  TrustedHostIdentity stored(String fp) => TrustedHostIdentity(
    host: 'h',
    port: 22,
    fingerprint: fp,
    keyType: 'ssh-ed25519',
    firstTrustedAt: DateTime.utc(2020, 1, 1),
    lastVerifiedAt: DateTime.utc(2020, 1, 1),
  );

  group('HostKeyVerifier.decide (pure)', () {
    test('no stored identity → firstUse', () {
      expect(
        HostKeyVerifier.decide(null, fpA),
        HostKeyVerificationOutcome.firstUse,
      );
    });
    test('matching fingerprint → match', () {
      expect(
        HostKeyVerifier.decide(stored(fpA), fpA),
        HostKeyVerificationOutcome.match,
      );
    });
    test('different fingerprint → mismatch', () {
      expect(
        HostKeyVerifier.decide(stored(fpA), fpB),
        HostKeyVerificationOutcome.mismatch,
      );
    });
  });

  group('verify() + commit()', () {
    test(
      'first use: accepts, defers write, commit persists identity',
      () async {
        final store = _FakeStore();
        final v = HostKeyVerifier(store: store, host: 'h', port: 22);

        expect(await v.verify('ssh-ed25519', md5A), isTrue);
        // Trust is not committed before authentication.
        expect(await store.get('h', 22), isNull);
        expect(v.pendingMismatch, isNull);

        await v.commit();
        final saved = await store.get('h', 22);
        expect(saved!.fingerprint, fpA);
        expect(saved.keyType, 'ssh-ed25519');
      },
    );

    test(
      'match: accepts and commit refreshes lastVerifiedAt, keeps firstTrustedAt',
      () async {
        final store = _FakeStore();
        await store.save(stored(fpA));
        final v = HostKeyVerifier(store: store, host: 'h', port: 22);

        expect(await v.verify('ssh-ed25519', md5A), isTrue);
        expect(v.pendingMismatch, isNull);

        await v.commit();
        final saved = await store.get('h', 22);
        expect(saved!.fingerprint, fpA);
        expect(saved.firstTrustedAt, DateTime.utc(2020, 1, 1));
        expect(saved.lastVerifiedAt.isAfter(DateTime.utc(2020, 1, 1)), isTrue);
      },
    );

    test(
      'mismatch (no override): rejects, captures old+new, commits nothing',
      () async {
        final store = _FakeStore();
        await store.save(stored(fpA));
        final v = HostKeyVerifier(store: store, host: 'h', port: 22);

        expect(await v.verify('ssh-ed25519', md5B), isFalse);
        expect(v.pendingMismatch, isNotNull);
        expect(v.pendingMismatch!.storedFingerprint, fpA);
        expect(v.pendingMismatch!.presentedFingerprint, fpB);
        expect(v.pendingMismatch!.host, 'h');
        expect(v.pendingMismatch!.port, 22);

        await v.commit();
        // The stored identity is unchanged — no silent re-trust.
        expect((await store.get('h', 22))!.fingerprint, fpA);
      },
    );

    test(
      'mismatch with trustNewHostKey: accepts and commit replaces identity',
      () async {
        final store = _FakeStore();
        await store.save(stored(fpA));
        final v = HostKeyVerifier(
          store: store,
          host: 'h',
          port: 22,
          trustNewHostKey: true,
        );

        expect(await v.verify('rsa-sha2-256', md5B), isTrue);
        expect(v.pendingMismatch, isNull);

        await v.commit();
        final saved = await store.get('h', 22);
        expect(saved!.fingerprint, fpB);
        expect(saved.keyType, 'rsa-sha2-256');
      },
    );
  });

  group('SshHostKeyChangedError', () {
    test('carries endpoint and both fingerprints', () {
      final e = SshHostKeyChangedError(
        host: 'h',
        port: 22,
        storedFingerprint: fpA,
        presentedFingerprint: fpB,
        keyType: 'ssh-ed25519',
      );
      expect(e.host, 'h');
      expect(e.toString(), contains(fpA));
      expect(e.toString(), contains(fpB));
    });
  });
}
