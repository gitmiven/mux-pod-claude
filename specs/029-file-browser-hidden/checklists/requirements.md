# Spec quality checklist — 029 file browser: show hidden files by default

- [x] User value clear (P1: reach `~/.claude/commands` & `skills` without re-tapping the eye each open).
- [x] Grounded in real code: filter machinery already exists (`isHidden`, `filterHidden`, `showHidden`,
      `toggleShowHidden`, AppBar eye); the gap is `initialize()` resetting `showHidden` to false each open.
- [x] Two P1 stories: hidden-visible-by-default (US1) + the Settings switch (US2).
- [x] Requirements testable (FR-001 setting+default+persist, FR-002 on→showHidden true, FR-003 off→false,
      FR-004 eye still overrides per-session & doesn't mutate setting, FR-005 lives in File browser section,
      FR-006 keeps dot-prefixed definition).
- [x] Measurable SCs (SC-001 on→shown, SC-002 off→hidden, SC-003 round-trip+default off, SC-004 eye
      override works, SC-005 gate ≥448 +tests).
- [x] Default preserves current behaviour (off) — no surprise for existing users.
- [x] Edge cases: per-session override vs default, navigating into a hidden dir, no-hidden-entries,
      POSIX has no "system" attribute (hidden = dot-prefixed).
- [x] Key decisions in Assumptions: seeds initial state only (toggle doesn't write back); global (not
      per-connection/pane); "hidden" unchanged.
- [x] Scope bounds: not option 2 (persist toggle) or option 3 (default-on); no per-connection memory;
      no new filtering semantics.
- [x] Decision memo `afa3478f` resolved → **Option 1** (Settings default, like 018) drives this spec.
