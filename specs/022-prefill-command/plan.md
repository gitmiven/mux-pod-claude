# Plan — 022 pre-fill command popup

## Design
- `InputLineExtractor.extract(line)` (pure): strip ANSI, a trailing box border, then a leading Claude
  box (`│ > `) or shell prompt (`$ `/`# `/`> `); fall back to the trimmed raw line.
- Setting `AppSettings.prefillCommandFromTerminal` (default false) + setter + a Terminal Settings toggle.
- `_currentInputLinePrefill()` (logic): cursor row of `_viewNotifier.value.content` (idx =
  lines.len - paneHeight + cursorY) → `InputLineExtractor.extract`.
- `_showInputDialog`: when enabled & extraction non-empty, use it as `initialValue` and mark prefilled;
  on send, if prefilled, `_clearPaneInputLine()` (C-u, C-a, C-k) before `_sendMultilineText` so the
  command isn't duplicated.

## Files
- New: input_line_extractor.dart; 2 test files.
- Modified: settings_provider.dart, settings_screen.dart (toggle), terminal_screen_view.dart (popup),
  terminal_screen_logic.dart (helpers), terminal_screen.dart (import); settings_screen_test.dart
  (robust scroll helper).

## Verification
analyze exit 0; flutter test 413 (+8: extractor cases, setting round-trip).
