# Plan — 026 more file viewers

## Design
- FileViewerType: + csv, archive, external (+ `isExternal`, labels, fromName); defaults csv→csv,
  zip→archive, html/mp4/webm/xls/doc→external.
- Pure helpers (file_parsers.dart): `parseCsvRows` (csv 8.x `CsvDecoder`), `listZipEntries`
  (archive 4.x `ZipDecoder`).
- FileViewerScreen: csv → DataTable (cap 500 rows), archive → entry ListView.
- External: file_browser `_openInViewer` routes `isExternal` → `_openExternally` →
  `fileBrowserProvider.downloadToTemp` (streams via `SftpBrowserService.downloadToFile`, 100 MiB cap,
  path_provider temp) → `OpenFilex.open`; SnackBar on failure/oversize.
- Settings: type picker SegmentedButton → DropdownButtonFormField (6 types).

## Files
- New: file_parsers.dart; 2 test files.
- Modified: file_viewer_type.dart, file_viewer_screen.dart, sftp_browser_service.dart (+stream
  download), file_browser_provider.dart (downloadToTemp), file_browser_screen.dart (external route),
  settings_screen.dart (dropdown); pubspec (csv/archive/open_filex/path_provider).

## Verification
analyze exit 0; flutter test 442 (+8: csv parse, zip entries, new types/defaults/isExternal).
Android: open_filex FileProvider uses a unique authority (no conflict with image_picker) → release APK
builds; full APK build only runs on the release tag (no local Android toolchain).
