# Tasks — full-width TUI backgrounds

- [x] **T001** `AnsiParser.lineFillColor` from the carried `endStyle` (inverse→fg; null=default).
- [x] **T002** Wrap each rendered line in a full-width `ColoredBox` when fill is non-null.
- [x] **T003** [TDD] Parser tests: carry across lines / plain=null / SGR49 ends fill / inverse=fg (+4).
- [x] **T004** Gate: analyze exit 0; flutter test 405.
- [ ] **T005** Commit, push, PR; CI green; manual mc check.
