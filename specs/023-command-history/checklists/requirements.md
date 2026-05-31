# Spec quality checklist — 023 command history

- [x] User value clear (P1: re-run a recent command without retyping).
- [x] Grounded: popup badge → button; send path `onSend`/`_sendMultilineText` (+022 clear-then-send).
- [x] Requirements testable (FR-001 dedup+recency, FR-002 persist+cap, FR-004 button→picker→send, FR-006 pure helper).
- [x] Measurable SCs (SC-001 list ops, SC-002 prefs round-trip, SC-003 button+selection, SC-004 gate).
- [x] Edge cases: duplicates move-to-front, empty not recorded, cap, persistence, multi-line, 022 interaction.
- [x] Reuses the popup's send path so 022 behaviour + recording stay uniform.
- [x] Scope bounds: no edit/remove/search/pin, no per-connection history, no command palette.
