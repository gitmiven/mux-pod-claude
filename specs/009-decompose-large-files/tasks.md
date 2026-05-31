# Tasks — Decompose the Next Large Files

## Slice 1 — connections_screen.dart (pure-move extraction)
- [x] **T001** Verify embedded classes self-contained (`_searchVisibleProvider` used only by main).
- [x] **T002** Extract `_ConnectionCard`, `_SearchField`, `_SortOptionTile`, `_NewSessionDialog` →
  `lib/screens/connections/widgets/` (public; `super.key`); ConnectionCard imports NewSessionDialog.
- [x] **T003** Rewrite main: remove classes, add imports, rename call sites, trim unused imports.
  1,180 → 494 lines. analyze exit 0 (30); test 335 pass.

## Slice 2 — ansi_text_view.dart
- [x] **T004** Extract `_EagerScaleGestureRecognizer` (+ `_TwoFingerMode`) to its own file.
- [x] **T005** Split `AnsiTextViewState` into part-file Logic/View mixins (one-directional).

## Slice 3 — special_keys_bar.dart
- [x] **T006** Split `_SpecialKeysBarState` into part-file mixins.

## Gate
- [x] **T007** analyze exit 0; test 335 pass; commit per slice; PR; CI green.
