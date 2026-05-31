# Feature Specification: Open a file in an in-app viewer (configurable per extension)

**Feature Branch**: `017-open-in-terminal-viewer` | **Created**: 2026-05-31 | **Status**: Draft (revised)
**Input**: User: in the file browser's per-file action menu (name+path / Rename / Delete), add a 4th
item **between the name and Rename** that opens the file in a viewer — images and markdown. The file
browser is a **Flutter screen, not the tmux terminal**, so the viewer must be **in-app** (not a
terminal tool like `timg`/`glow`). Which extension opens with which viewer is **configurable in
options**.

> **Revision note**: an earlier draft of this spec sent a terminal tool (`timg`/`glow`) to the active
> pane and switched back to the terminal. The user corrected this: the browse-and-open flow lives in
> the app, so opening must render **inside the app**. This spec supersedes that approach.

## Context

The file icon at the top of the terminal opens a **file browser** (`FileBrowserScreen`, a Flutter
screen pushed over the terminal; it reads the remote filesystem over **SFTP** via
`sshClient.openSftp()` + `SftpBrowserService`). Tapping a file shows a modal action menu
(`file_action_menu.dart`) built from `enum FileAction { open, rename, delete }` — a header (name +
path + size), then `Open` (directories only), `Rename`, `Delete`.

We add a new action that opens the file in an **in-app viewer screen**: it fetches the file's bytes
over SFTP and renders them according to a **viewer type** chosen by the file's extension:

- **Image** — render the bytes in a zoomable image view (`Image.memory` + `InteractiveViewer`).
- **Markdown** — render the decoded text with a markdown renderer (`flutter_markdown_plus`).
- **Text** — show the decoded text in a selectable monospace view.

Grounding:

- **Read a file over SFTP**: `dartssh2` `SftpClient.open(path).readBytes(length: …)` returns the bytes;
  reads are **capped** (a max size) so a huge/binary file can't OOM the app.
- **The tapped file**: `FileEntry` exposes `name`, `fullPath`, `isDirectory`, and a normalised
  lower-case `extension` getter.
- **Configurable options**: settings are a structured `AppSettings` (immutable + `copyWith`) persisted
  to `shared_preferences` via `settingsProvider`; a new **extension → viewer-type** map fits this model
  (persisted as JSON).

## User Scenarios & Testing

### User Story 1 — View a file in the app (Priority: P1)

A user browsing files taps an image (or a `.md`). The action menu shows a new **"Open with <Viewer>"**
item (e.g. *Open with Image* / *Open with Markdown*) under the name/path header. Tapping it opens an
in-app viewer that fetches the file over SFTP and renders it (zoomable image / rendered markdown /
selectable text) — **without leaving the app or touching the terminal**.

**Why P1**: It is the feature — preview a browsed file in place.

**Acceptance scenarios**:
1. **Given** `png → Image`, **when** the user taps the new item for `pic.png`, **then** an in-app image
   viewer opens showing `pic.png` (zoom/pan), fetched over SFTP.
2. **Given** `md → Markdown`, **when** the user taps it for `README.md`, **then** an in-app markdown
   viewer opens showing the rendered document.
3. **Given** `txt → Text`, **when** the user taps it for `notes.txt`, **then** an in-app text viewer
   shows the file's selectable contents.
4. **Given** the item is shown, **then** its label reflects the viewer that will be used (*Open with
   Image* / *Markdown* / *Text*).

### User Story 2 — Configure which extension opens with which viewer (Priority: P1)

In Settings, the user manages a list of **extension → viewer-type** mappings: add a mapping (e.g.
`jpg → Image`), change a type, or remove one. The app ships defaults (common image extensions → Image,
`md`/`markdown` → Markdown, `txt`/`log` → Text). Changes persist across restarts and apply on the next
menu open.

**Acceptance scenarios**:
1. **Given** Settings, **when** the user adds/edits/removes a mapping, **then** it is saved and
   reflected next time the file menu opens.
2. **Given** a fresh install, **then** default mappings exist (images → Image, `md` → Markdown,
   `txt`/`log` → Text).
3. **Given** several extensions mapped to the same viewer, **then** all open with it.

### Edge cases

- **Unmapped extension**: a file whose extension has no mapping shows **no** viewer item — the menu is
  the original three (never blocks Rename/Delete).
