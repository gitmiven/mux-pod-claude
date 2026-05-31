# Plan — 024 button-bar re-layout + bar history

## Design
- Shared picker: extract the popup's recent-commands sheet → `lib/widgets/recent_commands_sheet.dart`
  (`showRecentCommandsSheet`). InputDialogContent now calls it.
- SpecialKeysBar: new `recentCommands` + `onSendCommand` params.
- Bar 2 (`_buildModifierKeysRow`): insert `_buildArrowKeyCell(Up)` at column 2 (10 cells).
- Bar 3 (`_buildArrowKeysRow`): grid Row — Left/Down/Right as `_buildArrowKeyCell` (cols 1–3), an
  Expanded SizedBox (col 4 reserved), then `Expanded(flex:6)` holding image/⚡/number-keys-or-Input and
  a `_buildHistoryButton`. Same 10-col grid + horizontal padding (4) as bar 2 → Down (col 2) is exactly
  under Up (col 2). Removed the unused fixed-width `_buildArrowButton`.
- terminal_screen: pass `recentCommands: ref.watch(commandHistoryProvider)` and an `onSendCommand` that
  sends + records.

## Files
- New: recent_commands_sheet.dart; special_keys_bar_layout_test.dart.
- Modified: special_keys_bar.dart (+params, import), special_keys_bar_view.dart (rows + cells + history,
  -arrow button), input_dialog_content.dart (use shared sheet), terminal_screen.dart (wire).

## Verification
analyze exit 0; flutter test 427 (+5: Up/Left/Down/Right placement, Up-over-Down x-alignment, arrow keys,
history opens+sends, empty state). Existing arrow/key tests still pass.
