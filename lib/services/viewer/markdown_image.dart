import 'package:path/path.dart' as p;

/// Maps a markdown image reference [ref] (as it appears inside the document at
/// [markdownFilePath]) to a concrete **remote SFTP path**, or returns null when
/// the reference should not be fetched over SFTP (a network `http`/`https` URL
/// or an inline `data:` URI).
///
/// A relative reference is resolved against the directory of the markdown file;
/// an absolute reference is kept as-is. Remote paths are POSIX (the server is
/// Linux), so resolution uses the `path` package's posix context regardless of
/// the phone's platform.
String? resolveRemoteImagePath(String markdownFilePath, Uri ref) {
  switch (ref.scheme) {
    case 'http':
    case 'https':
    case 'data':
      return null;
  }

  // Decode percent-encoding (e.g. `my%20img.png`) to the real remote filename.
  final refPath = Uri.decodeComponent(ref.path);
  if (refPath.isEmpty) return null;

  if (refPath.startsWith('/')) return p.posix.normalize(refPath);

  final dir = p.posix.dirname(markdownFilePath);
  return p.posix.normalize(p.posix.join(dir, refPath));
}
