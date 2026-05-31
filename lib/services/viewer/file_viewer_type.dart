/// The in-app viewers a file can open with, chosen per file extension.
///
/// The mapping (extension → viewer type) is user-configurable and persisted in
/// settings; the file browser opens the matching viewer screen, which fetches
/// the file over SFTP and renders it in the app (no terminal involved).
enum FileViewerType {
  image,
  markdown,
  text;

  /// Human-readable label for the menu / settings (e.g. "Image").
  String get label => switch (this) {
        FileViewerType.image => 'Image',
        FileViewerType.markdown => 'Markdown',
        FileViewerType.text => 'Text',
      };

  /// Parse from a stored type name (case-insensitive); null if unrecognised.
  static FileViewerType? fromName(String? name) {
    switch (name?.toLowerCase().trim()) {
      case 'image':
        return FileViewerType.image;
      case 'markdown':
        return FileViewerType.markdown;
      case 'text':
        return FileViewerType.text;
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
};
