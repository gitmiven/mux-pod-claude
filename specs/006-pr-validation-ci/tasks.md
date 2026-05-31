# Tasks — PR Validation CI

- [x] **T001** Diagnose why `flutter test` isn't green offline (google_fonts network fetch).
- [x] **T002** Bundle `JetBrainsMono-Regular.ttf` + OFL license as assets; declare in `pubspec.yaml`.
- [x] **T003** Add `test/flutter_test_config.dart` disabling google_fonts runtime fetching.
- [x] **T004** Fix the unmasked `settings_provider` set-state-after-dispose bug (`ref.mounted` guard).
- [x] **T005** Remove the unused import that produced the lone analyzer warning.
- [x] **T006** Verify: `flutter analyze --no-fatal-infos` exits 0; `flutter test` 325 pass / 0 fail.
- [x] **T007** Add `.github/workflows/ci.yml` (analyze + test on PR/push-to-main, Flutter 3.38.6 pinned).
- [ ] **T008** Commit, open PR, and confirm the CI run goes green on the PR.

## Traceability

| FR/SC | Tasks |
|-------|-------|
| FR-001, 002, 003, 004 | T007 |
| FR-005 / SC-003 | T002, T003, T004, T006 |
| FR-002 / SC-002 | T005, T007 |
| SC-001, SC-004 | T007, T008 |
