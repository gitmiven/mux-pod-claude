# Spec quality checklist — 018 file-browser start directory

- [x] User value clear (P1: reopen the file browser where you left off).
- [x] Grounded in `initialize()`: today it always uses the pane CWD; there is no persisted last path.
- [x] Two P1 stories: resume-at-last-visited (US1) + the Settings toggle (US2).
- [x] Requirements testable (FR-001 setting+default, FR-002 open-at-last, FR-003 remember+persist, FR-004 fallback chain, FR-005 per-connection, FR-006 default unchanged).
- [x] Measurable SCs (SC-001 lands on last path, SC-002 fallback, SC-003 round-trip+default, SC-004 default mode = CWD, SC-005 gate).
- [x] Default preserves current behaviour (Claude Code folder) — no surprise for existing users.
- [x] Edge cases: remembered path gone/denied, different server, none-yet, empty vs `/`.
- [x] Key decisions in Assumptions: single last path (not a stack); per-connection; updated on navigation; validity via load-attempt.
- [x] Scope bounds: no back/forward stack, no bookmarks, no scroll/sort memory, per-connection (not per-pane).
