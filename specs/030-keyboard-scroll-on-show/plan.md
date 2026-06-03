# Plan — 030 auto-scroll terminal when the keyboard opens

## Design

The scroll machinery and the lifecycle hook already exist; this wires them together for the
keyboard-show case.

- **Detect the keyboard-show edge** in `TerminalScreenState.didChangeMetrics()`
  (`terminal_screen.dart`). Read the bottom view inset
  (`WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom / devicePixelRatio`, or
  `MediaQueryData.fromView(...).viewInsets.bottom`). Track the previous visibility in a field
  `bool _keyboardWasVisible`. When it transitions **hidden → visible** (inset crosses a small
  threshold, e.g. > 80 px logical), schedule a one-shot scroll.
- **Scroll to the input line**: after a short settle (a `Timer`/post-frame so the inset and the resized
  viewport have stabilised — reuse the debounce style already used for auto-resize), call the existing
  `_scrollToCaret()` (which delegates to `_ansiTextViewKey.currentState?.scrollToCaret()`); if there's
  no caret target, fall back to `_ansiTextViewKey.currentState?.scrollToBottom()`.
- **Independent of auto-resize**: the keyboard-show scroll runs regardless of `settings.isAutoResize`
  (today the method early-returns when auto-resize is off — the new branch sits *before* that gate).
- **Respect scroll mode**: skip the scroll when `_terminalMode == TerminalMode.scroll` (the user is
  reading history), matching the existing on-output auto-scroll suppression.
- **Hide edge**: when the inset falls to ~0, just update `_keyboardWasVisible = false`; no scroll.

No change to the `Scaffold`, the layout, `resizeToAvoidBottomInset`, the popup, or the scroll helpers
themselves.

## Files

- **Modified**: `lib/screens/terminal/terminal_screen.dart` (keyboard-show detection in
  `didChangeMetrics`); possibly `terminal_screen_logic.dart` if a small helper
  (`_onKeyboardShown()` / `_keyboardWasVisible` field) reads cleaner there (mixin holds the other
  scroll helpers and timers).
- **New**: 1 widget/unit test file.

## Testing approach

`didChangeMetrics` reads the platform view inset, which is awkward to drive directly. Prefer the
**smallest testable seam**: extract the decision into a pure helper, e.g.
`bool shouldScrollOnMetrics({required double prevInset, required double newInset, required bool isScrollMode})`
(rising-edge over threshold && !scrollMode), and unit-test that exhaustively (show → true; no-change →
false; hide → false; scroll-mode → false). Then a thin widget test (if practical) pumps a
`MediaQuery` view-inset change and asserts the terminal scroll offset moves to the end / the caret
helper is called. If the full-screen widget test proves too heavy (SSH/engine deps, as seen in 029),
rely on the pure-helper tests + manual device verification, and document it.

## Verification

`flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ current + new tests (rising-edge helper:
show/no-op/hide/scroll-mode). Manual on device: tap the lightning button → prompt line appears above
the keyboard, typed characters visible immediately; rotating with the keyboard up doesn't cause extra
jumps; scrolling up to read history then opening the keyboard doesn't yank to the bottom.

## Out of scope

`resizeToAvoidBottomInset`/layout changes; the command popup; a Settings toggle; animation redesign.
