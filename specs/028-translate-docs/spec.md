# Feature Specification: Translate the project docs to English

**Feature Branch**: `028-translate-docs` | **Created**: 2026-06-01 | **Status**: Draft
**Input**: User: the documentation files are still Japanese — translate the real docs (the `docs/*.md`
design docs and `ios/Runner/Info.plist` user-facing strings) to English, leaving `README.ja.md` and the
old `001–003` spec archives alone.

## Context

Feature 005 translated in-code **comments** and 014 translated user-facing **UI strings**, but the
project **documentation** was never in scope and is still Japanese. A reliable Unicode scan found
Japanese in many tracked files; this feature targets the **maintained docs** developers read, plus the
one user-facing native file:

- `docs/tmux-mobile-design-v2.md` (design doc)
- `docs/ui-guidelines.md`
- `docs/coding-conventions.md`
- `docs/working_pane.md`
- `ios/Runner/Info.plist` (iOS permission-description strings shown to users)

Deliberately **excluded** (not translated):
- `README.ja.md` and the `🇯🇵 日本語` link in `README.md` — the intentional Japanese README.
- `specs/001-*`…`specs/003-*` and `.specify/memory/constitution.md` — historical upstream spec archives
  (low value, not maintained).
- Japanese in `test/**` fixtures/comments — out of scope (test behaviour, not docs).

## Requirements

- **FR-001**: Translate all Japanese prose in the 4 `docs/*.md` files to clear, natural English,
  **preserving** markdown structure (headings, lists, tables), code blocks/inline code, links, image
  refs, and anchors.
- **FR-002**: Translate the user-facing Japanese **string values** in `ios/Runner/Info.plist` (the
  permission `*UsageDescription` entries) to English, leaving keys and XML structure intact.
- **FR-003**: The excluded files (`README.ja.md`, `README.md`'s JA link, `specs/001–003`,
  `.specify/...`, `test/**`) MUST be left unchanged.
- **FR-004**: No code/behaviour change — docs and plist strings only; the build/test gate stays green.

## Success Criteria

- **SC-001**: 0 Japanese characters remain in the 4 targeted `docs/*.md` files and in the translated
  `ios/Runner/Info.plist` string values (Unicode scan).
- **SC-002**: Markdown still renders (structure/links/code intact); the plist remains valid XML.
- **SC-003**: The excluded files are untouched (git diff shows no change to them).
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 448 pass (docs-only change).

## Assumptions

- English-first, faithful translation; technical terms kept as-is (tmux, SSH, pane, etc.).
- The `docs/screens/*.html` mockups (if any Japanese) are generated artifacts — out of scope unless
  trivially the same strings; primary targets are the four `.md` docs + the plist.
- No i18n framework; the JA README stays as the localized copy.

## Scope

**In scope**: translate the 4 `docs/*.md` files + the `ios/Runner/Info.plist` user-facing strings;
verify 0 Japanese remains in those; gate green.

**Out of scope**: `README.ja.md`, README JA link, the `001–003` spec archives, `.specify` constitution,
test fixtures, generated HTML mockups, screenshots.
