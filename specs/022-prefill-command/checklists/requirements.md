# Spec quality checklist — 022 pre-fill command popup

- [x] User value clear (P1: continue editing the terminal input in the comfortable popup editor).
- [x] Grounded: popup `initialValue`/`_savedCommandInput`; data source `viewData.content` + cursor.x/y.
- [x] Configurable + default off (no change for users who don't opt in).
- [x] Requirements testable (FR-002 pre-fill from cursor row, FR-003 strip decoration, FR-006 no duplicate send, FR-007 pure extractor).
- [x] Measurable SCs (SC-001 prefill on/off, SC-002 setting round-trip, SC-003 no duplication, SC-004 gate).
- [x] Two product decisions confirmed: D1 = strip the prompt (fallback raw line); D2 = clear the box (C-u / C-a C-k) then send.
- [x] Edge cases: empty line, not connected, multi-line box (v1 single line), send duplication.
- [x] Scope bounds: single-line v1, no live two-way sync, no deep app-specific parsing.
