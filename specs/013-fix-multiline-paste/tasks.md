# Tasks — Fix silent multi-line command send

- [x] **T001** Reproduce on the host: paste pipeline with bare tmux (3.4) vs the 3.6a server →
  `server exited unexpectedly`; with the absolute 3.6a path → pastes OK.
- [x] **T002** Extract the tmux path-resolution to a pure testable unit
  `lib/services/ssh/tmux_command_resolver.dart` (`TmuxCommandResolver.resolve`).
- [x] **T003** Reproduction test `test/services/ssh/tmux_command_resolver_test.dart` (RED on
  `| tmux` / `&& tmux` / `(tmux` / real load-buffer command).
- [x] **T004** Fix: regex `(^|;\s*)tmux\b` → `(^|[|&;(]\s*)tmux\b` (GREEN). Wire into `SshClient._resolveTmuxCommand`.
- [x] **T005** Surface failure to the user: `_sendMultilineText` shows a SnackBar (was a silent
  `AppLog.d` + TODO).
- [x] **T006** Verify: analyze exit 0; `flutter test` 357 pass (+9); end-to-end paste confirmed on the host.
- [ ] **T007** Commit, push, PR; CI green. (Then release vX.Y.Z to test on the phone.)

## Traceability
| FR/SC | Tasks |
|-------|-------|
| FR-001,002,004 / SC-001,002 | T002,T003,T004 |
| FR-003 / SC-003 | T005 |
| SC-004 | T006 |
