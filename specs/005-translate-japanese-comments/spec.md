# Feature Specification: Translate Japanese Source-Code Comments to English

**Feature Branch**: `005-translate-japanese-comments`
**Created**: 2026-05-30
**Status**: Draft
**Input**: User description: "Go through all the files and translate the Japanese source code comments to English. Make this the next feature."

## Context

The codebase's documentation/governance was migrated to English, but the in-code comments remain
Japanese (analysis recommendation #8 / `03-code-quality.md`). This is a contributor-onboarding
barrier for an open-source project with an English README. This feature translates the in-code
comments to English with **zero behavioral change**.

## User Scenarios & Testing

### User Story 1 - Read the code in English (Priority: P1)

An English-speaking contributor opens any source file and can understand the doc comments and
inline comments without translating Japanese.

**Independent Test**: Pick any previously-Japanese-commented file; confirm its comments are now
natural English and the code behaves identically (analyzer + tests still green).

**Acceptance Scenarios**:

1. **Given** a source file that contained Japanese comments, **When** a contributor reads it,
   **Then** all comments are in English and accurately convey the original meaning.
2. **Given** the translated codebase, **When** `flutter analyze` and `flutter test` run,
   **Then** results are identical to before translation (no new errors/warnings/failures).

### Edge Cases

- **Strings are not comments**: user-facing string literals, log messages, and any runtime text
  MUST NOT be changed — only comments.
- **Identifiers**: class/method/variable names MUST NOT be changed, even if they embed romaji.
- **Mixed lines**: a line with code + a trailing `// 日本語` comment keeps the code byte-for-byte;
  only the comment text changes.
- **Doc references**: `///` doc comments referencing types/params keep those references intact.
- **Non-Latin in data**: Japanese inside test fixtures/expected values (e.g. multibyte test
  payloads like `あいうえお`) MUST NOT be translated — they are test data, not comments.

## Requirements

### Functional Requirements

- **FR-001**: All Japanese text in source-code **comments** (`//`, `///`, `/* */`) across the
  scoped files MUST be translated to clear, accurate English.
- **FR-002**: No code, string literal, identifier, import, or test data may be altered — comments
  only. Indentation and surrounding formatting are preserved.
- **FR-003**: Translations MUST preserve the original meaning, including any caveats/warnings the
  comment conveyed (e.g. lifecycle hazards, ordering workarounds).
- **FR-004**: After translation, `flutter analyze` MUST report no new issues and `flutter test`
  MUST show no new failures versus the pre-translation baseline.

### Scope

In scope: all `lib/**.dart`, `test/**.dart`, and Android `**.kt` files containing Japanese
comments (86 files at time of writing). Out of scope: `docs/`, `specs/`, `README*`, generated
files (`*.g.dart`, `*.freezed.dart`), and any translation of user-facing strings.

## Success Criteria

- **SC-001**: 0 Japanese characters remain in comments across the scoped files (verified by a
  Unicode-range grep, excluding intentional test-data strings).
- **SC-002**: `flutter analyze` issue count and `flutter test` pass/fail counts are unchanged from
  the baseline recorded before this feature.
- **SC-003**: Spot review of a sample of files confirms comments read as natural English and code
  is byte-identical except for comment text.

## Assumptions

- The escaping/host-key code comments authored in feature 004 (also Japanese) are in scope.
- Pre-existing `flutter test` failures (google_fonts network) are environmental and remain the
  baseline; this feature neither fixes nor worsens them.
