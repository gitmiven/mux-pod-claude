# Feature Specification: More file types — CSV / ZIP in-app, the rest "Open with"

**Feature Branch**: `026-more-file-viewers` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: extend the in-app file viewer to handle `.mp4 .webm .html .zip .csv .xls .doc`.
Decision (confirmed): **lean in-app** — CSV → table, ZIP → file listing in-app; everything else
(`html mp4 webm xls doc`) downloads to the device and opens in the system app ("Open with…").

## Context

Feature 017 added in-app viewers (Image / Markdown / Text) chosen per extension via a configurable map,
fetched over SFTP and rendered in `FileViewerScreen`. This adds three handlers:

- **`csv`** — parse and render as a scrollable **table** (pure-Dart `csv`).
- **`archive`** — list the **entries inside a zip** (name + size) (pure-Dart `archive`); not extraction.
- **`external`** — **download** the file to the device and hand it to Android's **"Open with…"** chooser
  (`open_filex` + a temp file via `path_provider`). Used for binary/heavy formats Dart can't render
  in-app (`xls`, `doc`) and ones better handled by a dedicated app (`html`, `mp4`, `webm`), and works as
  a universal escape hatch for any extension.

The extension→viewer-type map (017) gains the new types with defaults for the requested extensions.

## User Scenarios & Testing

### User Story 1 — View CSV and ZIP in-app (Priority: P1)

Tapping a `.csv` opens a table of its rows/columns; tapping a `.zip` opens a list of the files inside
(name + size) — both rendered in the app, fetched over SFTP.

**Acceptance scenarios**:
1. **Given** `data.csv`, **when** opened, **then** an in-app scrollable table of its parsed rows shows.
2. **Given** `bundle.zip`, **when** opened, **then** a list of the archive's entries (name, size) shows.
3. **Given** a malformed/over-cap CSV or ZIP, **then** a clear message shows (no crash).

### User Story 2 — Open other types externally (Priority: P1)

Tapping `.html`, `.mp4`, `.webm`, `.xls`, or `.doc` (mapped to `external`) downloads the file to the
device and opens Android's "Open with…" chooser, so it opens in a proper app (browser / video player /
sheets / docs).

**Acceptance scenarios**:
1. **Given** `clip.mp4` mapped to External, **when** the user taps "Open with…", **then** the file is
   downloaded and the system "Open with" chooser appears for it.
2. **Given** the download fails / is too large / not connected, **then** a clear message shows (no crash).
3. **Given** a fresh install, **then** the defaults are: `csv → CSV`; `zip → Archive`;
   `html, mp4, webm, xls, doc → External`.

### Edge cases

- **Large files** (videos): the external download is **size-capped** with a higher limit and shows
  progress/refusal beyond it; CSV/ZIP keep the existing 5 MiB in-app cap.
- **CSV quirks**: quoted fields, commas-in-quotes, CRLF — handled by the `csv` parser; ragged rows render
  as-is.
- **Encrypted / corrupt zip**: shows a message, not a crash.
- **No app to open the type**: the "Open with" chooser reports it (OS behaviour); the app shows the
  `open_filex` result if it failed.
- **Temp files**: downloaded files go to the app's temp/cache dir (not user-visible storage).

## Requirements

- **FR-001**: Add viewer types **`csv`**, **`archive`**, and **`external`** to the configurable
  extension→viewer map, with defaults: `csv→csv`, `zip→archive`, and `html, mp4, webm, xls, doc →
  external` (existing image/markdown/text defaults unchanged).
- **FR-002**: A **CSV** file MUST render in-app as a scrollable table of parsed rows/columns
  (size-capped; clear message on failure/over-cap).
- **FR-003**: A **ZIP** file MUST render in-app as a list of its entries (name + size); failure shows a
  message (not extraction in v1).
- **FR-004**: An **external**-mapped file MUST be **downloaded to the device** (temp dir, size-capped)
  and opened via the OS "Open with…" chooser; failures show a clear message.
- **FR-005**: The Settings "File viewers" editor MUST let the user pick any of the (now 6) viewer types
  for an extension (the type selector accommodates them).
- **FR-006**: CSV parsing and ZIP-entry listing MUST be **pure, unit-testable** functions.
- **FR-007**: Existing viewers (image/markdown/text), the menu, and the rest of the browser MUST be
  unchanged; the new types slot into the same "Open with <viewer>" menu flow.

## Key Entities

- **FileViewerType** (existing enum) — gains `csv`, `archive`, `external`.
- **Zip entry** — `{ name, size }` listed from the archive.

## Success Criteria

- **SC-001**: `FileViewerType` resolves the new names + defaults; a unit test covers the mapping.
- **SC-002**: A CSV byte payload parses into rows (pure helper test); the screen renders a table.
- **SC-003**: A ZIP byte payload lists its entries (pure helper test); the screen renders the list.
- **SC-004**: An external-mapped file triggers the download-then-open-with path (verified by wiring /
  a unit test over the routing decision); failures are handled.
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests;
  the Android **release APK still builds** (open_filex/native config correct).

## Assumptions

- **External = download + `open_filex.open`** to the app's temp dir; no in-app rendering for those types.
- **CSV/ZIP in-app**, pure-Dart (`csv`, `archive`); ZIP shows a **listing**, not extraction.
- **Size caps**: CSV/ZIP keep the 5 MiB in-app cap; external download uses a larger cap (e.g. ~100 MiB)
  and streams to a file to avoid OOM.
- New deps: `csv`, `archive`, `open_filex`, `path_provider`. Android needs `open_filex`'s FileProvider
  wiring; verify the release build.
- English, hardcoded UI strings (no i18n framework).

## Scope

**In scope**: the 3 new viewer types + defaults; CSV table + ZIP listing in-app; external download +
"Open with"; Settings type selector for 6 types; streaming SFTP download to temp; pure parser tests +
type-mapping tests; Android open_filex config + release-build check.

**Out of scope**: in-app video/HTML/Office rendering; zip extraction or in-zip preview; editing files;
per-cell CSV editing; remembering downloads; caching; iOS "open with" specifics beyond what the plugin
provides.
