# Tasks — Translate Japanese Source-Code Comments to English

- [x] **T001** Record baseline: `flutter analyze` issue count + `flutter test` pass/fail.
- [x] **T002** Generate the file manifest (Japanese in `lib/**.dart`, `test/**.dart`, `android/**.kt`;
  exclude `*.g.dart`, `*.freezed.dart`).
- [x] **T003** Translate via multi-agent workflow (one Haiku agent per file): comments only;
  preserve code, strings, identifiers, test data, and formatting. (86 files)
- [x] **T004** Verify SC-001: re-grep for Japanese; confirm only intentional test-data strings remain.
- [x] **T005** Verify SC-002: `flutter analyze` (no new issues) + `flutter test` (no new failures)
  vs. baseline.
- [x] **T006** Verify SC-003: `dart format` no-op on touched files where applicable; spot-review a
  sample of files (large/critical ones: `terminal_screen.dart`, `ssh_client.dart`, `ssh_provider.dart`).
- [x] **T007** Commit and open PR into `main`.

## Traceability

| FR/SC | Tasks |
|-------|-------|
| FR-001, 002, 003 | T003 |
| FR-004 / SC-002 | T001, T005 |
| SC-001 | T004 |
| SC-003 | T006 |
