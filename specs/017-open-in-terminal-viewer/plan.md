# Plan — 017 open a file in an in-app viewer

## Design (revised: in-app, not terminal tools)
- `FileViewerType { image, markdown, text }` enum + `forExtension(map, ext)` resolver +
  `kDefaultFileViewers` (lib/services/viewer/file_viewer_type.dart).
- Settings: `AppSettings.fileViewers` (ext → type-name), persisted as JSON; add/edit/remove via
  `setFileViewer`/`removeFileViewer`/`setFileViewers`; defaults on first run. Settings UI section
  "File viewers" (list + add/edit dialog with a SegmentedButton of the three types).
- SFTP read: `SftpBrowserService.readFileBytes(sftp, path, maxBytes)` with a 5 MiB cap (stat-checks
  size, refuses oversize via `FileTooLargeException`).
- Menu: new `FileAction.openInViewer`, shown for files with a configured viewer, labelled
  "Open with <type>", placed between the name/path header and Rename.
- Browser: resolve the type from settings, pass the label to the menu, and on selection push
  `FileViewerScreen` (fetches over SFTP, renders Image via InteractiveViewer / Markdown via
  flutter_markdown_plus / Text via SelectableText, with loading + error states). Nothing is sent to
  the pane.

## Files
- New: file_viewer_type.dart, file_viewer_screen.dart; 3 test files.
- Modified: settings_provider.dart, sftp_browser_service.dart, file_action_menu.dart,
  file_browser_screen.dart, settings_screen.dart, pubspec (flutter_markdown_plus).

## Verification
analyze exit 0; flutter test 382 (+14: type resolution, settings round-trip/persist, menu construction).
