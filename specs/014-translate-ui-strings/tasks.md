# Tasks — Translate user-facing UI strings to English

- [x] **T001** Scan lib for Japanese in non-comment (string) positions → 231 chars in 5 files.
- [x] **T002** Translate the strings to English (file browser, biometric prompts, SSH notification,
  command-input hint), preserving `$`/`${}` interpolations, `\n`, and structure.
- [x] **T003** Verify SC-001: 0 Japanese chars remain in non-comment positions across all of lib.
- [x] **T004** Verify gate: analyze exit 0; flutter test 357 pass (no behavior change).
- [ ] **T005** Commit, push, PR; CI green.
