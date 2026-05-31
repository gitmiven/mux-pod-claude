# Spec quality checklist — 020 command Enter-to-send

- [x] User value clear (P1: press Enter on the phone keyboard to send the command).
- [x] Root cause captured: hardware-only key handler + `textInputAction.newline` → soft Enter inserts newline, never sends; existing tests only simulate hardware Enter so they miss it.
- [x] Requirements testable (FR-001 soft-Enter sends, FR-002 send IME action, FR-003 hardware unchanged, FR-004 composing guard, FR-005 no double-send).
- [x] Measurable SCs (SC-001 IME action → onSend once, SC-002 action exposed, SC-003 existing tests still pass, SC-004 gate).
- [x] The regression test simulates the *soft-keyboard* submit (not hardware) — the path the current tests don't cover.
- [x] Trade-off documented: soft-keyboard Enter sends (multi-line via paste / hardware Shift+Enter).
- [x] Scope bounds: only the command panel's submit behaviour; send pipeline, DirectInput, special-keys bar untouched.
