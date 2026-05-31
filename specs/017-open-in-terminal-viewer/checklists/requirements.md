# Spec quality checklist — 017 open-in-terminal-viewer

- [x] User value clear (P1: render a browsed file via the user's terminal tools, e.g. timg/glow).
- [x] Two user stories, both P1: the viewer button (US1) and the configurable mapping (US2, explicitly requested).
- [x] Grounded in real code: FileAction enum, FileEntry.extension, loadBufferAndPaste/sendKeys send path, AppSettings+prefs, ShellEscape — all cited with locations.
- [x] Requirements testable (FR-001 placement/visibility, FR-002 command+navigate, FR-004 escaping, FR-005 configurable+persist, FR-006 defaults).
- [x] Success criteria measurable (SC-001 command build, SC-002 hidden when unmapped, SC-003 prefs round-trip, SC-004 escaping, SC-005 gate ≥368).
- [x] Implementation-light: states *send `<tool> <path>` to the active pane* + *config is an ext→tool map in settings*, not the exact widget/provider code.
- [x] Ambiguities resolved in Assumptions: runs in the existing pane (not a new one); tool = command prefix + appended path; unmapped → hidden button; no tool install/validation.
- [x] Edge cases listed: unmapped ext, directory, dotfile, no pane/disconnected, spaces/quotes in path, tool not installed.
- [x] Scope bounds: no in-app rendering, no new pane, no tool install, extension-based only — Rename/Delete/Open untouched.
- [x] Security: path shell-escaped (no injection) — explicit FR + SC.
