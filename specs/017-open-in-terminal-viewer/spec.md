# Feature Specification: Open a file in a terminal viewer (configurable per extension)

**Feature Branch**: `017-open-in-terminal-viewer` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: in the file browser's per-file action menu (file name+path / Rename / Delete), add a
4th button **between the name and Rename** that opens the file in a terminal viewer — e.g. an image in
`timg`, a `.md` in `glow`. Which extension opens with which tool is **configurable in the options**.

## Context

The file icon at the top of the terminal opens a **file browser** for the current folder
(`FileBrowserScreen`, opened from `terminal_screen_logic.dart:_handleFileBrowser` with the active
`connectionId` and `paneId`). Tapping a file shows a modal action menu
(`lib/screens/file_browser/widgets/file_action_menu.dart`) built from:

```dart
enum FileAction { open, rename, delete }
```

— a header (file **name** + full **path** + size), then `Open` (directories only), `Rename`,
`Delete`. We add a **new action** that, for files, opens them in a terminal viewer **in the active
tmux pane** (the terminal the browser was launched from), then returns to the terminal so the user
sees the viewer's output.

Grounding for the pieces this needs:

- **Run a command in the active pane**: the app already sends shell text to the current pane via
  `TmuxCommands.loadBufferAndPaste(target, text)` / `sendKeys` and `SshClient.exec` (see
  `_sendMultilineText`). Opening a viewer = sending `"<tool> <path>\n"` to that pane.
- **The tapped file**: `FileEntry` exposes `name`, `fullPath`, `isDirectory`, and a normalised
  lower-case `extension` getter (`file_entry.dart:57`).
- **Configurable options**: settings are a structured `AppSettings` (immutable + `copyWith`) persisted
  to `shared_preferences` via `settingsProvider`, each surfaced in `settings_screen.dart`. A new
  **extension → tool** mapping fits this model (persisted as JSON, since prefs holds primitives).
- **Path safety**: the app has `ShellEscape.quote` (used by `TmuxCommands`); the file path MUST be
  escaped before it goes into the command.

## User Scenarios & Testing

### User Story 1 — View a file in its terminal viewer (Priority: P1)

A user browsing files taps an image (or a `.md`). The action menu shows a new **"Open with `<tool>`"**
button (e.g. *Open with timg* / *Open with glow*) just under the name/path header. Tapping it runs the
configured tool on that file **in the terminal they came from** and returns to the terminal, where the
rendered image / markdown is now visible.

**Why P1**: It is the feature — turn a browsed file into a rendered view using the user's terminal tools.

**Acceptance scenarios**:
1. **Given** an extension→tool mapping `png → timg`, **when** the user opens the menu for `pic.png` and
   taps the new button, **then** the app sends `timg <escaped /path/to/pic.png>` followed by Enter to
   the **active pane** and navigates back to the terminal.
2. **Given** a mapping `md → glow`, **when** the user taps the button for `README.md`, **then**
   `glow <escaped path>` + Enter runs in the active pane.
3. **Given** the button is shown, **then** its label reflects the tool that will be used
   (e.g. *Open with timg*), so the user knows what will happen before tapping.

### User Story 2 — Configure which extension opens with which tool (Priority: P1)

In Settings, the user manages a list of **extension → tool** mappings: add a mapping (e.g. `jpg` →
`timg`), edit a tool, or remove a mapping. The app ships sensible defaults (common image extensions →
`timg`, `md` → `glow`). Changes persist across app restarts and take effect on the next menu open.

**Why P1**: The user explicitly asked for the mapping to be configurable; without it the feature is
hard-coded.

**Acceptance scenarios**:
1. **Given** the Settings screen, **when** the user adds/edits/removes a mapping, **then** it is saved
   and reflected the next time the file menu is opened.
2. **Given** a fresh install, **then** default mappings exist (images → `timg`, `md` → `glow`).
3. **Given** the user maps several extensions to the same tool, **then** all of them open with it.

### Edge cases

- **Unmapped extension**: a file whose extension has no mapping shows **no** viewer button — the menu
  is the original three items (the feature never blocks Rename/Delete). (See Assumptions for the
  considered alternative of a disabled button + hint.)
- **Directory**: the viewer button never appears for directories (they already have `Open`).
- **No extension / dotfile**: treated as unmapped (no button).
- **No active pane / disconnected**: if there is no pane to run in, the action is unavailable or
  surfaces a clear message (consistent with how the command-input panel behaves when disconnected) —
  it must not fail silently or crash.
