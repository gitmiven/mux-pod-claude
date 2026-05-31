# Tasks — order in-session dropdown by recency

- [x] **T001** Add `#{session_activity}` to `listAllPanes()` format (appended last).
- [x] **T002** Add `TmuxSession.lastActivity` (+ copyWith) and the `byRecencyDesc` comparator.
- [x] **T003** Parse `session_activity` (parts[19]) in `parseFullTree` via `_parseTimestamp`.
- [x] **T004** Sort a copy of the sessions in `_showSessionSelector` with `byRecencyDesc`.
- [x] **T005** [TDD] Tests: parse with/without the token; comparator newest-first / null-last / name ties.
- [x] **T006** Gate: analyze exit 0; flutter test 368 (+5).
- [ ] **T007** Commit, push, PR; CI green.
