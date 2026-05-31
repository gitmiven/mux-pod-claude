# Feature Specification: Button-bar re-layout — split arrows + a bar history button

**Feature Branch**: `024-arrow-layout-history` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: (1) shift the bottom-bar buttons left and add a last button with the same function as
the "Enter Command" popup's history button. (2) Add an extra button to the 2nd bar **at position 2** —
the **Up** arrow — making it 10 buttons; the 3rd bar holds **Left / Down / Right** with **Down in
column 2**, so the **Up arrow sits exactly above the Down arrow**. The slot freed in the 3rd bar is
left empty for now (future use).

### Target layout

```
Bar 2 (10 equal cols):  ESC  [↑]  TAB  CTRL  ALT  SHIFT  RET  S-RET  /  -
Bar 3 (same col grid):  [←]  [↓]  [→]  (·)  [img] [⚡] [  Input…  ] [⏱ history]
                               ↑ Up (bar2 col2) is exactly above Down (bar3 col2)
```
`(·)` = the reserved empty slot freed by moving Up out of the arrow cluster.

## Context

The terminal's special-keys area (`lib/widgets/special_keys_bar.dart`) stacks three bars, top to bottom:

1. **Bar 1 — variable F-keys** (`_buildVariableKeyBar`, feature 015): 10 buttons F1–F10.
2. **Bar 2 — modifier row** (`_buildModifierKeysRow`): **9** equal-width buttons —
   `ESC TAB CTRL ALT SHIFT RET S-RET / -`.
3. **Bar 3 — arrow row** (`_buildArrowKeysRow`): the arrow cluster `← ↑ ↓ →` (fixed-width buttons),
   then the image-transfer button, the Direct-Input (⚡) toggle, and the **"Input…" (Enter Command)**
   button. In Direct-Input mode this row instead shows number keys `1 2 3 4` and the live field.

Feature 023 added a recent-commands **history** (`commandHistoryProvider` + a picker in the popup that
sends a chosen command). This feature surfaces that history directly on the bar and rearranges the
arrows into the familiar up-over-down cross.

## User Scenarios & Testing

### User Story 1 — Pick a recent command without opening the popup (Priority: P1)

A user taps a **history button on the bottom bar** (next to "Input…"), sees their unique recent
commands (most-recent first), taps one, and it is sent to the terminal — no need to open the Enter
Command popup first.

**Acceptance scenarios**:
1. **Given** recent commands exist, **when** the user taps the bar's history button, **then** the same
   recent-commands picker (unique, most-recent first) appears; tapping one **sends** it and records it
   (moves it to the top).
2. **Given** no commands yet, **when** tapped, **then** an empty-state is shown (no crash).
3. **Given** the new button is added, **then** the existing bottom-bar buttons shift left to make room;
   all remain usable.

### User Story 2 — Up arrow above the down arrow (Priority: P1)

The arrow keys form the familiar cross: **Up** on bar 2, **Left / Down / Right** on bar 3, with Up
directly above Down.

**Acceptance scenarios**:
1. **Given** the bars render, **then** bar 2 has **10** buttons — the modifier row with an **Up** arrow
   inserted at **position 2** (`ESC, ↑, TAB, CTRL, ALT, SHIFT, RET, S-RET, /, -`).
2. **Given** the bars render, **then** bar 3's arrow cluster is **Left (col 1), Down (col 2), Right
   (col 3)** (no Up), on the same equal-column grid as bar 2.
3. **Given** both bars render, **then** the **Up** button (bar 2, col 2) is **exactly above the Down**
   button (bar 3, col 2), and the slot at column 4 (vacated by Up) is left **empty** (reserved).
4. **Given** any arrow is tapped, **then** it sends the same key as before (`Up`/`Down`/`Left`/`Right`,
   composing with CTRL/ALT/SHIFT as today).

### Edge cases

- **Narrow screens**: bar 2's 10 buttons fit like bar 1's F-keys; bar 3's arrows + buttons + history
  button stay reachable.
- **Direct-Input mode**: bar 3 still swaps in the number keys `1–4` / live field; the arrow re-layout
  and history button must remain coherent (not overlap or break) in that mode.
- **Reserved empty slot**: leaving it blank must not misalign Down from Up or shift other buttons.
- **History button while disconnected**: behaves like the popup's send when not connected (no crash).

## Requirements

- **FR-001**: A **history button** MUST be added to the bottom bar (bar 3), next to the "Input…" button,
  with the existing buttons shifted left to fit it.
- **FR-002**: Tapping the bar's history button MUST open the **same** recent-commands picker as the
  popup (unique, most-recent first, from `commandHistoryProvider`); selecting a command MUST send it to
  the active pane and record it (keeping the history fresh).
- **FR-003**: Bar 2 (modifier row) MUST gain an **Up** arrow button inserted at **position 2** (between
  ESC and TAB), making 10 buttons, keeping the existing 9 and their behaviour.
- **FR-004**: Bar 3's arrow cluster MUST become **Left, Down, Right** (Up removed), laid out on the same
  equal-column grid as bar 2 so they align under bar 2's columns; each MUST send the same key as today
  and compose with modifiers.
- **FR-005**: **Down** MUST be in **column 2** so it is **exactly below the Up** button (bar 2 col 2);
  Left in column 1, Right in column 3 (a cross with Up over Down).
- **FR-006**: The **column-4** slot (vacated by Up) MUST be left **empty/reserved** (a placeholder),
  without misaligning Down or other buttons.
- **FR-007**: All other behaviour — bar 1 (F-keys), the modifier/special keys, Direct-Input mode, image
  transfer, and the Input/Enter-Command button — MUST be unchanged.

## Key Entities

- **Special-keys bar layout** — the three rows; bar 2 grows to 10, bar 3's arrows split to L/D/R + a
  reserved slot, plus a history button by "Input…".

## Success Criteria

- **SC-001**: Bar 2 renders 10 buttons ending in an Up arrow; bar 3 renders Left/Down/Right with Up
  absent — verifiable by a widget test over the bar.
- **SC-002**: Up is rendered horizontally aligned above Down (cross layout) — verifiable by comparing
  their rendered x-positions in a widget test.
- **SC-003**: The bar's history button opens the recent-commands list and tapping one invokes the
  command-send callback with that command — verifiable by a widget test.
- **SC-004**: Tapping each arrow still emits its key (`Up/Down/Left/Right`); modifier composition
  (e.g. CTRL+Up → `C-Up`) is unchanged.
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests.

## Assumptions

- The bar's history button reuses 023's `commandHistoryProvider` and a **shared picker** (extracted
  from the popup) so behaviour stays identical.
- Selecting from the bar history **sends directly** (no 022 pre-fill context); it records the command.
- The reserved empty slot in bar 3 is a sized placeholder (no action) until a later feature uses it.
- Up-above-Down alignment is achieved by laying **both bars on the same 10-column equal-width grid**:
  Up at bar 2 col 2, Down at bar 3 col 2 (Left col 1, Right col 3, reserved col 4). Bar 3's arrows
  therefore become grid-aligned cells (they are fixed-width today) so they line up under bar 2.
- English, hardcoded UI strings (no i18n framework).

## Scope

**In scope**: add the bar history button (+ shared picker + send/record wiring); move Up to bar 2 (10
buttons); make bar 3 arrows Left/Down/Right with a reserved slot; align Up over Down; widget tests for
layout + history.

**Out of scope**: deciding what fills the reserved slot; changing bar 1 (F-keys); redesigning
Direct-Input mode or the number keys; editing/searching history; per-connection history.
