# Tasks — pre-fill the command popup from the terminal input line

- [x] **T001** Pure `InputLineExtractor.extract` (ANSI + box/prompt strip, raw fallback).
- [x] **T002** Setting `prefillCommandFromTerminal` (default false) + setter + Terminal toggle.
- [x] **T003** `_currentInputLinePrefill()` from the cursor row of the captured pane.
- [x] **T004** Wire popup `initialValue`; clear-then-send (`C-u`/`C-a`/`C-k`) when pre-filled.
- [x] **T005** [TDD] Tests: extractor cases; setting round-trip (+8).
- [x] **T006** Gate: analyze exit 0; flutter test 413 (raised a brittle settings-scroll helper's reach).
- [ ] **T007** Commit, push, PR; CI green.
