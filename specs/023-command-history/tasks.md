# Tasks — recent-commands history in the command popup

- [x] **T001** Pure `addCommandToHistory` (dedup/move-to-front/cap/ignore-empty) + `commandHistoryProvider`.
- [x] **T002** Replace the popup's Shift+Enter badge with a history button + picker (reuses onSend).
- [x] **T003** Record each successful send in the history; pass `recentCommands` to the popup.
- [x] **T004** [TDD] Tests: list ops; provider round-trip; button present / lists+sends / empty state (+9).
- [x] **T005** Gate: analyze exit 0; flutter test 422.
- [ ] **T006** Commit, push, PR; CI green.
