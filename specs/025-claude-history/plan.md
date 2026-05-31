# Plan — 025 Claude history source

## Design
- `claude_history.dart`: pure `parseClaudeHistory(jsonl, project, {cap})` (filter by project, sort
  most-recent first, dedupe by display, cap; skip empty/malformed) + `ClaudeHistoryReader.read(client,
  project)` (bounded `tail -n 5000 "$HOME/.claude/history.jsonl"` over SSH; null when unavailable).
- `recent_commands_sheet.dart`: now a stateful sheet with an optional async `load` (+ `fallback`);
  shows loading → loaded list, falling back to `fallback` when load yields nothing / errors.
- InputDialogContent + SpecialKeysBar gain `loadRecentCommands`; both pass it to the sheet (with
  `recentCommands` as fallback).
- terminal_screen `_loadRecentCommands()`: Claude history for `tmuxProvider.activePane.currentPath`,
  else `commandHistoryProvider` (023). Wired into the popup and the bar.

## Files
- New: claude_history.dart; 2 test files.
- Modified: recent_commands_sheet.dart, input_dialog_content.dart, special_keys_bar.dart + _view,
  terminal_screen.dart (+import, wire), terminal_screen_logic.dart (loader), terminal_screen_view.dart.

## Verification
analyze exit 0; flutter test 434 (+7: parser filter/order/dedup/cap/skip; sheet async load/fallback/no-loader).
