import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/viewer/file_viewer_type.dart';

void main() {
  group('FileViewerType.fromName', () {
    test('parses known names case-insensitively', () {
      expect(FileViewerType.fromName('image'), FileViewerType.image);
      expect(FileViewerType.fromName('MARKDOWN'), FileViewerType.markdown);
      expect(FileViewerType.fromName(' Text '), FileViewerType.text);
    });

    test('returns null for unknown/empty/null', () {
      expect(FileViewerType.fromName('bogus'), isNull);
      expect(FileViewerType.fromName(''), isNull);
      expect(FileViewerType.fromName(null), isNull);
    });
  });

  group('FileViewerType.label', () {
    test('is the display name', () {
      expect(FileViewerType.image.label, 'Image');
      expect(FileViewerType.markdown.label, 'Markdown');
      expect(FileViewerType.text.label, 'Text');
    });
  });

  group('FileViewerType.forExtension', () {
    const map = {'png': 'image', 'md': 'markdown', 'log': 'text'};

    test('resolves a mapped extension (case-insensitive)', () {
      expect(FileViewerType.forExtension(map, 'png'), FileViewerType.image);
      expect(FileViewerType.forExtension(map, 'PNG'), FileViewerType.image);
      expect(FileViewerType.forExtension(map, 'md'), FileViewerType.markdown);
    });

    test('returns null for an unmapped or empty extension', () {
      expect(FileViewerType.forExtension(map, 'xyz'), isNull);
      expect(FileViewerType.forExtension(map, ''), isNull);
    });
  });

  group('kDefaultFileViewers', () {
    test('maps common images to image, md to markdown, txt/log to text', () {
      for (final ext in ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp']) {
        expect(kDefaultFileViewers[ext], 'image', reason: ext);
      }
      expect(kDefaultFileViewers['md'], 'markdown');
      expect(kDefaultFileViewers['markdown'], 'markdown');
      expect(kDefaultFileViewers['txt'], 'text');
      expect(kDefaultFileViewers['log'], 'text');
    });
  });
}
