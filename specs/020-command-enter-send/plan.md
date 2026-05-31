# Plan — 020 command Enter-to-send (soft keyboard)

## Root cause
`InputDialogContent`'s Enter-to-send is wired only through a hardware focus key handler
(`_handleKeyEvent`), and the `TextField` uses `keyboardType: multiline` + `textInputAction.newline`
with no `onSubmitted`. Soft keyboards don't emit the hardware `KeyEvent`, and the newline action just
inserts a newline → never sends.

## Fix
TextField: `keyboardType: TextInputType.text`, `textInputAction: TextInputAction.send`,
`onSubmitted: (_) => _handleSend()`. Keep `maxLines: null` (grows for pasted multi-line) and the
hardware `_handleKeyEvent` (Shift+Enter newline, Enter send, composing guard). `_handleSend`'s
in-flight guard prevents any double-send.

## Files
- Modified: input_dialog_content.dart.
- Tests: input_dialog_test.dart (+2: send IME action exposed; IME send action → onSend once).

## Verification
analyze exit 0; flutter test 395. The new test simulates the soft-keyboard submit
(`testTextInput.receiveAction(send)`) — the path the old tests missed.
