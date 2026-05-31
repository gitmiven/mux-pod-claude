# Spec quality checklist — 019 markdown images

- [x] User value clear (P1: images in a README render in the in-app markdown viewer).
- [x] Grounded: flutter_markdown_plus `imageBuilder` hook; reuse `readFileBytes`; resolve vs the .md dir.
- [x] Requirements testable (FR-002 resolve+fetch, FR-003 network/data passthrough, FR-004 placeholders, FR-006 pure resolver).
- [x] Measurable SCs (SC-001 resolver cases, SC-003 missing-image graceful, SC-004 gate).
- [x] Pure resolver isolated for unit testing (relative/absolute/`..`/network/data → path-or-null).
- [x] Edge cases: missing/denied/oversized/non-image, `./`/`../`/nested, percent-encoded, data URI, per-image loading.
- [x] POSIX path semantics noted (remote is Linux; use path posix context).
- [x] Scope bounds: markdown image rendering only — no caching, SVG/video, links; other viewers untouched.
