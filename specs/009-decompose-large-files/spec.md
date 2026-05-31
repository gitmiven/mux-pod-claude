# Feature Specification: Decompose the Next Large Files

**Feature Branch**: `009-decompose-large-files`
**Created**: 2026-05-31
**Status**: Draft
**Input**: User: "decompose next large files" (analysis recommendation #7).

## Context

After 007 cut `terminal_screen.dart` from 4,527 → 389 lines, the next-largest files remain hard to
navigate/test (analysis #7): `ansi_text_view.dart` (1,399), `connections_screen.dart` (1,180),
`special_keys_bar.dart` (1,064). This feature decomposes them using the two safe, behavior-identical
patterns proven in 007: **pure-move extraction** of self-contained classes, and **`part`-file mixin
splits** of god state-classes (Logic/View). No behavior change.

## User Scenarios & Testing

### User Story 1 - Smaller, navigable widgets (Priority: P1)

A contributor can find and read these widgets without scrolling 1,000+-line files; behavior is
unchanged.

**Acceptance Scenarios**:
1. **Given** the refactor, **When** the app runs, **Then** connection list, terminal text view, and
   the special-keys bar behave identically to before.
2. **Given** `flutter analyze`/`flutter test`, **Then** results match the baseline (no new
   errors/warnings/failures).

## Requirements

### Functional Requirements
- **FR-001**: `connections_screen.dart` — extract its self-contained embedded classes
  (`_ConnectionCard`, `_SearchField`, `_SortOptionTile`, `_NewSessionDialog`, `_SearchVisibleNotifier`)
  into their own files under `lib/screens/connections/widgets/`. Pure moves; make public only where
  referenced across files.
- **FR-002**: `ansi_text_view.dart` — extract `_EagerScaleGestureRecognizer` (+ `_TwoFingerMode`)
  into its own file; split `AnsiTextViewState` into `part`-file mixins (logic vs view) if it reduces
  the file materially with one-directional dependency.
- **FR-003**: `special_keys_bar.dart` — split `_SpecialKeysBarState` into `part`-file mixins.
- **FR-004**: No logic/string/behavior change — relocation + minimal visibility changes only;
  preserve each file's line endings.
- **FR-005**: `flutter analyze --no-fatal-infos` exit 0 (no new errors/warnings); `flutter test`
  unchanged (335 pass / 0 fail).

## Success Criteria
- **SC-001**: Each of the three files is materially smaller (target: each "host" file well under its
  original size; extracted modules are self-contained).
- **SC-002**: analyze exit 0; test 335 pass / 0 fail (behavior-identical).
- **SC-003**: No top-level private symbol is referenced across the new file boundaries except via the
  intended public/mixin surface (verified by the analyzer compiling).

## Scope
In scope: the three named files; new files under existing `widgets/` dirs; `part`-file mixins.
Out of scope: behavior/UI changes; new tests beyond what extraction enables; other large files.

## Implementation note
Done incrementally (one file per commit, each verified green): connections_screen (pure moves) →
ansi_text_view → special_keys_bar (mixin splits). Same techniques as 007.