- **Directory**: the viewer item never appears for directories (they already have `Open`).
- **No extension / dotfile**: treated as unmapped (no item).
- **File too large / binary mismatch**: the viewer enforces a max read size; over the cap (or bytes that
  don't decode as text for a text/markdown viewer) it shows a clear message, not a crash or OOM.
- **Read fails (permissions / gone / disconnected)**: the viewer shows an error state, not a silent
  blank or crash.
- **Image fails to decode**: the image viewer shows an "unsupported / corrupt image" message.

## Requirements

- **FR-001**: The file action menu MUST show a **4th item between the name/path header and Rename** that
  opens the file in an **in-app** viewer — shown **only for files whose extension has a configured
  viewer** (never for directories).
- **FR-002**: Tapping it MUST open an in-app viewer screen that fetches the file's bytes **over SFTP**
  and renders them by the configured **viewer type** (Image / Markdown / Text). Nothing is sent to the
  terminal/tmux.
- **FR-003**: The item's label MUST indicate the viewer that will be used (e.g. *Open with Markdown*).
- **FR-004**: An **extension → viewer-type** mapping MUST be user-configurable in Settings (add / edit /
  remove), persisted across restarts, and applied on the next menu open.
- **FR-005**: The app MUST ship defaults: common image extensions (`png`, `jpg`, `jpeg`, `gif`, `webp`,
  `bmp`) → Image; `md`, `markdown` → Markdown; `txt`, `log` → Text.
- **FR-006**: Extension matching MUST be case-insensitive (reuse `FileEntry.extension`); multiple
  extensions MAY map to the same viewer type.
- **FR-007**: File reads MUST be **size-capped**; exceeding the cap (or an unreadable/undecodable file)
  MUST produce a clear in-viewer message — never a crash, OOM, or silent blank.
- **FR-008**: The viewer MUST show **loading** and **error** states while/around the SFTP fetch.
- **FR-009**: The change MUST NOT alter the existing menu items (header, `Open`, `Rename`, `Delete`) or
  other browser behaviour, and MUST NOT send anything to the active pane.

## Key Entities

- **FileViewerType** — an enum: `image`, `markdown`, `text` (the in-app renderers).
- **Extension→viewer-type mapping** — a keyed set `{ extension → FileViewerType }` held in
  `AppSettings` and persisted (JSON of `extension → type-name`) via `settingsProvider`. `extension` is a
  bare lower-case extension (no dot). Ships with the FR-005 defaults.

## Success Criteria

- **SC-001**: For a mapped extension, the menu shows the viewer item (labelled with the viewer type)
  above Rename; tapping it opens the corresponding in-app viewer for that file — verifiable by a widget
  test over menu construction and a unit test over extension → type resolution.
- **SC-002**: For an unmapped extension (and for directories), the viewer item is absent and the menu is
  otherwise unchanged.
- **SC-003**: Settings can add/edit/remove a mapping; the value round-trips through `shared_preferences`
  (persists across a provider reload); defaults are present on first run.
- **SC-004**: A read beyond the size cap (or an undecodable text file) yields a clear message, not a
  crash/OOM.
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 368 pass (plus new tests for
  the type resolution, settings round-trip, and menu construction).

## Assumptions

- **In-app rendering, not the terminal**: viewers render inside the app from SFTP-fetched bytes; nothing
  is run in a pane. (This is the user's correction to the original terminal-tool idea.)
- **Three built-in viewer types** (Image / Markdown / Text) cover the initial need; more types are a
  later feature. The mapping chooses among these types — it is **not** an arbitrary shell command.
- **Markdown via `flutter_markdown_plus`** (the maintained successor to the discontinued
  `flutter_markdown`).
- **Size cap** is a fixed sensible default (e.g. a few MB) — not user-configurable in this feature.
- **Unmapped → hidden item** (cleaner menu) rather than a disabled item with a hint.
- **English, hardcoded UI strings** (no i18n framework).

## Scope

**In scope**: the `FileViewerType` enum; the extension→viewer-type map in `AppSettings`/prefs with
defaults + a Settings UI to add/edit/remove; the new menu item + visibility logic; an in-app viewer
screen that SFTP-fetches (size-capped) and renders Image/Markdown/Text with loading/error states;
adding `flutter_markdown_plus`; unit/widget tests.

**Out of scope**: sending anything to the terminal/tmux; editing files in the viewer; syntax
highlighting; video/audio/PDF/office viewers; MIME/content-based detection (extension-based only);
per-connection mappings; a user-configurable size cap; caching downloaded files.
