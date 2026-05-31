import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

/// Parses CSV [text] into rows of string cells (line endings auto-detected;
/// values kept as strings).
List<List<String>> parseCsvRows(String text) {
  if (text.trim().isEmpty) return const [];
  final rows = const CsvDecoder(dynamicTyping: false).convert(text);
  return [
    for (final row in rows) [for (final cell in row) cell?.toString() ?? ''],
  ];
}

/// One entry inside a zip archive.
typedef ZipEntry = ({String name, int size, bool isFile});

/// Lists the entries of a zip [bytes] (name, uncompressed size, is-file).
List<ZipEntry> listZipEntries(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return [
    for (final f in archive.files)
      (name: f.name, size: f.size, isFile: f.isFile),
  ];
}
