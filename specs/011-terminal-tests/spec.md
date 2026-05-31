# Feature Specification: Terminal Characterization Tests

**Feature Branch**: `011-terminal-tests` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: "do terminal tests" (analysis recommendation #5).

## Context

The terminal is the most-churned, most bug-prone area (IME, paste, special keys, modifiers) and had
**no widget/behavior tests** — the analysis flagged this (#5), and 007/009 (decomposition) unblocked
it. The full `TerminalScreen` is heavily coupled to SSH/timers/providers (hard to widget-test), but
the **input widgets** — `SpecialKeysBar` and `AnsiTextView` — expose clean public callback surfaces,
so their key/modifier behavior can be characterized directly.

## Requirements

- **FR-001**: Add widget tests for `SpecialKeysBar` covering special keys, arrows, literal keys, and
  modifier composition (Ctrl/Alt/Shift → `C-`/`M-`/`S-` prefixes in `S-C-M` order; one-shot consume;
  the Shift+Tab → `BTab` special case).
- **FR-002**: Add widget tests for `AnsiTextView` hardware key handling (Escape/Enter/Tab/Backspace →
  correct bytes + tmux key names; arrow keys; modifier-only presses emit nothing).
- **FR-003**: Tests must not depend on a live SSH backend; drive behavior through the widgets' public
  callbacks (`onKeyPressed`/`onSpecialKeyPressed`, `onKeyInput`).
- **FR-004**: Keep test output clean — silence `AppLog` in tests by default (via `flutter_test_config`).

## Success Criteria

- **SC-001**: New tests characterize the special-key/modifier behavior and the hardware-key mapping;
  all pass. Total suite 335 → **348** (+13).
- **SC-002**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` 0 failures.
- **SC-003**: No `AppLog` debug noise in test output.

## Scope
In scope: `SpecialKeysBar` + `AnsiTextView` characterization tests; quiet logging in tests.
Out of scope: full `TerminalScreen` integration tests (need a fake SSH harness — a larger, separate
effort); copy-mode/polling tests (depend on the SSH/timer engine).

## Notes
`AnsiTextView` runs a repeating cursor-blink animation, so tests use explicit `pump()`s rather than
`pumpAndSettle()`. It reads `settingsProvider`/`terminalDisplayProvider`, so tests wrap it in a
`ProviderScope` with mocked `SharedPreferences`.
