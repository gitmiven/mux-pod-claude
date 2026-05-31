# Tasks — recent commands from Claude Code's history

- [x] **T001** Pure `parseClaudeHistory` (project filter, recency order, dedupe, cap, skip bad).
- [x] **T002** `ClaudeHistoryReader.read` — bounded `tail` of `~/.claude/history.jsonl` over SSH; null if N/A.
- [x] **T003** Async-capable shared sheet (loading + `load` with `fallback`).
- [x] **T004** `loadRecentCommands` on InputDialogContent + SpecialKeysBar; both use it.
- [x] **T005** terminal `_loadRecentCommands` (Claude for pane project, else app history); wire both.
- [x] **T006** [TDD] Tests: parser cases; sheet async load / fallback / no-loader (+7).
- [x] **T007** Gate: analyze exit 0; flutter test 434.
- [ ] **T008** Commit, push, PR; CI green.
