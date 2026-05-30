import 'dart:async';
import 'dart:typed_data';

import 'host_key_fingerprint.dart';
import 'trusted_host_identity.dart';
import 'trusted_host_store.dart';

/// TOFU検証の判定結果。
enum HostKeyVerificationOutcome {
  /// 保存済み identity が無い → 初回信頼（認証成功後にコミット）。
  firstUse,

  /// 提示された identity が保存済みと一致 → そのまま続行。
  match,

  /// 提示された identity が保存済みと不一致 → フェイルクローズしてユーザーに提示。
  mismatch,
}

/// ホスト鍵が変化したことを示す型付き例外。
///
/// [host]/[port] のエンドポイントに対し、以前信頼した [storedFingerprint] と今回提示された
/// [presentedFingerprint] が異なる場合に [SshClient.connect] が送出する。警告・診断出力には
/// 秘密情報（パスワード/パスフレーズ/秘密鍵）を一切含めない（FR-015）。
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

/// 1回の接続試行に対するホスト鍵検証器（TOFU）。
///
/// dartssh2 の `onVerifyHostKey(type, md5)` から [verify] を呼び、信頼/拒否を判定する。
/// 鍵はプロトコル層で署名検証済みのため、ここでは「信頼」のみを判断する。
/// 信頼の永続化は認証成功後に [commit] で行う（失敗した認証で信頼を汚染しないため・D3）。
class HostKeyVerifier {
  final TrustedHostStore store;
  final String host;
  final int port;

  /// ユーザーが不一致を明示的に再信頼した場合に true（FR-005）。
  final bool trustNewHostKey;

  HostKeyVerifier({
    required this.store,
    required this.host,
    required this.port,
    this.trustNewHostKey = false,
  });

  /// 認証成功後にコミットすべき identity（初回信頼・再信頼）。
  TrustedHostIdentity? _pendingSave;

  /// 一致した既存 identity（認証成功後に lastVerifiedAt を更新）。
  TrustedHostIdentity? _matched;

  /// 不一致を検知した場合の情報（[trustNewHostKey] が false のとき設定）。
  SshHostKeyChangedError? pendingMismatch;

  /// 純粋な判定ロジック（dartssh2 非依存・テスト容易）。
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

  /// dartssh2 の `onVerifyHostKey` コールバック本体。
  ///
  /// [type] はホスト鍵アルゴリズム名、[md5Digest] はホスト鍵のMD5ダイジェスト。
  /// 受理する場合 true、拒否（ハンドシェイク中断）する場合 false を返す。
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
          // 明示的な再信頼: 新しい identity で置換（firstTrustedAt はリセット）。
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

  /// 認証成功後に信頼を永続化する（D3: first *successful* connection）。
  Future<void> commit() async {
    if (_pendingSave != null) {
      await store.save(_pendingSave!);
    } else if (_matched != null) {
      await store.save(_matched!.copyWith(lastVerifiedAt: DateTime.now()));
    }
  }
}
