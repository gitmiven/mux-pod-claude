# Spec quality checklist — 016 in-session dropdown ordering

- [x] User value is clear (P1: jump to a recently-used session fast; match the startup list's "recent" feel).
- [x] Root cause captured: the dropdown has no sort, AND the in-session fetch carries no session timestamp.
- [x] Requirements testable (FR-001 sort, FR-002 capture timestamp, FR-003 deterministic fallback/ties, FR-004 ordering-only, FR-005 graceful fallback).
- [x] Success criteria measurable (SC-001 descending order, SC-002 recency moves to top, SC-003 parse with/without token, SC-004 gate ≥363).
- [x] Implementation-light: states *order by recency* + *needs a tmux timestamp*, not the exact comparator/widget code.
- [x] Key ambiguity resolved: "recent" for live tmux sessions = tmux `#{session_activity}` (not app `lastAccessedAt`, which is per-connection) — documented in Assumptions with rationale + alternative.
- [x] Edge cases listed (missing/zero timestamp → bottom; ties → stable name key; current session still highlighted; old tmux → fallback render).
- [x] Scope bounds: dropdown ordering only — startup list, selection/attach, windows/panes, settings all untouched.
