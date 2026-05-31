# Feature Specification: Enter sends in the command-input panel (soft keyboard)

**Feature Branch**: `020-command-enter-send` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: in the "Enter Command" panel, pressing Enter to send doesn't work — I still have to
tap the on-screen button to send.

## Context

The command-input panel (`InputDialogContent`, opened from the special-keys bar's "Input…" button)
lets the user type a command and send it to the active pane (`onSend` → `_sendMultilineText`). It is
meant to send on **Enter** and insert a newline on **Shift+Enter**.

Enter-to-send is implemented only via a **hardware** key handler:

```dart
_focusNode.onKeyEvent = _handleKeyEvent; // KeyDownEvent + LogicalKeyboardKey.enter → send
...
keyboardType: TextInputType.multiline,
textInputAction: TextInputAction.newline, // <-- soft keyboard Enter = newline
// (no onSubmitted)
```

On a phone **software keyboard**, pressing Enter does **not** emit a hardware `KeyEvent`, so
`_handleKeyEvent` never runs. And because the field is multiline with
`textInputAction: TextInputAction.newline`, the soft-keyboard Enter just **inserts a newline** — it
never sends. So the user must tap the on-screen send button. (The existing tests only simulate
*hardware* Enter via `sendKeyEvent`, so they pass while the soft-keyboard path is broken.)

The fix is to make the soft keyboard's action **send**: use a send IME action and handle
`onSubmitted`, so pressing Enter on the on-screen keyboard sends the command.

## User Scenarios & Testing

### User Story 1 — Press Enter to send (Priority: P1)

A user types a command in the panel on their phone and presses the on-screen keyboard's **Enter/Send**
key; the command is sent to the terminal and the panel closes — no need to tap the send button.

**Why P1**: It's the reported defect — the panel's headline interaction (Enter to send) doesn't work
on the device keyboard.

**Acceptance scenarios**:
1. **Given** a typed command and the on-screen keyboard, **when** the user presses its Enter/Send
   action, **then** the command is sent (`onSend`) and the panel closes.
2. **Given** a hardware keyboard, **when** the user presses Enter, **then** it still sends (unchanged).
3. **Given** a hardware keyboard, **when** the user presses Shift+Enter, **then** a newline is inserted
   and nothing is sent (unchanged).
4. **Given** an IME composition is in progress, **when** Enter commits the composition, **then** it does
   **not** send (the keystroke finalises the text, consistent with today's guard).

### Edge cases

- **Multi-line commands**: still supported via **paste** (and hardware Shift+Enter). On the soft
  keyboard, Enter now sends rather than inserting a newline — the accepted trade-off for "Enter sends".
- **Empty input**: sending empty input behaves as today (the send handler/`_sendMultilineText` already
  no-ops on empty).
- **Double-send**: a hardware Enter (key handler) and any IME action must not send twice — the in-flight
  guard prevents duplicates.

## Requirements

- **FR-001**: In the command-input panel, pressing **Enter on the software keyboard** MUST send the
  command (same effect as tapping the send button) and not merely insert a newline.
- **FR-002**: The field MUST advertise a **send** IME action so the on-screen keyboard shows a send/go
  key and emits a submit event that the panel handles.
- **FR-003**: Hardware **Enter → send** and hardware **Shift+Enter → newline** MUST keep working.
- **FR-004**: Enter that **commits an IME composition** MUST NOT send (preserve the existing
  composing-range guard).
- **FR-005**: Sending MUST remain idempotent for a single press (no double-send from the hardware
  handler plus the IME submit).
- **FR-006**: The change MUST be limited to the command-input panel's submit behaviour; the send
  pipeline (`_sendMultilineText`), other inputs, and the special-keys bar are unchanged.

## Success Criteria

- **SC-001**: Simulating the soft-keyboard submit action on the panel triggers `onSend` exactly once —
  verifiable by a widget test using the IME action (the current behaviour does **not**).
- **SC-002**: The field exposes the send IME action (asserted in a widget test).
- **SC-003**: The existing hardware-Enter (send), Shift+Enter (newline), and composing-guard tests
  still pass.
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + the new test.

## Assumptions

- **Enter-sends over soft-keyboard newline**: on the device keyboard, Enter sends; typing a literal
  newline there is dropped in favour of send (multi-line via paste / hardware Shift+Enter). This is the
  user's explicit intent.
- **Send IME action**: `TextInputAction.send` with a non-multiline `keyboardType` so the action key
  submits; the field still grows (`maxLines: null`) to display pasted multi-line input.
- **English, hardcoded UI strings** (no i18n framework).

## Scope

**In scope**: the command-input panel's IME action + `onSubmitted` wiring so soft-keyboard Enter sends;
a widget test simulating the soft-keyboard action; keep the hardware Enter / Shift+Enter / composing
behaviour.

**Out of scope**: the send pipeline itself; the DirectInput field; the special-keys RET button; any
redesign of multi-line entry.
