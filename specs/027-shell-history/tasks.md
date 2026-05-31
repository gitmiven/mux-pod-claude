# Tasks — shell history as a recent-commands source

- [x] **T001** Pure `parseBashHistory` + `parseZshHistory` (newest-first, dedupe, skip blanks/comments).
- [x] **T002** `ShellHistoryReader.read` — bounded tail of bash/zsh history over SSH, shell-hint choice.
- [x] **T003** Insert shell tier into `_loadRecentCommands` (Claude → shell → app).
- [x] **T004** [TDD] Tests: bash + zsh parsers (order/dedupe/cap/comments/extended/plain) (+6).
- [x] **T005** Gate: analyze exit 0; flutter test 448.
- [ ] **T006** Commit, push, PR; CI green.