- **Path with spaces / special chars**: the path is shell-escaped, so `my file.png` opens correctly
  and nothing is injected.
- **Tool not installed on the server**: out of the app's control — the viewer command simply errors in
  the pane (the user sees the shell error); the app does not pre-verify the binary.

## Requirements

- **FR-001**: The file action menu MUST show a **4th item between the name/path header and Rename**
  that opens the file in a terminal viewer — shown **only for files whose extension has a configured
  mapping** (never for directories).
- **FR-002**: Tapping it MUST send `"<tool> <shell-escaped fullPath>"` followed by Enter to the
  **active tmux pane** (the pane the browser was opened with) using the existing send path, then return
  the user to the terminal view.
- **FR-003**: The button's label MUST indicate the tool that will be used (e.g. *Open with timg*).
- **FR-004**: The file path MUST be shell-escaped (reuse `ShellEscape`) — no command injection.
- **FR-005**: An **extension → tool** mapping MUST be user-configurable in Settings (add / edit /
  remove), persisted across restarts, and applied on the next menu open.
- **FR-006**: The app MUST ship default mappings: common image extensions (`png`, `jpg`, `jpeg`, `gif`,
  `webp`, `bmp`) → `timg`, and `md` → `glow`.
- **FR-007**: Extension matching MUST be case-insensitive (reuse `FileEntry.extension`, already
  lower-cased); multiple extensions MAY map to the same tool.
- **FR-008**: When there is no active pane / no connection, the action MUST be unavailable or show a
  clear message — never a silent no-op or crash.
- **FR-009**: The change MUST NOT alter the existing menu items (header, `Open`, `Rename`, `Delete`) or
  other browser behaviour.

## Key Entities

- **Extension→tool mapping** — an ordered/keyed set of `{ extension → tool }` entries, held in
  `AppSettings` and persisted (JSON) via `settingsProvider`. `extension` is a bare lower-case
  extension (no dot); `tool` is the command/binary to run (the file path is appended). Ships with the
  FR-006 defaults.

## Success Criteria

- **SC-001**: For a mapped extension, the menu shows the viewer button (labelled with the tool) above
  Rename; tapping it produces the command `"<tool> <escaped path>\n"` targeted at the active pane and
  navigates back to the terminal — verifiable by a unit test over the command-building function and a
  widget test over menu construction.
- **SC-002**: For an unmapped extension (and for directories), the viewer button is absent and the menu
  is otherwise unchanged.
- **SC-003**: Settings can add/edit/remove a mapping; the value round-trips through
  `shared_preferences` (persists across a provider reload); defaults are present on first run.
- **SC-004**: A path containing a space/quote is escaped such that the emitted command is safe and
  opens the correct file.
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 368 pass (plus new tests for
  the mapping lookup, command building, and settings round-trip).

## Assumptions

- **Runs in the existing pane, not a new one**: the viewer command is sent to the pane the browser was
  launched from, and the app returns to the terminal to show it. (Alternative — spawn a new
  window/pane — is out of scope; the user described "open in a terminal viewer", i.e. their current
  terminal.)
- **Tool string is a command prefix**: the configured `tool` is the binary (optionally with flags); the
  escaped path is appended as the final argument (`<tool> <path>`). A placeholder syntax for the path
  position is out of scope.
- **Unmapped → hidden button** (chosen over a disabled button with a "no viewer configured" hint) for a
  cleaner menu; revisit if users want discoverability.
- **No tool installation/validation**: the app neither installs nor checks for `timg`/`glow`; a missing
  tool just errors in the shell.
- **English, hardcoded UI strings** (consistent with the rest of the app; no i18n framework).

## Scope

**In scope**: the new `FileAction` viewer item + its visibility logic; building and sending the
`<tool> <path>` command to the active pane via the existing send path + returning to the terminal;
the extension→tool mapping in `AppSettings`/prefs with defaults; a Settings UI to add/edit/remove
mappings; shell-escaping the path; unit/widget tests.

**Out of scope**: in-app image/markdown rendering (it runs in the terminal); spawning a new
window/pane; installing or verifying the viewer tools; per-connection mappings; opening directories in
a viewer; MIME/content-based detection (extension-based only).
