# Feature Specification: Variable key bar (initial set: function keys F1–F10)

**Feature Branch**: `015-function-key-bar` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: add a third button bar on top of the existing two at the bottom of the terminal
screen. The bar is *variable* (its contents will be repurposed later). For now it holds 10 function
keys F1–F10; tapping a button fires that function key into the terminal.

## Context

The terminal screen currently shows **two** stacked special-key rows at the bottom
(`lib/widgets/special_keys_bar.dart`, a `Column`):

- **Modifier/standard row** — `ESC, TAB, CTRL, ALT, SHIFT, RET, SRET, /, .`
- **Arrow row** (+ an optional direct-input row)

Keys are delivered to the active pane through a single callback,
`onSpecialKeyPressed(String tmuxKey)`, which the terminal wires to tmux `send-keys` (e.g. `Enter`,
`C-c`). tmux accepts `F1`–`F12` as valid key names (verified: `send-keys F1` succeeds), so function
keys can be sent through the same path with **no new transport** — only a new bar of buttons.

This feature adds a **third bar, positioned above** the existing two, that is **variable**: it renders
a configurable list of buttons rather than a hardcoded layout. The **first and only configuration that
ships now** is a function-key set, `F1`–`F10`. Other configurations (different key/command sets) will
be defined in later features; this spec only establishes the bar and its function-key set.

## User Scenarios & Testing

### User Story 1 — Send function keys to a terminal program (Priority: P1)

A user is running a TUI program in a pane (an editor, a file manager, `htop`, a BIOS-style menu) that
responds to function keys. The phone keyboard cannot easily produce F-keys, so the user needs on-screen
buttons. They tap `F1` and the running program receives the F1 key.

**Why P1**: This is the entire user-visible value of the feature; without it the bar does nothing.

**Acceptance scenarios**:
1. **Given** the user is attached to a pane running a program that reacts to function keys, **when**
   they tap `F1` on the new bar, **then** the F1 key is delivered to that program (same effect as a
   physical F1 press).
2. **Given** the bar is visible, **when** the user taps each of `F2`…`F10` in turn, **then** each
   delivers the corresponding function key to the active pane.
3. **Given** a narrow phone screen, **when** the bar renders all 10 buttons, **then** every button is
   reachable (the row fits or scrolls horizontally) and the buttons are visually consistent with the
   existing special-key buttons.

### User Story 2 — The bar is variable / reusable (Priority: P2)

The bar is built to host **different** button sets in the future (the user will define other uses).
Adding a future set should be a matter of supplying a new configuration, not rebuilding the bar or
re-wiring the terminal screen.

**Why P2**: It shapes the design so later features are cheap, but it ships no second set now.

**Acceptance scenarios**:
1. **Given** the bar takes its buttons from a configuration (a labelled list of buttons + the key each
   sends), **when** a future feature provides a different configuration, **then** the bar renders that
   set with no change to the terminal screen's wiring or to the send mechanism.

### Edge cases

- **Not connected / no active pane**: tapping a function key behaves exactly like the existing
  special-key buttons in the same state (no crash; the key is simply sent to / queued for the active
  pane per current behavior — no new error path introduced).
- **Modifiers held**: if the user has toggled `CTRL`/`ALT`/`SHIFT` on the existing bar, a function-key
  tap composes with them the same way other special keys do (see Assumptions) — e.g. `SHIFT`+`F1`
  sends `S-F1`.
- **Vertical space**: adding a third row must not hide the terminal content or the existing two bars on
  common phone heights; the bars remain a compact stack at the bottom.

## Requirements

- **FR-001**: The terminal screen MUST display a **third button bar above** the existing two
  special-key rows.
- **FR-002**: The bar MUST be **data-driven** — it renders a configurable list of buttons (each button
  has a visible label and the key/action it sends), rather than a fixed hardcoded set.
- **FR-003**: The initial (and, for this feature, only) configuration MUST present **10 buttons labelled
  `F1`–`F10`**, in order.
- **FR-004**: Tapping `Fn` MUST send the corresponding function key to the **active pane**, reusing the
  existing special-key send path (`onSpecialKeyPressed` → tmux `send-keys`). No new SSH/tmux transport
  is introduced.
- **FR-005**: The bar MUST lay out all 10 buttons usably on a typical phone width (fit, wrap, or scroll)
  and be visually consistent with the existing special-key bars (same button styling/theme).
- **FR-006**: Adding the bar MUST NOT change the behaviour, layout, or labels of the existing two bars.
- **FR-007**: The function-key buttons MUST compose with the existing `CTRL`/`ALT`/`SHIFT` modifier
  toggles the same way the other special keys do (no special-casing).

## Key Entities

- **Key bar configuration** — a named, ordered list of **bar buttons**; the bar renders whichever
  configuration it is given. Ships with one: the function-key set.
- **Bar button** — one entry: a display **label** (e.g. `F1`) and the **key it sends** (e.g. the tmux
  key name `F1`). The shape must generalise to future, non-function-key sets.

## Success Criteria

- **SC-001**: From a pane running a key-echoing program (e.g. `showkey -a`, `cat -v`, or an editor that
  binds F-keys), tapping each of `F1`–`F10` causes the program to receive the matching function key.
- **SC-002**: The third bar renders **above** the two existing bars without altering them; all 10
  buttons are reachable on a ~360 dp-wide phone screen.
- **SC-003**: The bar's button set comes from a configuration object, such that a future feature can
  supply a different set with **no edit to the terminal screen's wiring or the send path** (demonstrated
  by the code shape / a unit test over the configuration → buttons mapping).
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 357 pass (plus any new tests).

## Assumptions

- **Sent as tmux key names**: `F1`–`F10` map directly to the tmux key names `F1`–`F10` and are sent via
  the existing `onSpecialKeyPressed` path — so modifier composition (e.g. `S-F1`, `C-F1`) comes for free
  and matches how the current bar handles `RET`/arrows/etc.
- **Always visible**: the bar is a fixed third row shown whenever the special-key bars are shown (no
  show/hide toggle, no persistence, no user customisation in this feature).
- **Ten keys, F1–F10**: exactly as requested — `F11`/`F12` are out of scope for the initial set.
- **English, hardcoded labels**: consistent with the rest of the app (no i18n framework).

## Scope

**In scope**: a variable (data-driven) third key bar above the existing two; its function-key
configuration (`F1`–`F10`); wiring each button to the existing send path; layout that fits a phone;
unit/widget coverage of the configuration → buttons mapping and the send call.

**Out of scope**: defining any *other* button set or use for the bar (future features); a show/hide
toggle, persistence, or user-editable bar contents; `F11`/`F12`; changing the existing two bars; any
new SSH/tmux transport.
