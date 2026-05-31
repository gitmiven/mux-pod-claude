# Feature Specification: Full-screen TUI background colors (fill line backgrounds to pane width)

**Feature Branch**: `021-full-width-bg` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: a Midnight Commander (`mc`) screen that is **solid blue** in other terminals renders
mostly **black** here — the blue only shows behind the text, which makes it hard to use.

## Context

The terminal display polls `tmux capture-pane -p -e -S -1000` and renders the result with a **custom**
ANSI renderer (`AnsiTextView` + `lib/services/terminal/ansi_parser.dart`) — the app does not use a live
terminal emulator. Full-screen TUI apps (mc, htop, vim) paint a **solid background** by setting a
background color and erasing/filling the screen with it. Two things in the pipeline drop that fill:

1. **The renderer resets ANSI state per line.** `ansi_parser` parses each captured line starting from
   the default style, so a background that was set on one line and is still active on the next is lost.
2. **The renderer never pads a line to the pane width.** Each line is a `Text.rich` that draws
   background only behind the glyphs present; the columns after the last glyph (and entirely empty
   rows) get the app's default (black) background.

### What the capture actually contains (verified on a tmux pane painted fully blue)

Painting a pane blue (`ESC[44m` + clear) then writing two short lines, `capture-pane -p -e` returns:

```
^[[44mline one        # blue SGR set, text; trailing blue cells STRIPPED, and NO reset emitted
line two              # NO SGR re-emitted — the blue is carried over in the stream
                      # empty rows below: completely bare — no SGR at all
```

Key implications:
- The background active at a line's (stripped) **end is still "blue"** — recoverable if we pad to width
  with the **active** background.
- The blue on **subsequent lines** is only knowable if ANSI state is **carried across line breaks**
  (capture does not re-emit it) — which is exactly how a real terminal behaves.
- **Empty rows** carry no SGR; their color is only recoverable by **carrying the active background
  across lines** down to them.

So fixing **both** — (a) carry ANSI/background state across lines, and (b) fill each line's background
to the pane width using the active background — makes a fully-painted screen render fully colored,
including the empty rows.

## User Scenarios & Testing

### User Story 1 — A full-screen TUI app shows its real background (Priority: P1)

A user opens `mc` (or htop/vim) over the connection. Its solid background (mc's blue) fills the screen —
each row across its full width, and the empty area below content — so the UI looks and reads the way it
does in any other terminal, instead of blue-fragments-on-black.

**Why P1**: It's the reported defect — full-screen apps are hard to use because their background isn't
rendered.

**Acceptance scenarios**:
1. **Given** an `mc` screen whose background is solid blue, **when** it renders in the app, **then**
   each row's background is blue across the **full pane width** (not only behind the text).
2. **Given** the same screen has rows below the file content that mc painted blue, **when** it renders,
   **then** those rows are blue too (the active background carries down), not black.
3. **Given** a background color is set and remains active across several lines (no reset emitted between
   them), **when** they render, **then** all those lines show the background.

### Edge cases

- **Normal shell output** (default background, programs reset SGR before the newline): rows stay the
  default background — **no regression**, no accidental full-width recolor.
- **A line ending in a colored segment that the app *did* reset** (e.g. `ls` colors): the reset returns
  the active background to default before the line end, so padding uses the default — the colored item
  does **not** bleed to the row edge.
- **Inverse / selection / cursor cell**: still render correctly; the full-width fill must not hide the
  cursor or break selection highlighting.
- **Lines longer than the pane width / wrapped lines**: padding only applies up to the pane width and
  must not corrupt wrapped-line handling.
- **Unknown pane width**: if the column count isn't known yet, fall back to today's behaviour rather
  than mis-padding.

## Requirements

- **FR-001**: The renderer MUST carry ANSI style state (especially background color) **across line
  breaks** within a capture, instead of resetting per line — matching real terminal behaviour and the
  fact that `capture-pane` does not re-emit unchanged SGR per line.
- **FR-002**: Each rendered line MUST fill its background to the **full pane width**, using the
  background color **active at the end of that line** (so padding beyond the last glyph, and fully empty
  rows, show the active background).
- **FR-003**: Lines whose active background is the **default** MUST render unchanged (the default
  background is transparent/black as today) — no regression for ordinary shell output.
- **FR-004**: The fill MUST NOT break text selection/copy, cursor rendering, horizontal/vertical
  scrolling, wrapped-line handling, or the per-line `itemExtent` performance model.
- **FR-005**: The pane width used for padding MUST come from the display's known column count; if it is
  unknown, the renderer falls back to current behaviour.

## Key Entities

- **Parsed line** (existing, extended) — in addition to its styled segments, each line carries the
  **background color in effect at its end** (its "fill" / trailing background), derived from ANSI state
  carried across lines.

## Success Criteria

- **SC-001**: An `mc` (or equivalently blue-painted) screen renders with its background filling each
  row's full width and the empty rows below content — predominantly blue, readable, usable — not
  blue-behind-text-on-black.
- **SC-002**: Ordinary shell output (prompts, `ls`, logs) is visually unchanged (no full-width recolor,
  no color bleed to the row edge).
- **SC-003**: Selection, copy, cursor, and scrolling behave as before.
- **SC-004**: A unit test proves the parser carries background across lines and reports the correct
  per-line fill background (incl. an empty row inheriting a prior line's background, and a reset line
  reverting to default).
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests.

## Assumptions

- **Carrying SGR state across lines is correct terminal behaviour** (a background set with no reset
  persists across newlines), so it both fixes mc and matches real terminals; well-behaved shell
  programs reset before the newline, so they are unaffected.
- **Per-line fill background** is implemented as a background behind each line up to the pane width
  (e.g. a line-level background color), not by emitting per-cell padding glyphs — cheaper and selection-
  safe.
- **Pane width** is the column count the display already tracks for the active pane.
- The fix stays within the **capture-pane + custom renderer** architecture; switching to a live
  PTY-stream terminal emulator is out of scope.

## Scope

**In scope**: carry ANSI/background state across lines in `ansi_parser`; expose a per-line fill
background; render each line's background to the full pane width in `AnsiTextView`; unit tests for the
cross-line state + fill background; a manual check against an `mc` screen.

**Out of scope**: replacing the renderer with a live terminal emulator; reflowing/wrapping changes;
truecolor/256-color accuracy beyond what already works; capturing trailing cells differently from tmux
(the fix is client-side); non-background SGR fidelity.
