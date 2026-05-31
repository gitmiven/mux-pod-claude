# Spec quality checklist — 025 Claude history source

- [x] User value clear (P1: history button shows real recent Claude prompts for this project).
- [x] Grounded in the verified file: `~/.claude/history.jsonl` = {display, timestamp, project=cwd}, time-ordered.
- [x] Solves the buffering problem: Claude records final submitted prompts (incl. Direct-Input) accurately.
- [x] Requirements testable (FR-001 read+scope+order+dedup, FR-002 fallback, FR-005 bounded read, FR-006 pure parser).
- [x] Measurable SCs (SC-001 parser, SC-002 Claude source + send, SC-003 fallback, SC-004 failure-safe).
- [x] Fallback to app history (023) explicit; 023 recording kept so fallback stays populated.
- [x] Edge cases: loading, large file (bounded), not connected, paste placeholders, cwd≠project, malformed lines.
- [x] Scope bounds: no source toggle, no merge, no edit, no caching, no paste reproduction, no shell-history.
- [x] Privacy noted: reads the user's own prompt-history file over their own SSH connection, surfaced in-app.
