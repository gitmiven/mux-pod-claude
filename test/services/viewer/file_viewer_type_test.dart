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

  group('new viewer types (csv / archive / external)', () {
    test('fromName resolves the new types', () {
      expect(FileViewerType.fromName('csv'), FileViewerType.csv);
      expect(FileViewerType.fromName('Archive'), FileViewerType.archive);
      expect(FileViewerType.fromName('EXTERNAL'), FileViewerType.external);
    });

    test('isExternal is true only for external', () {
      expect(FileViewerType.external.isExternal, isTrue);
      expect(FileViewerType.csv.isExternal, isFalse);
      expect(FileViewerType.archive.isExternal, isFalse);
      expect(FileViewerType.image.isExternal, isFalse);
    });

    test('defaults map the requested extensions', () {
      expect(kDefaultFileViewers['csv'], 'csv');
      expect(kDefaultFileViewers['zip'], 'archive');
      for (final ext in ['html', 'mp4', 'webm', 'xls', 'doc']) {
        expect(kDefaultFileViewers[ext], 'external', reason: ext);
      }
    });

    test('every default value is a known viewer type', () {
      for (final v in kDefaultFileViewers.values) {
        expect(FileViewerType.fromName(v), isNotNull, reason: v);
      }
    });
  });
}
