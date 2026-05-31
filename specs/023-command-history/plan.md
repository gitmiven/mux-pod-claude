# Plan — 023 command history

## Design
- `command_history.dart`: pure `addCommandToHistory(list, cmd, {cap})` (dedup, move-to-front, cap,
  ignore empty) + `commandHistoryProvider` (Notifier<List<String>> persisted as JSON in prefs).
- InputDialogContent: new `recentCommands` param; the top-right badge is replaced by a history
  IconButton that opens a modal list (most-recent first); tapping an item reuses `onSend` (so 022's
  clear-then-send + recording apply). `_handleSend` → `_sendValue(text)`; selection → `_sendValue(cmd)`.
- terminal_screen_view._showInputDialog: pass `recentCommands: ref.read(commandHistoryProvider)`; after
  a successful send, `commandHistoryProvider.notifier.add(value)`.

## Files
- New: command_history.dart; 2 test files.
- Modified: input_dialog_content.dart (button + picker + _sendValue), terminal_screen_view.dart (wire),
  terminal_screen.dart (import).

## Verification
analyze exit 0; flutter test 422 (+9: list ops, provider round-trip, button/picker/selection/empty).
