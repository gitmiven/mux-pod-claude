import 'dart:typed_data';

/// Helper for handling SSH host key fingerprint representations.
///
/// The `fingerprint` passed by dartssh2's `onVerifyHostKey(type, fingerprint)`
/// is the **MD5 digest** (raw bytes) of the host key. This formats it into
/// an OpenSSH-compatible human-comparable format `MD5:xx:xx:...` (lowercase
/// hexadecimal separated by colons).
///
/// Note: Since the raw host key bytes are not passed to the callback, SHA256
/// cannot be computed here. The output is comparable to `ssh-keygen -l -E md5`
/// display and can be used for out-of-band verification.
class HostKeyFingerprint {
  const HostKeyFingerprint._();

  /// Formats an MD5 digest byte sequence into a string in `MD5:xx:xx:...` format.
  static String formatMd5(Uint8List digest) {
    final hex = digest
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
    return 'MD5:$hex';
  }
}
