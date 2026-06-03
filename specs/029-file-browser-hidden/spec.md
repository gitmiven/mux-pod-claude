# Feature Specification: File browser — show hidden files by default (Settings)

**Feature Branch**: `029-file-browser-hidden` | **Created**: 2026-06-02 | **Status**: Draft
**Input**: User: the file browser should also show hidden or system folders and files. Use case: I
need to check Claude commands and skills (which live under the hidden `~/.claude/` folder, e.g.
`~/.claude/commands` and `~/.claude/skills`).

## Context

The file browser **already** supports showing hidden (dot-prefixed) entries. The machinery exists end
to end:

- `FileEntry.isHidden` (`lib/services/sftp/file_entry.dart`) — `name.startsWith('.')`.
- `SftpBrowserService.filterHidden(entries, showHidden)` — drops hidden entries unless `showHidden`.
- `FileBrowserState.showHidden` (default `false`) + `displayEntries` applying the filter.
- `FileBrowserNotifier.toggleShowHidden()` — flips it.
- An eye **toggle in the AppBar** (`lib/screens/file_browser/file_browser_screen.dart`,
  `Icons.visibility`/`visibility_off`) wired to `toggleShowHidden()`.

So a user *can* reveal `.claude/` and other dotfiles today — by tapping the eye every time. The gap is
**persistence**: `FileBrowserNotifier.initialize()` resets `state = const FileBrowserState()` on every
open, so `showHidden` always reverts to `false`. For the user's recurring task — inspecting
`~/.claude/commands` and `~/.claude/skills`, both inside a hidden folder — that means re-tapping the
eye on every single browser open.

This feature adds a **Settings option** to make "show hidden files" the default, mirroring the existing
`fileBrowserStartDir` ("Open at") pattern from 018 and the `prefillCommandFromTerminal` bool setting
from 022:

- **Show hidden files by default** (default **off**, preserving today's behaviour) — when on, the
  browser opens with hidden entries already visible.
- The existing eye toggle still works as a **per-session override** either way.

## User Scenarios & Testing

### User Story 1 — Hidden files visible without re-tapping (Priority: P1)

A user who works with Claude config sets **Show hidden files by default = on**. From then on, every time
the file browser opens, `.claude/` (and other dotfiles) are already listed, so they can drill into
`~/.claude/commands` / `~/.claude/skills` directly — no eye-tap needed.

**Why P1**: It's the request — make hidden content reachable for the "check Claude commands & skills"
workflow without repeating a manual step each open.

**Acceptance scenarios**:
1. **Given** the setting is **on**, **when** the browser opens, **then** hidden entries are shown
   immediately and the AppBar eye reflects the "showing" state.
2. **Given** the setting is **off** (default), **when** the browser opens, **then** hidden entries are
   hidden — exactly as today.
3. **Given** the setting is **on** and the browser is open, **when** the user taps the eye, **then**
   hidden entries hide for the rest of that session (the per-session override still works); reopening
   the browser shows them again (the default re-applies).

### User Story 2 — Choose the behaviour in Settings (Priority: P1)

In the **File browser** Settings section (the one that already hosts "Open at" from 018), the user
toggles **Show hidden files by default**. The choice persists across app restarts; the default is
**off** (no behaviour change for users who don't touch it).

**Acceptance scenarios**:
1. **Given** Settings, **when** the user turns the switch on, **then** it is saved and applied the next
   time the browser opens.
2. **Given** a fresh install, **then** the switch is **off** (current behaviour preserved).

### Edge cases

- **Per-session override vs default**: the eye toggle changes only the current browser session; it does
  **not** rewrite the setting. The setting decides the *initial* state on each open.
- **A hidden directory the user navigates into** (e.g. `.claude`): listing its contents is unaffected by
  the toggle — the toggle only filters dot-prefixed entries *within* the current listing. (Showing
  hidden entries is what makes `.claude` itself appear in its parent so it can be entered.)
- **No hidden entries in a directory**: turning the setting on has no visible effect there.
- **System files**: on POSIX there is no separate "system" attribute over SFTP; "hidden" = dot-prefixed.
  This is the same definition the browser already uses (`FileEntry.isHidden`).

## Requirements

- **FR-001**: A setting **Show hidden files by default** MUST let the user choose whether the file
  browser opens with hidden (dot-prefixed) entries visible. Default **off** (preserves today's
  behaviour). Persisted across restarts.
- **FR-002**: When the setting is **on**, opening the browser MUST initialise `showHidden = true` so
  hidden entries are shown without any manual action.
- **FR-003**: When the setting is **off**, opening the browser MUST initialise `showHidden = false`
  (identical to today).
- **FR-004**: The existing AppBar eye toggle MUST still flip hidden visibility for the current session
  regardless of the setting (per-session override); it MUST NOT mutate the persisted setting.
- **FR-005**: The setting MUST live in the existing **File browser** Settings section alongside "Open
  at", as a switch consistent with the app's other boolean settings.
- **FR-006**: "Hidden" MUST keep the browser's current definition — dot-prefixed names
  (`FileEntry.isHidden`) — so no new filtering semantics are introduced.

## Key Entities

- **Show-hidden-default setting** — an `AppSettings` field
  (`showHiddenFilesByDefault: bool`, default `false`), persisted in `shared_preferences` under a new
  key, with a setter — mirroring `prefillCommandFromTerminal` (022).
- **`FileBrowserState.showHidden`** — existing per-session flag; its **initial** value on each open
  becomes seeded from the setting instead of hard-coded `false`.

## Success Criteria

- **SC-001**: With the setting **on**, opening the browser yields `showHidden == true` and hidden
  entries appear in `displayEntries` — verifiable by a unit/widget test over `initialize`.
- **SC-002**: With the setting **off** (default), opening the browser yields `showHidden == false`
  (today's behaviour) — verifiable by test.
- **SC-003**: The setting round-trips through `shared_preferences` (persists across a provider reload);
  the default is **off**.
- **SC-004**: After opening with the setting on, tapping the eye sets `showHidden == false` for that
  session (override works) without changing the persisted setting.
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current 448) pass + new
  tests for the setting round-trip/default and the initialise-honours-setting behaviour.

## Assumptions

- **"Hidden or system" = dot-prefixed entries**, the browser's existing `isHidden` definition. SFTP on
  POSIX servers exposes no separate "system" attribute, so no new classification is added.
- **Default off** preserves current behaviour; existing users see no change unless they opt in.
- **Setting seeds the initial state only**; the eye toggle remains a live per-session override and does
  not write back to settings (keeps the two concepts independent and predictable).
- **Global setting**, not per-connection or per-pane (matches the simple boolean nature of the request;
  the start-dir memory in 018 is the per-connection concept, this is not).
- **English, hardcoded UI strings** (no i18n framework), consistent with the rest of the app.

## Scope

**In scope**: the `showHiddenFilesByDefault` setting + its switch in the File browser Settings section;
seeding `FileBrowserState.showHidden` from it in `initialize`; keeping the eye toggle as a per-session
override; unit/widget tests for the setting round-trip and the initialise behaviour.

**Out of scope**: persisting the *per-session* toggle state itself (option 2 in the decision memo);
defaulting on with no opt-out (option 3); per-connection or per-pane hidden-visibility memory; any
change to what counts as "hidden" (no size/attribute/glob filters); a separate "system files" concept;
changes to sort/scroll memory.
