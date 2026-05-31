# Tasks — Decompose terminal_screen.dart (Slice 1)

- [x] **T001** Map the file; confirm the 7 helper classes (3294–4527) are self-contained (no top-level private deps, all imports already present).
- [x] **T002** Extract into 5 files under `lib/screens/terminal/widgets/`: pane_layout_visualizer, input_dialog_content, new_window_dialog, resize_pane_chooser_dialog, resize_window_chooser_dialog. Publicize the 6 referenced widgets; keep split-icon painters + *State classes private; add `super.key`.
- [x] **T003** Rewrite `terminal_screen.dart`: remove the classes + the test-only factory, add 5 imports, rename the 6 call sites. Preserve CRLF.
- [x] **T004** Update `test/widgets/input_dialog_test.dart` to import `InputDialogContent` directly.
- [x] **T005** Add `test/screens/terminal/widgets/new_window_dialog_test.dart` (name validation: special chars, duplicate, valid+pop).
- [x] **T006** Verify: `flutter analyze --no-fatal-infos` exit 0 (31 infos, no errors/warnings); `flutter test` 328 pass / 0 fail; line count 4,527 → 3,291.
- [ ] **T007** Commit, push, open PR; CI green.

## Follow-up slices (not this PR)
- Extract polling/capture engine, input/IME/key handling, copy-mode/scroll, and tmux session/window/pane
  operations from `_TerminalScreenState` into testable controllers, each with unit tests (#5).
