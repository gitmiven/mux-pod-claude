# Feature Specification: Translate user-facing UI strings to English

**Feature Branch**: `014-translate-ui-strings` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: menus/dialogs are still in Japanese — translate the user-facing strings to English.

## Context

Feature 005 translated source-code **comments** to English but deliberately left **user-facing
string literals** (menus, dialogs, labels, prompts) in Japanese. So the running app still shows
Japanese in: the file browser, the biometric-auth prompts, the SSH foreground notification, and the
command-input hint. This feature translates those strings to English (the fork is English-first).

A Unicode-range scan found **231 Japanese characters in non-comment positions across 5 files**:
`file_browser_screen.dart` (file browser UI), `ssh_auth.dart` (biometric prompts),
`file_action_menu.dart` (Open/Rename/Delete), `foreground_task_service.dart` (notification title),
`input_dialog_content.dart` (`Shift+Enter: 改行`).

## Requirements

- **FR-001**: Translate all user-facing Japanese **string literals** in those 5 files to clear,
  natural English, preserving interpolations (`$connectionName`, `${entry.name}`), `\n`, and structure.
- **FR-002**: No code/identifier/logic change — only the text inside string literals.
- **FR-003**: Use hardcoded English (consistent with the existing hardcoded-string approach); no
  localization framework (YAGNI — the fork is English-only).
- **FR-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 357 pass.

## Success Criteria

- **SC-001**: 0 Japanese characters remain in non-comment (string) positions in `lib/` (Unicode grep).
- **SC-002**: analyze exit 0; test suite unchanged (no behavior change beyond visible text).
- **SC-003**: Spot review confirms the file browser, biometric prompt, notification, and command hint
  read naturally in English.

## Scope
In scope: the 5 files' UI strings. Out of scope: a localization/i18n framework, Android/iOS native
strings (the app label is already "MuxPod Claude"), test-data strings.
