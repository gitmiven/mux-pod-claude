# Tasks — button-bar re-layout + bar history button

- [x] **T001** Extract shared `recent_commands_sheet.dart`; popup uses it.
- [x] **T002** SpecialKeysBar: `recentCommands` + `onSendCommand` params.
- [x] **T003** Bar 2: insert Up at column 2 (`_buildArrowKeyCell`).
- [x] **T004** Bar 3: grid Left/Down/Right (col 2 = Down under Up), reserved col 4, flex-6 action group.
- [x] **T005** History button on bar 3 → shared picker → onSendCommand.
- [x] **T006** Wire terminal_screen (recentCommands + send/record); remove unused fixed arrow button.
- [x] **T007** [TDD] Widget tests: placement, Up-over-Down alignment, arrows, history (+5).
- [x] **T008** Gate: analyze exit 0; flutter test 427.
- [ ] **T009** Commit, push, PR; CI green.
