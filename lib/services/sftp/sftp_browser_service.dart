import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import 'file_entry.dart';

/// Thrown when a file is larger than the read cap for in-app viewing.
class FileTooLargeException implements Exception {
  final int size;
  final int limit;
  const FileTooLargeException(this.size, this.limit);
  @override
  String toString() => 'FileTooLargeException(size: $size, limit: $limit)';
}

/// SFTP file browser service
///
/// Provides browser operations such as directory listing, deletion, renaming,
/// and folder creation. Upload operations are handled by [SftpService].
class SftpBrowserService {
  static const _listTimeout = Duration(seconds: 10);
  static const _readTimeout = Duration(seconds: 20);

  /// Default cap for in-app file viewing (5 MiB). Larger files are refused
  /// rather than risking an out-of-memory load.
  static const int defaultReadCap = 5 * 1024 * 1024;

  /// Reads up to [maxBytes] of the file at [path] for in-app viewing.
  ///
  /// Throws [FileTooLargeException] when the file's reported size exceeds
  /// [maxBytes] (checked via `stat` before reading), so an oversized/binary
  /// file can't OOM the app.
  Future<Uint8List> readFileBytes(
    SftpClient sftp,
    String path, {
    int maxBytes = defaultReadCap,
  }) async {
    final normalizedPath = validatePath(path);
    final file = await sftp.open(normalizedPath).timeout(_readTimeout);
    try {
      final attrs = await file.stat().timeout(_readTimeout);
      final size = attrs.size;
      if (size != null && size > maxBytes) {
        throw FileTooLargeException(size, maxBytes);
      }
      // Read one byte past the cap so we can detect files that under-report size.
      final bytes =
          await file.readBytes(length: maxBytes + 1).timeout(_readTimeout);
      if (bytes.length > maxBytes) {
        throw FileTooLargeException(bytes.length, maxBytes);
      }
      return bytes;
    } finally {
      await file.close();
    }
  }

  /// Default cap for downloading a file to open in an external app (100 MiB).
  static const int defaultDownloadCap = 100 * 1024 * 1024;

  /// Streams the remote file at [path] into [dest], up to [maxBytes]. Throws
  /// [FileTooLargeException] when the file exceeds the cap (so a huge file
  /// can't fill the device). Used for "open with" downloads.
  Future<void> downloadToFile(
    SftpClient sftp,
    String path,
    File dest, {
    int maxBytes = defaultDownloadCap,
  }) async {
    final normalizedPath = validatePath(path);
    final file = await sftp.open(normalizedPath).timeout(_readTimeout);
    final sink = dest.openWrite();
    var written = 0;
    try {
      final attrs = await file.stat().timeout(_readTimeout);
      final size = attrs.size;
      if (size != null && size > maxBytes) {
        throw FileTooLargeException(size, maxBytes);
      }
      await for (final chunk in file.read()) {
        written += chunk.length;
        if (written > maxBytes) {
          throw FileTooLargeException(written, maxBytes);
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
      await file.close();
    }
  }

  /// Get directory listing
  ///
  /// Returns the directory contents at [path] as a list of [FileEntry].
  /// `.` and `..` entries are excluded.
  /// Throws an exception if the timeout (10 seconds) is exceeded.
  Future<List<FileEntry>> listDirectory(
    SftpClient sftp,
    String path,
  ) async {
    final normalizedPath = validatePath(path);
    final names = await sftp.listdir(normalizedPath).timeout(_listTimeout);

    return names
        .where((n) => n.filename != '.' && n.filename != '..')
        .map((n) => FileEntry.fromSftpName(n, normalizedPath))
        .toList();
  }

  /// Delete a file
  Future<void> deleteFile(SftpClient sftp, String path) async {
    final normalizedPath = validatePath(path);
    await sftp.remove(normalizedPath);
  }

  /// Delete a directory (empty directories only)
  Future<void> deleteDirectory(SftpClient sftp, String path) async {
    final normalizedPath = validatePath(path);
    await sftp.rmdir(normalizedPath);
  }

  /// Rename a file or directory
  Future<void> rename(
    SftpClient sftp,
    String oldPath,
    String newPath,
  ) async {
    final normalizedOld = validatePath(oldPath);
    final normalizedNew = validatePath(newPath);
    await sftp.rename(normalizedOld, normalizedNew);
  }

  /// Create a directory
  Future<void> createDirectory(SftpClient sftp, String path) async {
    final normalizedPath = validatePath(path);
    await sftp.mkdir(normalizedPath);
  }

  /// Get the path to the home directory
  Future<String> getHomeDirectory(SftpClient sftp) async {
    return await sftp.absolute('.');
  }

  /// Normalize and validate path
  ///
  /// Normalizes the path to prevent path traversal attacks.
  /// Only absolute paths are allowed.
  String validatePath(String path) {
    if (path.isEmpty) return '/';
    final normalized = p.posix.normalize(path);
    if (!normalized.startsWith('/')) {
      return '/$normalized';
    }
    return normalized;
  }

  /// Sort entries
  List<FileEntry> sortEntries(
    List<FileEntry> entries,
    SortOption option,
    bool ascending,
  ) {
    final sorted = List<FileEntry>.from(entries);
    sorted.sort((a, b) {
      // Always put directories at the top
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int result;
      switch (option) {
        case SortOption.name:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortOption.size:
          result = (a.size ?? 0).compareTo(b.size ?? 0);
        case SortOption.date:
          result = (a.modifiedTime ?? 0).compareTo(b.modifiedTime ?? 0);
        case SortOption.type:
          result = a.extension.compareTo(b.extension);
          if (result == 0) {
            result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
      }
      return ascending ? result : -result;
    });
    return sorted;
  }

  /// Filter hidden files
  List<FileEntry> filterHidden(List<FileEntry> entries, bool showHidden) {
    if (showHidden) return entries;
    return entries.where((e) => !e.isHidden).toList();
  }
}
