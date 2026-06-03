# Spec quality checklist — 030 auto-scroll terminal when the keyboard opens

- [x] User value clear (P1: typing under Direct Input is blind because the prompt is hidden behind the
      keyboard; scroll it into view).
- [x] Grounded in real code: lightning → `toggleDirectInput` → focused `TextField` in `SpecialKeysBar`
      pops the keyboard; `Scaffold` default `resizeToAvoidBottomInset` shrinks the body but the terminal
      scroll position isn't moved; `didChangeMetrics` already exists; `_scrollToCaret`/`scrollToBottom`
      already exist.
- [x] One focused P1 story + clear edge cases (scroll mode, rotation/fold, already-open, no pane,
      auto-resize on).
- [x] Requirements testable (FR-001 scroll on show, FR-002 rising-edge debounced, FR-003 caret→bottom,
      FR-004 independent of auto-resize, FR-005 respect scroll mode, FR-006 no scroll on hide, FR-007 no
      popup regression).
- [x] Measurable SCs (SC-001 show→scroll, SC-002 non-show→no scroll, SC-003 scroll-mode→no jump,
      SC-004 gate + manual).
- [x] Edge cases: scroll/copy mode, rotation/fold while open, keyboard already open, no active pane,
      auto-resize on.
- [x] Key decisions in Assumptions: caret over bottom; rising-edge + settle debounce; respect scroll
      mode; keep `resizeToAvoidBottomInset` default; Android phone primary.
- [x] Scope bounds: not the command popup (already insets), no layout/resize-strategy change, no
      Settings toggle, no animation redesign, no hardware-keyboard case.
- [x] Testability noted: pure `shouldScrollOnMetrics` helper as the primary seam; full widget test only
      if engine/SSH deps allow (per 029's lesson), else manual verification documented.
