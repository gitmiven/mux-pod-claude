import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/viewer/file_parsers.dart';

void main() {
  group('parseCsvRows', () {
    test('parses rows and columns', () {
      final rows = parseCsvRows('a,b,c\n1,2,3\n');
      expect(rows.first, ['a', 'b', 'c']);
      expect(rows[1], ['1', '2', '3']);
    });

    test('handles quoted commas and CRLF', () {
      final rows = parseCsvRows('name,note\r\n"Smith, J",hi\r\n');
      expect(rows[1], ['Smith, J', 'hi']);
    });

    test('empty input yields no rows', () {
      expect(parseCsvRows('   '), isEmpty);
    });
  });

  group('listZipEntries', () {
    Uint8List buildZip() {
      final archive = Archive()
        ..addFile(ArchiveFile.string('readme.txt', 'hello'))
        ..addFile(ArchiveFile.string('dir/data.csv', 'x,y'));
      return ZipEncoder().encodeBytes(archive);
    }

    test('lists entries with names, sizes, and is-file', () {
      final entries = listZipEntries(buildZip());
      final names = entries.map((e) => e.name).toList();
      expect(names, containsAll(['readme.txt', 'dir/data.csv']));

      final readme = entries.firstWhere((e) => e.name == 'readme.txt');
      expect(readme.size, 5); // 'hello'
      expect(readme.isFile, isTrue);
    });
  });
}
