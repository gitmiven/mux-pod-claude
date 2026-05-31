# Spec quality checklist — 026 more file viewers

- [x] Scope confirmed by user: CSV/ZIP in-app; html/mp4/webm/xls/doc external "Open with".
- [x] Honest feasibility: xls/doc can't render in-app (legacy binary) → external; documented.
- [x] Requirements testable (FR-001 types+defaults, FR-002 csv table, FR-003 zip list, FR-004 download+open, FR-006 pure helpers).
- [x] Measurable SCs (SC-001 type map, SC-002 csv parse, SC-003 zip entries, SC-004 external routing, SC-005 gate + release-build).
- [x] Edge cases: large files (stream + cap), CSV quirks, corrupt/encrypted zip, no-app-to-open, temp files.
- [x] Reuses 017's map + menu flow; existing viewers untouched.
- [x] Risk flagged: open_filex Android FileProvider config + the APK release build (CI only runs analyze/test).
- [x] Scope bounds: no in-app video/html/office, no zip extraction, no caching/editing.
