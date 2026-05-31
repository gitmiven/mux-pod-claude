# Feature Specification: File browser start directory — Claude Code folder or last visited

**Feature Branch**: `018-file-browser-start-dir` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: when opening the file browser, I want it to open at the folder I was last in
("history", the path where we last were) if it exists. Make this **configurable**: open the *Claude
Code folder* (current behaviour) **or** the *history* (last visited).

## Context

When the file browser opens, `FileBrowserNotifier.initialize(paneId)`
(`lib/providers/file_browser_provider.dart`) picks the start directory:

```dart
// Get the pane's CWD
if (paneId != null) {
  final pane = _findPaneById(tmuxState, paneId);
  initialPath = pane?.currentPath;          // the "Claude Code folder"
}
...
if (initialPath != null && initialPath.isNotEmpty) {
  await loadDirectory(initialPath);
} else {
  await _loadHomeDirectory();               // fallback
}
```

So today it always opens at the **pane's current working directory** — the directory the Claude Code
session is in — falling back to home. As the user navigates, `FileBrowserState.currentPath` changes
(`loadDirectory` / `navigateToDirectory` / `navigateUp`), but that path is **never remembered** across
openings — there is no persisted "last visited" location.

This feature adds a setting to choose the start directory:

- **Claude Code folder** (default, current behaviour) — the pane's CWD.
- **Last visited** — the directory the browser was last in, if still available.

The browser already carries `connectionId` and `paneId`, so the last-visited path can be remembered
per connection.

## User Scenarios & Testing

### User Story 1 — Resume where I left off (Priority: P1)

A user who set the start mode to **Last visited** browses to `/var/www/app/src`, closes the browser,
later reopens it (same or a new session) and lands back in `/var/www/app/src` instead of the Claude
Code folder.

**Why P1**: It's the request — pick up file browsing where it was left.

**Acceptance scenarios**:
1. **Given** start mode = *Last visited* and a remembered path `/var/www/app/src` that still exists,
   **when** the browser opens, **then** it opens at `/var/www/app/src`.
2. **Given** start mode = *Last visited* but **no** path has been remembered yet (first use),
   **when** the browser opens, **then** it falls back to the Claude Code folder (then home), i.e. the
   current behaviour.
3. **Given** start mode = *Claude Code folder*, **when** the browser opens, **then** it opens at the
   pane's CWD exactly as today (the remembered path is ignored).

### User Story 2 — Choose the behaviour in Settings (Priority: P1)

In Settings the user picks the file-browser start mode (*Claude Code folder* / *Last visited*). The
choice persists across restarts; the default is *Claude Code folder* (no behaviour change for users who
don't touch it).

**Acceptance scenarios**:
1. **Given** Settings, **when** the user switches the mode, **then** it is saved and applied the next
   time the browser opens.
2. **Given** a fresh install, **then** the mode is *Claude Code folder* (current behaviour preserved).

### Edge cases

- **Remembered path no longer exists / not permitted**: loading it fails → fall back to the Claude
  Code folder (then home). The user is never stranded on an error screen at open.
- **Different server**: the remembered path is **per connection**, so opening the browser on connection
  B does not jump to a path that only exists on connection A.
- **No remembered path yet**: behaves exactly like *Claude Code folder*.
- **Empty/`/` paths**: a remembered root `/` is valid; an empty remembered value is treated as "none".

## Requirements

- **FR-001**: A setting MUST let the user choose the file-browser **start directory mode**:
  *Claude Code folder* (the pane CWD) or *Last visited* (the remembered path). Default *Claude Code
  folder* (preserves today's behaviour). Persisted across restarts.
- **FR-002**: When mode = *Last visited* and a remembered path exists for the current connection, the
  browser MUST open at that path.
- **FR-003**: The browser MUST remember the directory it was in (per connection), updated as the user
  navigates, and persist it so it survives app restarts.
- **FR-004**: If the remembered path can't be opened (missing/denied) or none exists, the browser MUST
  fall back to the Claude Code folder, then home — never leaving the user on an error at open.
- **FR-005**: The remembered path MUST be scoped **per connection** so paths from one server are not
  used for another.
- **FR-006**: When mode = *Claude Code folder*, behaviour MUST be identical to today (the remembered
  path is ignored).

## Key Entities

- **File-browser start mode** — an `AppSettings` field (e.g. `fileBrowserStartDir`:
  `claudeCodeFolder` | `lastVisited`), persisted in `shared_preferences`. Default `claudeCodeFolder`.
- **Last-visited path** — a remembered directory **per connection** (e.g. a `connectionId → path`
  map, or one key per connection), persisted; updated on navigation.

## Success Criteria

- **SC-001**: With mode = *Last visited* and a valid remembered path, opening the browser lands on that
  path (not the pane CWD) — verifiable by a unit test over the start-path selection logic.
- **SC-002**: With mode = *Last visited* and no/invalid remembered path, the browser opens at the pane
  CWD (then home) — same as the default mode.
- **SC-003**: The start mode and the per-connection last-visited path round-trip through
  `shared_preferences` (persist across a provider reload); default mode is *Claude Code folder*.
- **SC-004**: With mode = *Claude Code folder*, the open path is the pane CWD regardless of any
  remembered path.
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests
  for the start-path selection and the settings/last-path round-trip.

## Assumptions

- **"History" = the single last-visited directory**, not a full back/forward stack (the browser has
  `navigateUp` but no history stack today). Remembering one path matches the user's phrasing ("path
  where we last were").
- **Persisted per connection**, keyed by `connectionId` (the browser already has it), so multi-server
  use doesn't cross paths.
- **Updated on each successful navigation** (so it's always current and survives a crash), rather than
  only on close.
- **Validity is checked by attempting to load it**; a failure triggers the fallback chain — no separate
  existence probe.
- **Default preserves current behaviour** (*Claude Code folder*), so existing users see no change
  unless they opt in.
- **English, hardcoded UI strings** (no i18n framework).

## Scope

**In scope**: the start-mode setting + its Settings UI; remembering the last-visited path per
connection and persisting it; using it (with graceful fallback) in `initialize`; unit/widget tests for
the selection logic and the round-trips.

**Out of scope**: a multi-step history/back-forward stack; bookmarks/favourites; remembering scroll
position, sort, or hidden-file toggles; per-pane (vs per-connection) memory; syncing the remembered
path to the terminal's CWD.
