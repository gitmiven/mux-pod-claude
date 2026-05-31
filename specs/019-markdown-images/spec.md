# Feature Specification: Render embedded images in the in-app Markdown viewer

**Feature Branch**: `019-markdown-images` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: the `.md` viewer does not support viewing images. Add image support.

## Context

Feature 017 added an in-app Markdown viewer (`FileViewerScreen`, `_buildMarkdown`) that renders a
remote `.md` over SFTP with `Markdown(data: text, selectable: true)` (`flutter_markdown_plus`). But
**embedded images don't show**: by default the renderer treats `![alt](src)` as a network/asset image,
so a relative or absolute **remote** path (`./diagram.png`, `images/x.png`, `/srv/app/logo.png`) — the
common case in a repo's README — can't be reached, and renders as broken/blank.

`flutter_markdown_plus` exposes an **`imageBuilder: (Uri uri, String? title, String? alt) → Widget`**
hook on the `Markdown` widget. We supply a builder that:

- resolves a **relative** `src` against the **directory of the `.md` file** (`widget.path`), keeps an
  **absolute** `src` as-is (POSIX semantics — the server is Linux), and
- **fetches the image over SFTP** (reusing `SftpBrowserService.readFileBytes`, size-capped) and shows
  it via `Image.memory`, while
- leaving **`http`/`https`** sources to load over the network and **`data:`** URIs to render from their
  inline bytes.

## User Scenarios & Testing

### User Story 1 — See images in a README (Priority: P1)

A user opens a `README.md` in the Markdown viewer. Images it references — a logo at `./logo.png`, a
diagram at `docs/arch.png`, a shared asset at `../assets/banner.png` — appear inline, fetched from the
server over SFTP.

**Why P1**: It's the request — markdown with images should show the images.

**Acceptance scenarios**:
1. **Given** `/srv/app/README.md` containing `![logo](logo.png)`, **when** it opens, **then** the image
   at `/srv/app/logo.png` is fetched over SFTP and rendered inline.
2. **Given** `![arch](docs/arch.png)` in the same file, **then** `/srv/app/docs/arch.png` renders.
3. **Given** `![b](../assets/banner.png)`, **then** `/srv/assets/banner.png` renders (`..` resolved).
4. **Given** `![abs](/opt/x/pic.png)`, **then** `/opt/x/pic.png` renders (absolute kept as-is).
5. **Given** `![web](https://example.com/i.png)`, **then** it loads over the network as before.

### Edge cases

- **Missing / denied / oversized / non-image** source: that image shows a small **broken-image
  placeholder**; the rest of the document still renders (one bad image never blanks the page).
- **Relative path with `./` or `../` or nested dirs**: normalised correctly against the doc directory.
- **Percent-encoded src** (`my%20img.png`): decoded before fetching.
- **`data:` URI**: rendered from its inline bytes (no SFTP).
- **Loading**: each image shows a lightweight placeholder until its bytes arrive; images load
  independently (one slow image doesn't block the others or the text).

## Requirements

- **FR-001**: The Markdown viewer MUST render images referenced by `![alt](src)`.
- **FR-002**: For a non-network `src`, the image MUST be fetched **over SFTP**; a **relative** path is
  resolved against the **`.md` file's directory**, an **absolute** path is used as-is (POSIX `/`).
- **FR-003**: `http`/`https` sources MUST load over the network (unchanged); `data:` URIs MUST render
  from their inline bytes.
- **FR-004**: A failed image (missing/denied/oversized/undecodable) MUST show a broken-image
  placeholder without breaking the rest of the document; each image MUST show a loading placeholder.
- **FR-005**: Image reads MUST be size-capped (reuse `SftpBrowserService.readFileBytes`).
- **FR-006**: The src-resolution logic (relative/absolute/network/data → remote path or "not SFTP")
  MUST be a pure, unit-testable function.
- **FR-007**: The change MUST be limited to the Markdown viewer's image rendering — text rendering,
  the Image/Text viewers, and the rest of the browser are unchanged.

## Key Entities

- **Resolved image source** — the result of mapping a markdown image `Uri` (+ the doc's path) to either
  a concrete **remote SFTP path** or **null** (meaning "load via network / inline, not SFTP").

## Success Criteria

- **SC-001**: For a doc at `/srv/app/README.md`, the resolver maps `logo.png` → `/srv/app/logo.png`,
  `docs/a.png` → `/srv/app/docs/a.png`, `../assets/b.png` → `/srv/assets/b.png`, `/opt/x.png` →
  `/opt/x.png`, and `http(s)://…`/`data:…` → null — verifiable by unit tests.
- **SC-002**: An SFTP-resolved image renders from fetched bytes; a `data:` image renders inline; an
  `http(s)` image uses the network.
- **SC-003**: A missing/oversized image shows a placeholder and the surrounding markdown still renders.
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests
  for the resolver.

## Assumptions

- **POSIX paths** (remote is Linux); resolution uses the `path` package's posix context so it's
  independent of the phone's OS.
- **Reuse the 5 MiB read cap** from `readFileBytes`; an oversized image just shows the placeholder.
- **No caching** of fetched images in this feature (each open refetches); fine for typical README use.
- **No markdown-link navigation, SVG, or video** — raster images only, as the underlying widget
  supports.

## Scope

**In scope**: a custom `imageBuilder` for the Markdown viewer; a pure src→remote-path resolver;
SFTP-fetched `Image.memory` with loading/error placeholders; network/data passthrough; unit tests for
the resolver.

**Out of scope**: image caching; SVG/video/PDF; clickable links; changing the Image/Text viewers; a
configurable size cap; pre-fetching or prioritising images.
