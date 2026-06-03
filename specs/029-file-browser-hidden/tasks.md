# Tasks — file browser: show hidden files by default

- [ ] **T001** Settings: `AppSettings.showHiddenFilesByDefault` (bool, default false) + `copyWith` +
      prefs key `settings_show_hidden_files_default` (load/save) + `setShowHiddenFilesByDefault` setter
      — mirror `prefillCommandFromTerminal`.
- [ ] **T002** `FileBrowserNotifier.initialize`: seed `FileBrowserState(showHidden: settings.showHiddenFilesByDefault)`
      instead of `const FileBrowserState()`.
- [ ] **T003** Settings UI: add "Show hidden files by default" `SwitchListTile` in the existing File
      browser section (with "Open at").
- [ ] **T004** [TDD] Tests: setting default/round-trip; `initialize` seeds `showHidden` on (true) and
      off (false); eye toggle still flips per-session without mutating the setting.
- [ ] **T005** Gate: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 448 (+ new).
- [ ] **T006** Commit, push, PR; CI green.
