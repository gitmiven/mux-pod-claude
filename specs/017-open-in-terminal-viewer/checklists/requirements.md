# Spec quality checklist — 017 open-in-app-viewer (revised)

- [x] User value clear (P1: preview a browsed file in the app — image/markdown/text).
- [x] Captures the user's correction: in-app rendering, NOT terminal tools (timg/glow) in a pane.
- [x] Two P1 stories: the viewer item (US1) + the per-extension configurable mapping (US2).
- [x] Grounded: FileAction enum, FileEntry.extension, SFTP open/readBytes, AppSettings+prefs, flutter_markdown_plus.
- [x] Requirements testable (FR-001 placement/visibility, FR-002 in-app render via SFTP, FR-004 configurable+persist, FR-005 defaults, FR-007 size cap, FR-008 loading/error).
- [x] Measurable SCs (SC-001 menu+open, SC-002 hidden when unmapped, SC-003 prefs round-trip, SC-004 size cap, SC-005 gate ≥368).
- [x] Edge cases: unmapped, directory, dotfile, too-large/binary, read failure, image decode failure.
- [x] Scope bounds: no terminal/tmux, no editing, no PDF/video, extension-based only.
