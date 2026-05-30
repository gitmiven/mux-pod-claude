import 'dart:typed_data';

/// SSHホスト鍵のフィンガープリント表現を扱うヘルパー。
///
/// dartssh2 の `onVerifyHostKey(type, fingerprint)` が渡す `fingerprint` は
/// ホスト鍵の **MD5ダイジェスト**（生バイト）である。これを OpenSSH 互換の
/// 人間が比較可能な形式 `MD5:xx:xx:...`（小文字16進をコロン区切り）に整形する。
///
/// 注: 生のホスト鍵バイトはコールバックに渡されないため、ここで SHA256 は計算できない。
/// 出力は `ssh-keygen -l -E md5` の表示と比較可能で、帯域外検証に利用できる。
class HostKeyFingerprint {
  const HostKeyFingerprint._();

  /// MD5ダイジェストのバイト列を `MD5:xx:xx:...` 形式の文字列に整形する。
  static String formatMd5(Uint8List digest) {
    final hex = digest
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
    return 'MD5:$hex';
  }
}
