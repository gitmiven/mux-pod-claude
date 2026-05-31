# Tasks — Logging Utility & Secret-Leak Audit

- [x] **T001** Test: `test/services/logging/app_log_test.dart` — level gating (off suppresses all;
  below-threshold suppressed, at/above emitted), tag/level format, error+stackTrace emission,
  never-throws when sink throws.
- [x] **T002** Impl: `lib/services/logging/app_log.dart` — `AppLog` + `LogLevel` + `LogSink`,
  release-off default, try/catch. Make green.
- [x] **T003** Migrate all `developer.log(name:)` sites → `AppLog.d/e(tag:)`; remove
  `dart:developer` imports; add `app_log.dart` imports. CRLF-preserving.
- [x] **T004** Migrate all `debugPrint(` sites → `AppLog.d`; add `app_log.dart` imports.
- [x] **T005** Secret fix: `ssh_client.dart` — stop logging raw `stdout`/`stderr` content (log byte
  counts only). Audit `persistent_shell`, `terminal_screen_logic`, `tmux_parser` for content logging.
- [x] **T006** Verify SC-001: 0 `print(`/`debugPrint(`/`developer.log(` in `lib/` outside `app_log.dart`.
- [x] **T007** Verify gate: `flutter analyze --no-fatal-infos` exit 0; `flutter test` 328+ pass.
- [x] **T008** Update `CLAUDE.md`; commit, push, PR; CI green.

## Traceability
| FR/SC | Tasks |
|-------|-------|
| FR-001,002,005,006 / SC-002,003 | T001, T002 |
| FR-003 / SC-001 | T003, T004, T006 |
| FR-004 / SC-004 | T005 |
| SC-005 | T007 |
