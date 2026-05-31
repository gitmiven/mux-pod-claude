# Tasks — variable key bar (F1–F10)

- [x] **T001** Data model: `KeyBarConfig` / `KeyBarButton` + `functionKeys` (F1–F10) [key_bar_config.dart].
- [x] **T002** [TDD] Tests: config has F1–F10; bar renders 10 keys; tap sends F1/F5/F10; SHIFT+F1 → S-F1; null hides.
- [x] **T003** Add `variableKeyBar` field to `SpecialKeysBar` (default `functionKeys`); render as top row.
- [x] **T004** `_buildVariableKeyBar(config)` in the view mixin — buttons via `_sendSpecialKey` (modifiers compose).
- [x] **T005** Gate: analyze exit 0; flutter test 363 pass (+6).
- [ ] **T006** Commit, push, PR; CI green.
