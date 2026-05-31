# Feature Specification: Recent commands from Claude Code's history (app-history fallback)

**Feature Branch**: `025-claude-history` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: instead of buffering keystrokes, query Claude Code for the recent commands — read its
prompt history — and fall back to the app-recorded history when that isn't available.

## Context

Features 023/024 give a recent-commands history, but it is **app-recorded** — only commands sent through
the "Enter Command" popup (or re-run from the picker) are captured. Commands typed live in Direct-Input
mode (which must stream keystroke-by-keystroke so Claude Code's `/`-autocomplete works) are never
recorded.

Claude Code **records every submitted prompt itself**, on the server, at `~/.claude/history.jsonl` —
verified on this machine. One JSON object per line:

```
{ "display": "<the submitted prompt text>", "timestamp": <epoch ms>,
  "project": "<the working directory, e.g. /home/me/dev/app>", "sessionId": "…", "pastedContents": {…} }
```

Key facts (confirmed): `project` is the **working directory** — the same path the app already tracks as
the active pane's CWD (the "Claude Code folder"); entries are time-ordered; prompts include slash
commands. So we can read this file over the **existing SSH connection**, scope it to the current pane's
project, and surface the user's **actual recent Claude Code prompts** — accurately, including
Direct-Input-typed ones (Claude stores the final submitted text, after autocomplete/edits). When the
file is absent/empty (e.g. a plain shell pane), we fall back to the app-recorded history (023).

## User Scenarios & Testing

### User Story 1 — See my recent Claude Code prompts (Priority: P1)

A user taps the history button (popup or bar ⏱). It shows their **recent prompts for this project**,
read from Claude Code's history, most-recent first, deduplicated. Tapping one re-issues it (sends it to
the pane, i.e. into Claude's input).

**Acceptance scenarios**:
1. **Given** `~/.claude/history.jsonl` has entries whose `project` is the active pane's directory,
   **when** the history opens, **then** those prompts are listed most-recent first, deduplicated by text.
2. **Given** a prompt is listed, **when** tapped, **then** it is sent to the pane (same send path as the
   app history) and the sheet closes.
3. **Given** entries for *other* projects exist, **then** they are **not** shown (scoped to this pane).

### User Story 2 — Fallback to app history (Priority: P1)

When Claude Code's history can't be used, the history button still works off the app-recorded list.

**Acceptance scenarios**:
1. **Given** `~/.claude/history.jsonl` is **missing** (plain shell pane) or unreadable, **when** the
   history opens, **then** it shows the **app-recorded** history (023) instead.
2. **Given** the file exists but has **no entries for this project**, **then** it falls back to the
   app-recorded history.
3. **Given** neither source has anything, **then** the empty-state ("No recent commands yet") is shown.

### Edge cases

- **Loading**: reading over SSH is async; the picker shows a brief loading state, then the list.
- **Large file**: the read is **bounded** (recent slice) so a huge history can't stall the UI.
- **Not connected**: falls back to app history (no crash).
- **Pasted-content prompts**: Claude's `display` may contain a paste placeholder; such an entry is shown
  as-is and, if selected, sends the placeholder text (it won't reproduce the original paste) — acceptable
  for v1.
- **CWD ≠ project**: if the pane changed directory away from where Claude was launched, the project match
  may miss; v1 matches on the pane's current directory (documented assumption).
- **Malformed lines**: skipped, not fatal.

## Requirements

- **FR-001**: When the history picker opens, the app MUST read Claude Code's `~/.claude/history.jsonl`
  over the existing SSH connection (bounded to a recent slice), parse it, keep entries whose `project`
  matches the **active pane's directory**, sort **most-recent first**, **dedupe by prompt text**, and
  show the top N.
- **FR-002**: If that source is unavailable — file missing/unreadable, not connected, or **no entries
  for this project** — the picker MUST fall back to the **app-recorded history** (023).
- **FR-003**: Selecting an entry MUST send it to the active pane via the existing send path (and the
  picker closes) — identical behaviour to the app-history picker.
- **FR-004**: The picker MUST show **loading**, **empty**, and (on read failure) **fallback** states —
  never a crash or indefinite spinner.
- **FR-005**: The Claude-history read MUST be **bounded** (size/line cap) so a large file can't hang or
  OOM the app.
- **FR-006**: Parsing/filtering/dedup/cap MUST be a **pure, unit-testable** function (JSONL + project →
  ordered unique prompts).
- **FR-007**: App-side recording (023) MUST continue, so the fallback stays populated; no existing
  behaviour regresses.

## Key Entities

- **Claude history entry** — `{ display, timestamp, project }` parsed from `history.jsonl`.
- **Resolved recent commands** — the ordered, unique prompt list shown in the picker: Claude history for
  the pane's project, else the app-recorded history.

## Success Criteria

- **SC-001**: Given a JSONL sample with mixed projects/timestamps/duplicates, the pure parser returns
  this-project prompts, most-recent first, deduped, capped — verifiable by a unit test.
- **SC-002**: With Claude history present for the project, the picker shows those prompts; selecting one
  sends it — verifiable by a test over the resolution + a widget test over the picker.
- **SC-003**: With the file absent/empty-for-project, the picker shows the app-recorded history.
- **SC-004**: A read failure / disconnected state falls back gracefully (app history or empty), no crash.
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests.

## Assumptions

- **`project` == the pane's current directory** (Claude's project = its launch CWD; the pane's CWD
  reflects it while Claude is foreground). v1 matches on that path.
- **Read on open** (on-demand over SSH) with a loading state; no caching in v1.
- **Prefer Claude history, fall back to app history** — automatic, no new setting (a source toggle is
  out of scope).
- **Send = paste the prompt text** into the pane (re-issue to Claude); paste-placeholder entries are
  imperfect.
- English, hardcoded UI strings (no i18n framework).

## Scope

**In scope**: read+parse `~/.claude/history.jsonl` (bounded) over SSH; pure parse/filter/dedup/cap;
scope by pane project; resolve Claude-or-app source with fallback; loading/empty/fallback states in the
shared picker; keep 023 recording; unit tests (parser + resolution) and a widget/loading test.

**Out of scope**: a source-selection setting; merging Claude + app histories; editing/removing entries;
faithfully reproducing pasted content; caching; cross-project history; non-Claude shell history files.
