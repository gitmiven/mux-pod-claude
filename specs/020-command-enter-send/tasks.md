# Tasks — Enter sends in the command-input panel (soft keyboard)

- [x] **T001** TextField → `TextInputAction.send` + `onSubmitted: _handleSend` (keyboardType text).
- [x] **T002** Keep hardware Enter/Shift+Enter/composing behaviour + in-flight no-double-send guard.
- [x] **T003** [TDD] Tests: field exposes send action; IME send action calls onSend once (+2).
- [x] **T004** Gate: analyze exit 0; flutter test 395; existing hardware tests still pass.
- [ ] **T005** Commit, push, PR; CI green.
