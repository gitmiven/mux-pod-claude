# Tasks — Terminal Characterization Tests

- [x] **T001** Study testable surfaces (SpecialKeysBar/AnsiTextView public callbacks; key logic).
- [x] **T002** `test/widgets/special_keys_bar_test.dart` — 7 tests: ESC/TAB/arrows/literal; CTRL→C-,
  CTRL+ALT→C-M- (S-C-M order), one-shot consume, SHIFT+TAB→BTab, SHIFT+ESC→S-Escape.
- [x] **T003** `test/screens/terminal/widgets/ansi_text_view_keys_test.dart` — 6 tests: Escape/Enter/
  Tab/Backspace bytes+names, arrows, modifier-only emits nothing. ProviderScope + mock prefs;
  explicit pumps (cursor-blink animation never settles).
- [x] **T004** Silence AppLog in tests (`flutter_test_config.dart` → `AppLog.level = none`).
- [x] **T005** Verify: analyze exit 0; `flutter test` 348 pass / 0 fail; no DEBUG noise.
- [ ] **T006** Commit, push, PR; CI green.

## Out of scope (future)
Full TerminalScreen integration tests (fake SSH harness), copy-mode/polling, IME-compose end-to-end.
