# Feature Specification: Auto-scroll the terminal to the input line when the keyboard opens

**Feature Branch**: `030-keyboard-scroll-on-show` | **Created**: 2026-06-02 | **Status**: Draft
**Input**: User: when viewing the terminal and I tap the lightning (Direct Input) button, the keyboard
pops up but the terminal stays fixed — when I start typing I can't see what I type. It would be great
if the terminal scrolls down after the keyboard appears, so I immediately see what I'm typing.

## Context

Tapping the **lightning / bolt button** toggles **Direct Input** (`onDirectInputToggle` →
`SettingsNotifier.toggleDirectInput`, wired in `terminal_screen.dart`). When Direct Input turns on,
`SpecialKeysBar` reveals a focused `TextField` (`_directInputController` / `_directInputFocusNode`,
`lib/widgets/special_keys_bar*.dart`) and requests focus, which brings up the **soft keyboard**.
Keystrokes are sent to the pane (tmux `send-keys`) and the pane **echoes** them at its prompt / input
box.

The terminal screen's `Scaffold` (`terminal_screen.dart:241`) does **not** set
`resizeToAvoidBottomInset`, so it defaults to `true`: when the keyboard opens, the body — a `Column` of
`[breadcrumb, Expanded(terminal output), bottom key bars]` — **shrinks** to fit above the keyboard. But
the terminal's vertical scroll position is **not moved**, so the bottom of the output — the live
prompt / cursor line where typed characters echo — is left below the now-shorter viewport, hidden
behind the keyboard. The user types blind.

The seam to fix this already exists:

- `TerminalScreenState` is a `WidgetsBindingObserver` and already overrides **`didChangeMetrics()`**
  (`terminal_screen.dart:165`), which fires when the keyboard shows/hides (the bottom view inset
  changes). Today it only triggers auto-resize, and only when `settings.isAutoResize` is true.
- The terminal already knows how to scroll to the active line: `_scrollToCaret()`
  (`terminal_screen_logic.dart:996` → `_ansiTextViewKey.currentState?.scrollToCaret()`) centres the
  cursor line; `AnsiTextViewState.scrollToBottom()` jumps to the end. `scrollToCaret` clamps to the
  viewport, so it behaves correctly after the viewport shrinks.

So the fix is: when the keyboard **appears**, scroll the terminal to the caret (falling back to bottom)
so the input line sits just above the keyboard — independent of the auto-resize setting.

This is **not** about the "Enter Command" popup, which already insets itself for the keyboard
(`input_dialog_content.dart:142`, `MediaQuery…viewInsets.bottom`). It is specifically the main terminal
view under Direct Input.

## User Scenarios & Testing

### User Story 1 — See what I type as soon as the keyboard opens (Priority: P1)

A user viewing a pane taps the lightning button. The keyboard slides up; the terminal immediately
scrolls so the active prompt / cursor line is visible just above the keyboard. As they type, the echoed
characters are on screen.

**Why P1**: It's the request — typing blind makes Direct Input frustrating to use on a phone.

**Acceptance scenarios**:
1. **Given** the terminal is scrolled to the live prompt and Direct Input is off, **when** the user taps
   the lightning button and the keyboard appears, **then** the terminal scrolls so the cursor / prompt
   line is visible above the keyboard (not hidden behind it).
2. **Given** the keyboard is open and the user is typing, **when** the pane echoes the characters,
   **then** the echoed input line remains visible (the existing on-output auto-scroll keeps it in view).
3. **Given** the keyboard closes (Direct Input off / dismissed), **then** the terminal is not yanked —
   the viewport grows back and the content stays where it is.

### Edge cases

- **Scroll/copy mode**: if the user has scrolled up to read history (terminal in scroll mode), opening
  the keyboard MUST NOT yank them to the bottom — the auto-scroll applies only in the normal
  interactive (follow-the-cursor) state. *(See Assumptions — this matches the existing on-output
  auto-scroll behaviour.)*
- **Rotation / fold while the keyboard is open**: `didChangeMetrics` fires for those too; the scroll
  MUST trigger on the keyboard **show transition** (inset rising from ~0 to a meaningful height), not on
  every metrics tick, so it doesn't fight rotation/auto-resize or repeatedly jump.
- **Keyboard already open** when the metrics change for another reason: no repeated scroll (only the
  rising-edge triggers it).
- **No active pane / not connected**: the scroll request is a no-op (the existing scroll helpers guard
  on `hasClients` / parsed lines).
