# Feature Specification: Order the in-session session dropdown by most-recent

**Feature Branch**: `016-session-dropdown-order` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: the startup session list is ordered "recent sessions"; the in-session dropdown
(switch session from the top of the terminal) is ordered differently (alphabetical / creation).
Make the dropdown use "recent sessions" ordering too.

## Context

Two places list sessions, with different orderings:

1. **Startup "Recent Sessions"** (`sessionHistoryProvider`,
   `lib/providers/session_history_provider.dart`) sorts the app's saved **connections** by
   `lastAccessedAt ?? connectedAt` **descending** — most recently used first.
2. **In-session dropdown** (`_showSessionSelector` in
   `lib/screens/terminal/terminal_screen_view.dart`) renders `tmuxState.sessions` in **whatever
   order the parser produced** — effectively tmux's natural order (`list-panes -a`, map-iteration),
   which reads as alphabetical-by-name / creation order. There is **no sort**.

These two lists are different kinds of thing: the startup list is the app's **connection** history
(one row per saved server connection); the dropdown lists the **live tmux sessions on the one server
you're attached to**. So the dropdown cannot reuse `lastAccessedAt` — that field belongs to
connections, not to individual tmux sessions.

The right "recent" signal for live tmux sessions is one tmux already tracks per session:

- `#{session_activity}` — last activity time in the session (output/input), or
- `#{session_last_attached}` — last time the session was attached.

**Neither is currently fetched.** `TmuxCommands.listAllPanes()` (the in-session source) requests
`session_name`/`session_id` but **no timestamp**, and the `TmuxSession` model
(`lib/services/tmux/tmux_parser.dart`) has only `created` — no activity/last-attached field. So
delivering "recent" ordering for the dropdown requires carrying a session timestamp end-to-end
(format string → parser → model → sort), then sorting the dropdown by it.

## User Scenarios & Testing

### User Story 1 — Switch to a recently-used session quickly (Priority: P1)

A user attached to one session opens the top dropdown to jump to another session they were recently
working in. The most-recently-active sessions appear at the **top** of the list (matching the startup
list's "recent first" feel), so the session they want is near the top instead of buried alphabetically.

**Why P1**: It's the whole request — make the dropdown's order match the user's mental model of
"recent" so switching is fast.

**Acceptance scenarios**:
1. **Given** several tmux sessions with different last-activity times, **when** the user opens the
   in-session dropdown, **then** the sessions are ordered **most-recent first** (descending by the
   session's last-activity timestamp).
2. **Given** the user works in session B (making it the most recently active), then switches to
   session A and reopens the dropdown, **then** B is now near the top (its recency moved it up).
3. **Given** the dropdown is open, **when** comparing against the startup list's intent, **then** both
   read as "recent first" rather than one alphabetical and one by recency.

### Edge cases

- **Missing/zero timestamp**: if tmux returns no/zero activity time for a session, it sorts to the
  bottom (treated as oldest) rather than crashing or jumping to the top — consistent with the startup
  list's `?? fallback`.
- **Ties**: sessions with equal timestamps fall back to a stable secondary key (e.g. name) so the
  order is deterministic, not random map order.
- **The currently-attached session**: it still appears in the list and remains highlighted as active
  (`TmuxSessionTile.isActive` behaviour is unchanged); recency ordering simply places it by its
  timestamp.
- **Older tmux / unsupported format**: if the activity format yields nothing, the dropdown must still
  render (fall back to the existing order) — never an empty or broken list.

## Requirements

- **FR-001**: The in-session session dropdown MUST order sessions **most-recently-active first**
  (descending by the session's last-activity timestamp), matching the "recent first" intent of the
  startup list.
- **FR-002**: The in-session fetch MUST capture a per-session recency timestamp from tmux
  (`#{session_activity}` or `#{session_last_attached}`) so the ordering has data to sort on; the
  `TmuxSession` model MUST carry this value.
- **FR-003**: Sessions with a missing/zero timestamp MUST sort to the bottom (treated as least
  recent), and ties MUST break on a stable secondary key (name) — no nondeterministic ordering.
- **FR-004**: The change MUST be limited to **ordering**: the dropdown's contents, the active-session
  highlight, selection behaviour, and the startup list are all unchanged.
- **FR-005**: If the recency timestamp is unavailable (older/edge tmux), the dropdown MUST still render
  (graceful fallback to the prior order) — never crash or show an empty list.

## Key Entities

- **TmuxSession** (existing) — gains a recency timestamp field (e.g. `lastActivity`/`lastAttached`)
  parsed from the new tmux format token, alongside the existing `created`.

## Success Criteria

- **SC-001**: With sessions whose last-activity times are known, the dropdown lists them in strictly
  descending recency order (newest activity at top) — verifiable in a unit test over the sort.
- **SC-002**: A session that becomes the most recently active moves to (near) the top on the next
  dropdown open.
- **SC-003**: Parsing a `list-panes -a` payload that includes the new timestamp token yields
  `TmuxSession`s with the timestamp populated; a payload lacking it still parses (timestamp null) and
  the dropdown still renders.
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 363 pass (plus new tests for
  the parse + sort).

## Assumptions

- **"Recent" = last activity**: the ordering key is tmux's `#{session_activity}` (most recently active
  session first). `#{session_last_attached}` is an acceptable alternative with the same UX; the
  implementation picks one and documents it. (Rationale: it is the per-session analogue of the startup
  list's `lastAccessedAt`, and the session the user just left will have the freshest activity.)
- **Server-side data**: the timestamp comes from tmux, not from app-side history — the dropdown lists
  live server sessions, which have no `ActiveSession.lastAccessedAt`.
- **No persistence/UI added**: no new setting, sort toggle, or column — ordering only.

## Scope

**In scope**: add a session recency timestamp to the in-session tmux format
(`listAllPanes`), parse it into `TmuxSession`, sort the dropdown (`_showSessionSelector`) most-recent
first with deterministic tie-breaking; unit tests for the parse + sort.

**Out of scope**: changing the startup/dashboard list; a user-configurable sort order or toggle;
reordering windows/panes; persisting per-session recency on the app side; any change to selection or
attach behaviour.
