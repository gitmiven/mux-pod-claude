# Plan — 015 variable key bar (F1–F10)

## Design
The bar is a **new top row inside `SpecialKeysBar`** (not a separate widget), so it shares the
existing modifier state and the `_sendSpecialKey` path — modifier composition (S-/C-/M-) comes for
free (FR-007), and the existing two rows are untouched (FR-006).

Data-driven (FR-002): a pure `KeyBarConfig { name, List<KeyBarButton{label, tmuxKey}> }`. Ships one
config, `KeyBarConfig.functionKeys` (F1–F10). `SpecialKeysBar.variableKeyBar` defaults to it
(always visible), or null to hide. A future feature supplies a different config — no terminal-screen
re-wiring (SC-003).

## Files
- **New**: `lib/widgets/key_bar_config.dart` (data model + functionKeys);
  `test/widgets/function_key_bar_test.dart` (6 tests).
- **Modified**: `lib/widgets/special_keys_bar.dart` (import, `variableKeyBar` field, render row first);
  `lib/widgets/special_keys_bar_view.dart` (`_buildVariableKeyBar`).

## Verification
analyze exit 0; flutter test 363 pass (+6). Buttons reuse `_buildSpecialKeyButton` (Expanded) → fit
any width; tap → `_sendSpecialKey('Fn')` → tmux `send-keys Fn`.
