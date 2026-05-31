# Spec quality checklist — 021 full-width TUI backgrounds

- [x] User value clear (P1: full-screen TUI apps like mc render their real background, become usable).
- [x] Root cause verified on a real tmux pane: capture strips trailing cells + no reset; renderer resets SGR per line and never pads to width.
- [x] Requirements testable (FR-001 carry state across lines, FR-002 fill to pane width with active bg, FR-003 default-bg unchanged, FR-004 selection/cursor/scroll safe).
- [x] Measurable SCs (SC-001 mc fills full width incl. empty rows, SC-002 no regression for shell output, SC-004 parser unit test for cross-line fill).
- [x] Edge cases: normal reset-before-newline output, ls-style colored items not bleeding, inverse/cursor, wrapped/over-width lines, unknown width.
- [x] Not an mc-specific fix: applies to all full-screen TUI apps (htop/vim/less) via the renderer.
- [x] Scope bounds: stays in the capture-pane + custom-renderer architecture; no live-PTY rewrite, no reflow changes.
