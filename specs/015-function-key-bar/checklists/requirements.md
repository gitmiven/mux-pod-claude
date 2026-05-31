# Spec quality checklist — 015 variable key bar (F1–F10)

- [x] User-facing value is clear (P1: send F-keys to TUI programs from the phone).
- [x] Requirements are testable (FR-001..007 each map to an observable behaviour).
- [x] Success criteria are measurable (SC-001 key delivery, SC-002 layout, SC-003 variability, SC-004 gate).
- [x] Implementation-light: states *what* (a data-driven bar + F-key set), not *how* the widget tree is built.
- [x] Ambiguities resolved via documented Assumptions (sent as tmux key names; always-visible; F1–F10; modifier composition).
- [x] Scope bounds the work: no other button sets, no toggle/persistence, no F11/F12, existing bars untouched.
- [x] Reuses existing transport (`onSpecialKeyPressed` → tmux `send-keys`) — no new SSH/tmux surface, no new error path.
- [x] Future-proofing captured (US2 / SC-003: a later config plugs in without re-wiring the terminal screen).
