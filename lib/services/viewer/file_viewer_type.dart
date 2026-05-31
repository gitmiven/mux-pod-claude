/// The in-app viewers a file can open with, chosen per file extension.
///
/// The mapping (extension → viewer type) is user-configurable and persisted in
/// settings; the file browser opens the matching viewer screen, which fetches
/// the file over SFTP and renders it in the app (no terminal involved).
enum FileViewerType {
  image,
  markdown,
  text,
  csv,
  archive,
  external;

  /// Human-readable label for the menu / settings (e.g. "Image").
  String get label => switch (this) {
        FileViewerType.image => 'Image',
        FileViewerType.markdown => 'Markdown',
        FileViewerType.text => 'Text',
        FileViewerType.csv => 'CSV',
        FileViewerType.archive => 'Archive',
        FileViewerType.external => 'External app',
      };

  /// Whether opening this type leaves the app (download + system "Open with"),
  /// rather than rendering in an in-app viewer screen.
  bool get isExternal => this == FileViewerType.external;

  /// Parse from a stored type name (case-insensitive); null if unrecognised.
  static FileViewerType? fromName(String? name) {
    switch (name?.toLowerCase().trim()) {
      case 'image':
        return FileViewerType.image;
      case 'markdown':
        return FileViewerType.markdown;
      case 'text':
        return FileViewerType.text;
      case 'csv':
        return FileViewerType.csv;
      case 'archive':
        return FileViewerType.archive;
      case 'external':
        return FileViewerType.external;
      default:
        return null;
    }
  }

  /// The viewer configured for [extension] (bare, no dot; matched
  /// case-insensitively) in [mapping] (extension → type-name), or null when
  /// nothing is mapped — in which case no viewer item is shown.
  static FileViewerType? forExtension(
    Map<String, String> mapping,
    String extension,
  ) {
    if (extension.isEmpty) return null;
    return fromName(mapping[extension.toLowerCase()]);
  }
}

/// Default extension → viewer-type-name mappings (FR-005): common image formats
/// open in the Image viewer, markdown in Markdown, plain text/logs in Text.
const Map<String, String> kDefaultFileViewers = {
  'png': 'image',
  'jpg': 'image',
  'jpeg': 'image',
  'gif': 'image',
  'webp': 'image',
  'bmp': 'image',
  'md': 'markdown',
  'markdown': 'markdown',
  'txt': 'text',
  'log': 'text',
  'csv': 'csv',
  'zip': 'archive',
  // Opened in the device's system app ("Open with…").
  'html': 'external',
  'mp4': 'external',
  'webm': 'external',
  'xls': 'external',
  'doc': 'external',
};
