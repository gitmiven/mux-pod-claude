# Spec quality checklist — 024 button-bar re-layout + bar history

- [x] User value clear (P1: faster recent-command access on the bar; familiar up-over-down arrow cross).
- [x] Bar numbering grounded top-to-bottom: 1=F-keys, 2=modifier(9→10), 3=arrows.
- [x] Requirements testable (FR-001/002 history button+picker+send, FR-003 Up on bar 2, FR-004 L/D/R on bar 3, FR-005 up-over-down, FR-006 reserved slot).
- [x] Measurable SCs (SC-001 button counts, SC-002 x-alignment of Up/Down, SC-003 history send, SC-004 arrow keys+modifiers).
- [x] Reuses 023 history (shared picker + commandHistoryProvider) — no behaviour drift.
- [x] Edge cases: narrow screens, Direct-Input mode (1–4 keys), reserved slot alignment, disconnected.
- [x] Scope bounds: bar 1 untouched; reserved slot's future content out of scope; no Direct-Input redesign.
- [x] Layout pinned by the user: Up at bar 2 **col 2**, Down at bar 3 **col 2** (exactly below); both bars share a 10-col grid so arrows align (bar 3 arrows become grid cells, not fixed-width); col 4 reserved.
