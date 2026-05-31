import 'dart:async';
import 'dart:typed_data';

import 'host_key_fingerprint.dart';
import 'trusted_host_identity.dart';
import 'trusted_host_store.dart';

/// TOFU verification result determination.
enum HostKeyVerificationOutcome {
  /// No stored identity → first-time trust (committed after successful authentication).
  firstUse,

  /// Presented identity matches stored → continue as-is.
  match,

  /// Presented identity does not match stored → fail-close and present to user.
  mismatch,
}

/// Typed exception indicating host key has changed.
///
/// Thrown by [SshClient.connect] when [storedFingerprint] (previously trusted for
/// [host]/[port] endpoint) differs from [presentedFingerprint] (just presented).
/// Warning and diagnostic output must not contain any secret information
/// (passwords/passphrases/private keys) (FR-015).
class SshHostKeyChangedError implements Exception {
  final String host;
  final int port;
  final String storedFingerprint;
  final String presentedFingerprint;
  final String keyType;

  SshHostKeyChangedError({
    required this.host,
    required this.port,
    required this.storedFingerprint,
    required this.presentedFingerprint,
    required this.keyType,
  });

  @override
  String toString() =>
      'SshHostKeyChangedError: host identity for $host:$port changed '
      '(was $storedFingerprint, now $presentedFingerprint, $keyType)';
}

/// Host key verifier (TOFU) for a single connection attempt.
///
/// Call [verify] from dartssh2's `onVerifyHostKey(type, md5)` to determine trust/rejection.
/// Since keys are signature-verified at protocol layer, only judge 'trust' here.
/// Persist trust via [commit] after successful authentication (to avoid tainting trust with failed auth · D3).
class HostKeyVerifier {
  final TrustedHostStore store;
  final String host;
  final int port;

  /// True if user explicitly re-trusted despite mismatch (FR-005).
  final bool trustNewHostKey;

  HostKeyVerifier({
    required this.store,
    required this.host,
    required this.port,
    this.trustNewHostKey = false,
  });

  /// Identity to commit after successful authentication (first-time trust or re-trust).
  TrustedHostIdentity? _pendingSave;

  /// Matched existing identity (update lastVerifiedAt after successful authentication).
  TrustedHostIdentity? _matched;

  /// Information when mismatch is detected (set when [trustNewHostKey] is false).
  SshHostKeyChangedError? pendingMismatch;

  /// Pure decision logic (dartssh2-independent, test-friendly).
  static HostKeyVerificationOutcome decide(
    TrustedHostIdentity? stored,
    String presentedFingerprint,
  ) {
    if (stored == null) return HostKeyVerificationOutcome.firstUse;
    if (stored.fingerprint == presentedFingerprint) {
      return HostKeyVerificationOutcome.match;
    }
    return HostKeyVerificationOutcome.mismatch;
  }

  /// dartssh2's onVerifyHostKey callback body.
  ///
  /// [type] is host key algorithm name, [md5Digest] is host key MD5 digest.
  /// Return true to accept, false to reject (abort handshake).
  FutureOr<bool> verify(String type, Uint8List md5Digest) async {
    final presented = HostKeyFingerprint.formatMd5(md5Digest);
    final stored = await store.get(host, port);
    final outcome = decide(stored, presented);
    final now = DateTime.now();

    switch (outcome) {
      case HostKeyVerificationOutcome.firstUse:
        _pendingSave = TrustedHostIdentity(
          host: host,
          port: port,
          fingerprint: presented,
          keyType: type,
          firstTrustedAt: now,
          lastVerifiedAt: now,
        );
        return true;

      case HostKeyVerificationOutcome.match:
        _matched = stored;
        return true;

      case HostKeyVerificationOutcome.mismatch:
        if (trustNewHostKey) {
          // Explicit re-trust: replace with new identity (firstTrustedAt is reset).
          _pendingSave = TrustedHostIdentity(
            host: host,
            port: port,
            fingerprint: presented,
            keyType: type,
            firstTrustedAt: now,
            lastVerifiedAt: now,
          );
          return true;
        }
        pendingMismatch = SshHostKeyChangedError(
          host: host,
          port: port,
          storedFingerprint: stored!.fingerprint,
          presentedFingerprint: presented,
          keyType: type,
        );
        return false;
    }
  }

  /// Persist trust after successful authentication (D3: first *successful* connection).
  Future<void> commit() async {
    if (_pendingSave != null) {
      await store.save(_pendingSave!);
    } else if (_matched != null) {
      await store.save(_matched!.copyWith(lastVerifiedAt: DateTime.now()));
    }
  }
}
