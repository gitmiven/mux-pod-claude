# Plan — 027 shell history source

## Design
- `shell_history.dart`: pure `parseBashHistory` (lines, skip blanks/#, newest-first dedupe) and
  `parseZshHistory` (`: ts:dur;cmd` or plain, newest-first dedupe); `ShellHistoryReader.read(client,
  {shellHint})` does a bounded `tail` of `$HOME/.zsh_history`/`.bash_history` over SSH, picking the
  shell from the pane's foreground command, returns null when unavailable.
- terminal_screen `_loadRecentCommands`: inserts the shell tier — Claude → **shell** → app.

## Files
- New: shell_history.dart; shell_history_test.dart.
- Modified: terminal_screen_logic.dart (chain), terminal_screen.dart (import).

## Verification
analyze exit 0; flutter test 448 (+6 bash/zsh parser cases). Pure Dart, no new deps / native.
