import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/viewer/markdown_image.dart';

void main() {
  const doc = '/srv/app/README.md';
  String? resolve(String src) => resolveRemoteImagePath(doc, Uri.parse(src));

  group('resolveRemoteImagePath', () {
    test('relative path resolves against the .md file directory', () {
      expect(resolve('logo.png'), '/srv/app/logo.png');
      expect(resolve('docs/arch.png'), '/srv/app/docs/arch.png');
      expect(resolve('./logo.png'), '/srv/app/logo.png');
    });

    test('parent-relative paths normalise', () {
      expect(resolve('../assets/banner.png'), '/srv/assets/banner.png');
      expect(resolve('../../x.png'), '/x.png');
    });

    test('absolute path is kept as-is (normalised)', () {
      expect(resolve('/opt/x/pic.png'), '/opt/x/pic.png');
      expect(resolve('/opt/./x/../pic.png'), '/opt/pic.png');
    });

    test('network and data URIs are not SFTP (null)', () {
      expect(resolve('https://example.com/i.png'), isNull);
      expect(resolve('http://example.com/i.png'), isNull);
      expect(resolve('data:image/png;base64,iVBORw0KGgo='), isNull);
    });

    test('percent-encoded spaces are decoded', () {
      expect(resolve('my%20img.png'), '/srv/app/my img.png');
    });

    test('empty reference yields null', () {
      expect(resolve(''), isNull);
    });
  });
}
