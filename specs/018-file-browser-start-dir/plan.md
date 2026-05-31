# Plan — 018 file-browser start directory

## Design
- `file_browser_start.dart`: mode constants (`claudeCodeFolder`/`lastVisited`), a pure
  `startPathCandidates(mode, lastPath, claudeCodePath)` (ordered candidates; caller falls back to
  home), and `LastPathStore` (per-connection last path persisted as a JSON map in prefs).
- Settings: `AppSettings.fileBrowserStartDir` (default `claudeCodeFolder`) + setter + a "File browser"
  Settings section with an "Open at" picker.
- `FileBrowserNotifier.initialize(connectionId, paneId)`: build candidates from the mode + remembered
  path + pane CWD, try each (first that loads wins), else home. On every successful `loadDirectory`,
  remember the path per connection (fire-and-forget). The remembering is independent of the mode so
  history exists when the user later switches to "last visited".
- `FileBrowserScreen` passes `connectionId` to `initialize`.

## Files
- New: file_browser_start.dart; 2 test files.
- Modified: settings_provider.dart, file_browser_provider.dart, file_browser_screen.dart,
  settings_screen.dart.

## Verification
analyze exit 0; flutter test 393 (+11: candidate ordering, per-connection store round-trip/persist,
setting default/persist/normalise).
