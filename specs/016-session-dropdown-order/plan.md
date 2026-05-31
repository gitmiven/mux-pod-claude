# Plan — 016 order in-session dropdown by recency

## Design
End-to-end carry of a per-session recency timestamp, then sort the dropdown:
1. `TmuxCommands.listAllPanes()` — append `#{session_activity}` (epoch secs) as the last format token
   (appended last → older payloads without it still parse).
2. `TmuxParser.parseFullTree` — read `parts[19]` via the existing `_parseTimestamp`; set
   `TmuxSession.lastActivity` when the session row is first created.
3. `TmuxSession` — new `lastActivity` field (+ copyWith) and a pure `byRecencyDesc` comparator
   (newest first; null/unknown → bottom; ties → name).
4. `_showSessionSelector` — sort a **copy** of `tmuxState.sessions` with `byRecencyDesc` (other
   consumers of the state order are untouched).

## Files
- Modified: `tmux_commands.dart` (format token), `tmux_parser.dart` (field, copyWith, comparator, parse),
  `terminal_screen_view.dart` (sort the dropdown copy).
- New: `test/services/tmux/tmux_session_recency_test.dart` (5 tests).

## Verification
analyze exit 0; flutter test 368 (+5). Parse populates/omits lastActivity; comparator orders newest
first with null-last + name tie-break.
