# Feature Specification: Recent-commands history in the command popup

**Feature Branch**: `023-command-history` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: in the "Enter Command" popup, replace the top-right "Shift+Enter: new line" info with
a **button**. Tapping it opens a window listing all **unique recently-entered commands, ordered by
recent use**; tapping one **sends** it.

## Context

The popup (`InputDialogContent`) shows a top-right badge reading "Shift+Enter: new line", and sends a
command via `onSend` → `_sendMultilineText` (and, per 022, optionally clears the terminal line first).
There is **no history** of previously-sent commands today.

This feature: (1) record each sent command in a **persisted, deduplicated, recency-ordered** history;
(2) replace the badge with a **history button**; (3) a picker listing the unique recent commands, where
tapping one sends it.

## User Scenarios & Testing

### User Story 1 — Re-run a recent command (Priority: P1)

A user opens the popup, taps the history button, sees their recent commands (most recent first), taps
one, and it is sent to the terminal — no retyping.

**Acceptance scenarios**:
1. **Given** commands were sent before, **when** the user taps the history button, **then** a list of
   the **unique** recent commands appears, **most-recently-used first**.
2. **Given** the list is open, **when** the user taps a command, **then** that command is sent (same as
   typing it and sending) and the popup closes.
3. **Given** a command is sent (typed or re-run), **when** the user reopens history, **then** that
   command is at the **top** (and not duplicated if it already existed).
4. **Given** no commands have been sent yet, **when** the user taps the button, **then** an empty-state
   ("No recent commands yet") is shown rather than a crash.

### Edge cases

- **Duplicates**: re-sending an existing command moves it to the front (no duplicate entry).
- **Empty / whitespace-only** sends are not recorded.
- **History size** is capped (oldest dropped beyond the cap).
- **Persistence**: history survives app restart.
- **Multi-line commands**: stored and shown (possibly truncated in the list for display).
- **Selecting from history respects 022**: if the popup was pre-filled from the terminal, sending a
  chosen command still clears the input line first (reuses the popup's send path), so nothing is
  duplicated.

## Requirements

- **FR-001**: Each non-empty command sent from the popup MUST be added to a **command history** that is
  **deduplicated** (exact match) and **ordered most-recently-used first** (re-send moves to front).
- **FR-002**: The history MUST be **persisted** across app restarts and **capped** to a sensible max
  (oldest dropped).
- **FR-003**: The popup's top-right MUST show a **history button** in place of the "Shift+Enter" badge.
- **FR-004**: Tapping the button MUST open a picker listing the **unique recent commands, most-recent
  first**; tapping one MUST **send** that command (via the popup's existing send path) and close the
  popup.
- **FR-005**: An empty history MUST show a clear empty-state, not an error.
- **FR-006**: The history list ops (add/dedup/move-to-front/cap, ignore empty) MUST be a pure,
  unit-testable function.
- **FR-007**: The change MUST NOT alter the send pipeline or the 022 clear-then-send behaviour.

## Key Entities

- **Command history** — an ordered list of unique command strings (most-recent first), persisted
  (JSON) via a provider; capped (e.g. 50).

## Success Criteria

- **SC-001**: Adding commands yields a deduped, most-recent-first list capped at the max — verifiable by
  a unit test over the pure add function.
- **SC-002**: The history persists through a provider reload (round-trips via `shared_preferences`).
- **SC-003**: The popup shows the history button; tapping a listed command sends it and closes the
  popup — verifiable by a widget test over the popup (button present; selection invokes `onSend`).
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests.

## Assumptions

- **Dedup is exact-string** (case-sensitive, whole command); cap **50**.
- The picker is a modal list opened over the popup; tapping reuses `onSend` so 022's clear-then-send and
  history-recording apply uniformly.
- Display may **truncate** long/multi-line commands in the list (full command still sent).
- English, hardcoded UI strings (no i18n framework).

## Scope

**In scope**: a pure history-list helper; a persisted `commandHistoryProvider`; recording sends; the
history button replacing the badge; the picker; unit tests (helper + provider round-trip) and a widget
test (button + selection).

**Out of scope**: editing/removing/pinning history entries; search/filter; per-connection history;
syncing; fuzzy dedup; a full command palette.
