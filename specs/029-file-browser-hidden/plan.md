# Plan — 029 file browser: show hidden files by default

## Design

The hidden-file filter already exists end to end (`FileEntry.isHidden`, `filterHidden`,
`FileBrowserState.showHidden`, `toggleShowHidden()`, the AppBar eye). The only change is **where the
initial `showHidden` comes from** plus a Settings switch to control it.

- **Settings** (`settings_provider.dart`): add `AppSettings.showHiddenFilesByDefault` (bool, default
  `false`) — mirror `prefillCommandFromTerminal` exactly: field, constructor default, `copyWith` param,
  prefs key `settings_show_hidden_files_default`, load via `prefs.getBool(...) ?? false`, persist in the
  save path, and a `setShowHiddenFilesByDefault(bool)` setter on the notifier.
- **Browser init** (`file_browser_provider.dart`): in `initialize(connectionId, paneId)`, instead of
  `state = const FileBrowserState()`, seed the flag from settings —
  `state = FileBrowserState(showHidden: ref.read(settingsProvider).showHiddenFilesByDefault)`. Every
  subsequent `loadDirectory` already preserves `showHidden` via `copyWith` (it doesn't touch it), and
  `toggleShowHidden()` still flips it for the session.
- **Settings UI** (`settings_screen.dart`): in the existing **File browser** section (with "Open at"),
  add a `SwitchListTile` "Show hidden files by default" bound to the setting (same widget style as the
  other boolean settings).

No change to `FileBrowserScreen`, the eye toggle, `filterHidden`, or `displayEntries`.

## Files

- **Modified**: `lib/providers/settings_provider.dart` (new bool setting + key + setter),
  `lib/providers/file_browser_provider.dart` (seed `showHidden` in `initialize`),
  `lib/screens/settings/settings_screen.dart` (switch in the File browser section).
- **New**: 1–2 test files (or additions to existing settings/file-browser tests).

## Verification

`flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 448 (+ new: setting default/round-trip;
`initialize` seeds `showHidden` from the setting on/off; eye toggle still overrides per-session).
Manual: Settings → File browser → toggle on; reopen browser → `.claude/` visible without tapping the eye.

## Out of scope

Persisting the per-session toggle (memo option 2); default-on with no opt-out (memo option 3);
per-connection/per-pane memory; redefining "hidden".
