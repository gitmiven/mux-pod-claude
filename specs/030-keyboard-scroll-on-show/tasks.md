# Tasks — auto-scroll terminal when the keyboard opens

- [x] **T001** Pure helper `shouldScrollOnMetrics({prevInset, newInset, isScrollMode})` — rising-edge
      over a threshold && not scroll mode (place near the terminal logic or a small util).
- [x] **T002** `didChangeMetrics`: read bottom view inset, track `_keyboardWasVisible`, and on the
      hidden→visible edge schedule a settled one-shot scroll — *before* the `isAutoResize` early-return.
- [x] **T003** On the keyboard-show edge, call `_scrollToCaret()` (fallback
      `_ansiTextViewKey.currentState?.scrollToBottom()`); skip when `_terminalMode == TerminalMode.scroll`.
- [x] **T004** [TDD] Tests: `shouldScrollOnMetrics` (show→true, no-change→false, hide→false,
      scroll-mode→false); widget-level inset-change → scroll-to-end if feasible, else document why
      (engine/SSH deps) and rely on the pure helper + manual check.
- [x] **T005** Gate: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ current + new.
- [ ] **T006** Manual device check: lightning → prompt visible above keyboard, typed chars visible;
      rotation with keyboard up = no extra jump; scroll-mode not yanked.
- [ ] **T007** Commit, push, PR; CI green.
