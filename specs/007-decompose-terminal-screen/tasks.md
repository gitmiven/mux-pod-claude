# Tasks — Decompose terminal_screen.dart (Slice 1)

- [x] **T001** Map the file; confirm the 7 helper classes (3294–4527) are self-contained (no top-level private deps, all imports already present).
- [x] **T002** Extract into 5 files under `lib/screens/terminal/widgets/`: pane_layout_visualizer, input_dialog_content, new_window_dialog, resize_pane_chooser_dialog, resize_window_chooser_dialog. Publicize the 6 referenced widgets; keep split-icon painters + *State classes private; add `super.key`.
- [x] **T003** Rewrite `terminal_screen.dart`: remove the classes + the test-only factory, add 5 imports, rename the 6 call sites. Preserve CRLF.
- [x] **T004** Update `test/widgets/input_dialog_test.dart` to import `InputDialogContent` directly.
- [x] **T005** Add `test/screens/terminal/widgets/new_window_dialog_test.dart` (name validation: special chars, duplicate, valid+pop).
- [x] **T006** Verify: `flutter analyze --no-fatal-infos` exit 0 (31 infos, no errors/warnings); `flutter test` 328 pass / 0 fail; line count 4,527 → 3,291.
- [x] **T007** Commit, push, open PR (#4); CI green.

## Slice 2 — split the state class into part-file mixins (safe mechanical split)

- [x] **T008** Map all members of `_TerminalScreenState` (52 logic + 19 view + 6 lifecycle/build).
- [x] **T009** Move all fields + engine methods into `mixin _TerminalScreenLogic on ConsumerState<TerminalScreen>` (`terminal_screen_logic.dart`, `part of`).
- [x] **T010** Move presentation (`_build*`/`_show*`) into `mixin _TerminalScreenView on _TerminalScreenLogic` (`terminal_screen_view.dart`). One-directional View→Logic — no cross-mixin abstract contracts, no new infos.
- [x] **T011** Main file keeps only the widget, lifecycle overrides, and `build()`; adds `part` directives and `with _TerminalScreenLogic, _TerminalScreenView`. 4,527 → **389 lines**.
- [x] **T012** Verify: analyze exit 0 (31 issues, 0 new); `flutter test` 328 pass / 0 fail (behavior-identical mechanical move).

> Rationale: the state class is deeply coupled (shared mutable state, setState/ref throughout) with almost no terminal tests, so a true state-migrating controller rewrite was too risky. The part-file mixin split (user-chosen) decomposes the god-file safely with the analyzer as the correctness net. Further splitting of the logic mixin, or true controllers with characterization tests, can follow.