- **Auto-resize on**: the scroll MUST still happen — it is independent of the `isAutoResize` gate that
  currently guards `didChangeMetrics`.

## Requirements

- **FR-001**: When the soft keyboard appears while the terminal is in the foreground, the terminal MUST
  scroll so the active cursor / input line is visible above the keyboard.
- **FR-002**: The scroll MUST be triggered by the keyboard **show transition** (bottom view inset rising
  from ≈0 to a meaningful height) detected in `didChangeMetrics`, debounced/settled so it fires once per
  appearance and does not fight rotation, folding, or auto-resize.
- **FR-003**: The scroll MUST use the existing caret scroll (`_scrollToCaret()` →
  `AnsiTextViewState.scrollToCaret()`), falling back to `scrollToBottom()` if no caret target is
  available, so it reveals exactly where typed characters land.
- **FR-004**: The behaviour MUST be independent of the display **adjust mode** — it applies whether or
  not `isAutoResize` is enabled.
- **FR-005**: The behaviour MUST NOT disturb **scroll/copy mode** — when the user has scrolled up to
  read history, opening the keyboard MUST NOT force a jump to the cursor.
- **FR-006**: Keyboard **hide** MUST NOT force a scroll (the viewport restores; content stays put).
- **FR-007**: No regression to the "Enter Command" popup, which already handles its own keyboard inset.

## Key Entities

- **`didChangeMetrics()`** (`terminal_screen.dart`) — the lifecycle hook that observes the keyboard
  inset change; gains keyboard-show detection that triggers the scroll.
- **Keyboard-visible state** — derived from `MediaQuery…viewInsets.bottom` (or
  `View…viewInsets`), compared frame-to-frame to detect the rising edge. May be held as a small field
  (e.g. `_keyboardWasVisible`) on the screen state.
- **Caret/bottom scroll** — existing `_scrollToCaret()` / `AnsiTextViewState.scrollToBottom()`,
  reused unchanged.

## Success Criteria

- **SC-001**: With the terminal following the cursor, simulating a keyboard appearance (bottom inset
  0 → >0 via `didChangeMetrics`) results in a caret/bottom scroll request — verifiable by a widget test
  that pumps a view-inset change and asserts the scroll helper is invoked (or the scroll offset moves to
  the end).
- **SC-002**: A metrics change that is **not** a keyboard-show (inset stays 0, or inset falling) does
  NOT trigger the scroll — verifiable by test.
- **SC-003**: In scroll/copy mode, a keyboard appearance does NOT trigger the cursor jump — verifiable
  by test.
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + the new
  keyboard-show tests. Manual: on a device, tapping the lightning button reveals the prompt line above
  the keyboard and typed characters are visible immediately.

## Assumptions

- **Scroll to caret, not just bottom**: the request is "see what I type"; the caret is exactly where
  typing lands. `scrollToCaret` already clamps to the (shrunk) viewport, so the input line ends up
  visible above the keyboard. Bottom is the fallback when there's no caret target.
- **Rising-edge trigger with a short settle delay**: the keyboard animates in (~100–300 ms) and the
  inset arrives over several frames; a small debounce (similar to the existing 500 ms auto-resize
  debounce, or a post-frame after the inset stabilises) ensures one scroll after the viewport settles.
- **Respect scroll mode**: consistent with the app's existing rule that auto-scroll-to-cursor is
  suppressed while the user is reading history; the keyboard-show scroll follows the same guard.
- **`resizeToAvoidBottomInset` stays at its default (true)**: the body already shrinks to sit above the
  keyboard; this feature only fixes the *scroll position*, not the resize strategy.
- **Android phone is the primary target** (the app's focus); behaviour on tablets/foldables follows the
  same inset logic.
- **English, hardcoded UI strings** (no i18n framework). No new user-facing strings expected.

## Scope

**In scope**: detecting the keyboard-show transition in `didChangeMetrics` and scrolling the terminal to
the caret (fallback bottom), independent of auto-resize and suppressed in scroll mode; widget tests for
the show-transition, the non-trigger cases, and the scroll-mode guard.

**Out of scope**: changing the `resizeToAvoidBottomInset` strategy or the layout; the "Enter Command"
popup (already insets itself); a Settings toggle for this behaviour (it's a straightforward UX fix, on
by default); redesigning the scroll animations; hardware-keyboard cases (no soft keyboard inset).
