# Feature Specification: Pre-fill the command popup from the terminal input line (configurable)

**Feature Branch**: `022-prefill-command` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: the "Enter Command" popup always starts empty, regardless of what Claude Code's input
box already contains. Make it (configurable in options) pre-fill with the contents of that input box —
it makes usage much more intuitive.

## Context

The "Enter Command" popup (`InputDialogContent`, opened from the special-keys "Input…" button) opens
with `initialValue: _savedCommandInput` — the app's own previously-typed-but-unsent text, which starts
empty. It has **no awareness of what is currently typed in the terminal** (e.g. Claude Code's input box,
or a half-typed shell command at the prompt).

The terminal screen already has the data to know that: `AnsiTextView` is fed `viewData.content` (the
captured pane text, incl. history) and the cursor position `cursor.x` / `cursor.y`
(`terminal_screen.dart:276`). The current input the user sees lives on the **cursor's row** of the
captured pane (the visible area is the last `paneHeight` lines; the cursor's absolute line is
`lines.length - paneHeight + cursor.y`).

This feature adds a **configurable option** so that, when enabled, opening the popup pre-fills it with
the current terminal input-line text — letting the user continue editing in the comfortable popup
editor instead of typing into the terminal directly. Default **off** (current behaviour preserved).

## User Scenarios & Testing

### User Story 1 — Continue editing what's already typed (Priority: P1)

A user has typed a partial prompt into Claude Code's input box (or a half-finished shell command).
Editing it on the phone keyboard directly in the terminal is awkward, so they open the "Enter Command"
popup — and it opens **pre-filled with that text**, ready to edit and send.

**Acceptance scenarios**:
1. **Given** the option is **on** and the terminal input line reads `git comm` (at the prompt/box),
   **when** the user opens the popup, **then** it opens containing `git comm` (the prompt/box
   decoration removed — see Decisions), cursor at end.
2. **Given** the option is **off**, **when** the user opens the popup, **then** it opens empty / with
   `_savedCommandInput` exactly as today.
3. **Given** the option is **on** but the input line is empty, **when** the user opens the popup,
   **then** it opens empty.

### User Story 2 — Configure it (Priority: P1)

A toggle in Settings turns the pre-fill on/off; the choice persists across restarts; default off.

### Edge cases

- **No active line / not connected**: opening the popup falls back to empty (no crash).
- **Multi-line input box** (Claude Code can wrap): v1 captures the current line (see Decisions /
  out-of-scope for full multi-line reconstruction).
- **Wide/!ASCII content**: extraction operates on the captured plain text of the row.
- **Send duplication**: because the text is *already* in the terminal's input box, sending the popup's
  text as-is would duplicate it — the send behaviour must avoid that (see Decisions D2).

## Requirements

- **FR-001**: A **Settings toggle** MUST control whether the command popup pre-fills from the terminal
  input line. Default **off**; persisted across restarts.
- **FR-002**: When **on**, opening the popup MUST pre-fill it with the current terminal input-line text,
  extracted from the captured pane at the cursor row.
- **FR-003**: The extraction MUST strip a leading prompt / input-box decoration (shell `$ `/`# `/`> `;
  Claude's `│`/`┃` box + optional `> ` and trailing border) so the pre-filled text is the user's actual
  input, not the prompt; if none is recognised it falls back to the trimmed raw line (Decision D1).
- **FR-004**: When **off**, behaviour MUST be exactly as today (`_savedCommandInput`).
- **FR-005**: The pre-filled text MUST be fully editable; if extraction yields nothing/unknown, the
  popup opens empty rather than failing.
- **FR-006**: When the popup was pre-filled from the terminal, **Send MUST first clear the terminal
  input line** (send `C-u`, plus `C-a C-k` as a fallback) before sending the edited text, so the
  command is never duplicated (Decision D2). The non-pre-filled send path is unchanged.
- **FR-007**: The extraction logic MUST be a pure, unit-testable function (captured line + cursor →
  pre-fill text).

## Key Entities

- **Setting** — `AppSettings.prefillCommandFromTerminal` (bool, default false), persisted.
- **Input-line extractor** — pure function: `(cursorLineText, …) → prefillText`.

## Success Criteria

- **SC-001**: With the option on and a known input line, the popup opens pre-filled with the extracted
  text; with it off, empty/`_savedCommandInput` — verifiable by a unit test over the extractor + a
  widget/wiring test.
- **SC-002**: The setting round-trips through `shared_preferences` (persists across reload); default off.
- **SC-003**: Sending from the pre-filled popup does not duplicate the text in the terminal.
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests.

## Decisions (confirmed)

- **D1 — what to pre-fill → strip the prompt.** Take the cursor line and heuristically strip a leading
  prompt / input-box decoration: a leading shell prompt ending in `$ `, `# `, or `> `, and Claude
  Code's input-box decoration (a leading box-drawing char `│`/`┃` then optional `> `), plus the box's
  trailing border. If no decoration is recognised, fall back to the trimmed raw line.
- **D2 — send behaviour → clear the box, then send.** Because the pre-fill came from the terminal's
  input line, sending MUST first **clear that line** in the pane (send `C-u`; for editors that ignore
  it, also `C-a C-k`) and then send the edited text — so the box ends up with exactly the edited text,
  never duplicated. This clear-then-send applies **only when the popup was pre-filled** from the
  terminal (the normal send path is unchanged otherwise).

## Assumptions

- The current input is on the **cursor's row** of the captured pane; v1 reads that single line.
- Extraction is **best-effort** and heuristic (prompt/box decoration varies); when unsure it prefers
  the raw line or empty over a wrong guess.
- Default **off** keeps current behaviour for users who don't opt in.
- English, hardcoded UI strings (no i18n framework).

## Scope

**In scope**: the Settings toggle + persistence; a pure input-line extractor; wiring the popup's
`initialValue` to use it when enabled; the send-without-duplication behaviour (per D2); unit tests for
the extractor + setting round-trip.

**Out of scope**: full multi-line input-box reconstruction; two-way live sync between the popup and the
terminal box; app-specific parsing beyond the common Claude-Code box + shell prompt; changing the send
pipeline itself.
