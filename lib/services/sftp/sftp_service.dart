import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:uuid/uuid.dart';

/// SFTP upload result
class SftpUploadResult {
  final String remotePath;
  final int bytesWritten;

  const SftpUploadResult({
    required this.remotePath,
    required this.bytesWritten,
  });
}

/// SFTP upload service
class SftpService {
  static const _uuid = Uuid();
  static final _safeCharsRegex = RegExp(r'[^a-zA-Z0-9._-]');

  /// Sanitize filename (permit only safe characters)
  ///
  /// Replace characters other than [a-zA-Z0-9._-] with `_`.
  static String sanitizeFilename(String raw) {
    if (raw.isEmpty) return 'unnamed';
    return raw.replaceAll(_safeCharsRegex, '_');
  }

  /// Generate unique filename from timestamp + shortened UUID
  ///
  /// Example: img_20260403_143025_a3f2.png
  static String generateFilename(String prefix, String extension) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final shortUuid = _uuid.v4().substring(0, 4);
    final sanitizedExt = extension.startsWith('.') ? extension.substring(1) : extension;
    return '${sanitizeFilename(prefix)}${timestamp}_$shortUuid.$sanitizedExt';
  }

  /// Check existence and create remote directory
  Future<void> ensureDirectory(SftpClient sftp, String remotePath) async {
    try {
      await sftp.stat(remotePath);
    } on SftpStatusError {
      await sftp.mkdir(remotePath);
    }
  }

  /// File upload
  ///
  /// [sftp] SFTP client
  /// [remoteDir] Remote directory path (trailing / optional)
  /// [filename] Filename
  /// [bytes] Byte data to upload
  /// [onProgress] Progress callback (0.0 ~ 1.0)
  Future<SftpUploadResult> upload({
    required SftpClient sftp,
    required String remoteDir,
    required String filename,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final dir = remoteDir.endsWith('/') ? remoteDir.substring(0, remoteDir.length - 1) : remoteDir;
    final remotePath = '$dir/$filename';

    await ensureDirectory(sftp, dir);

    SftpFile? file;
    try {
      file = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );

      final totalBytes = bytes.length;
      var written = 0;

      // Stream write with chunking (for progress tracking)
      const chunkSize = 32 * 1024; // 32KB
      final chunks = <Uint8List>[];
      for (var offset = 0; offset < totalBytes; offset += chunkSize) {
        final end = (offset + chunkSize > totalBytes) ? totalBytes : offset + chunkSize;
        chunks.add(bytes.sublist(offset, end));
      }

      final stream = Stream.fromIterable(chunks).map((chunk) {
        written += chunk.length;
        onProgress?.call(totalBytes > 0 ? written / totalBytes : 1.0);
        return chunk;
      });

      final writer = file.write(stream);
      await writer.done;

      return SftpUploadResult(remotePath: remotePath, bytesWritten: totalBytes);
    } catch (e) {
      // Attempt cleanup of partial file
      try {
        await sftp.remove(remotePath);
      } catch (_) {
        // Ignore cleanup failure
      }
      rethrow;
    } finally {
      await file?.close();
    }
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
