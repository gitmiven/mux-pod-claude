import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/ssh/host_key_fingerprint.dart';

void main() {
  group('HostKeyFingerprint.formatMd5', () {
    test('formats digest as MD5: + lowercase colon-hex', () {
      final digest = Uint8List.fromList([0x16, 0x27, 0xac, 0x4f]);
      expect(HostKeyFingerprint.formatMd5(digest), 'MD5:16:27:ac:4f');
    });

    test('zero-pads each byte to two hex digits', () {
      final digest = Uint8List.fromList([0x00, 0x01, 0x0f, 0x10, 0xff]);
      expect(HostKeyFingerprint.formatMd5(digest), 'MD5:00:01:0f:10:ff');
    });

    test('handles a full 16-byte MD5 digest', () {
      final digest = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final result = HostKeyFingerprint.formatMd5(digest);
      expect(result.startsWith('MD5:'), isTrue);
      // 16 bytes → 16 colon-separated hex pairs.
      expect(result.substring(4).split(':').length, 16);
      expect(result, 'MD5:00:01:02:03:04:05:06:07:08:09:0a:0b:0c:0d:0e:0f');
    });

    test('empty digest yields just the MD5: prefix', () {
      expect(HostKeyFingerprint.formatMd5(Uint8List(0)), 'MD5:');
    });
  });
}
