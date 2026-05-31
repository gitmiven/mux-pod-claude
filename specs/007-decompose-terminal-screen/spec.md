# Feature Specification: Decompose `terminal_screen.dart` (Slice 1 — extract helper classes)

**Feature Branch**: `007-decompose-terminal-screen`
**Created**: 2026-05-31
**Status**: Draft
**Input**: User: "Decompose terminal_screen.dart next." (Analysis recommendation #1 — P1 god-widget.)

## Context

`lib/screens/terminal/terminal_screen.dart` was 4,527 lines — ~18% of `lib/` in one file, the app's
most important and most-churned screen, effectively untestable as a unit (#1, #5). The decomposition is
done incrementally so behavior is preserved and CI (006) guards each step.

**This slice (user-chosen scope):** move the 7 self-contained helper classes that sit below the main
state class — painters, dialogs, a pane-layout visualizer — into their own files. Pure, behavior-
identical relocations. Extracting controllers from `_TerminalScreenState` is deferred to follow-up slices.

## User Scenarios & Testing

### User Story 1 - Smaller, navigable, testable terminal module (Priority: P1)

A contributor can find and unit-test the terminal's helper widgets without scrolling a 4,500-line file.

**Acceptance Scenarios**:
1. **Given** the refactor, **When** the app runs, **Then** terminal behavior (pane layout overlay,
   command input, new-window/resize dialogs) is identical to before.
2. **Given** the extracted widgets, **When** a contributor writes a widget test for one (e.g. the
   new-window dialog's name validation), **Then** it can be imported and tested directly.

## Requirements

### Functional Requirements
- **FR-001**: The 7 helper classes MUST move into separate files under `lib/screens/terminal/widgets/`
  with no behavior change.
- **FR-002**: No logic, string literal, or UI behavior may change — relocation + visibility only.
- **FR-003**: Widgets referenced from `_TerminalScreenState` MUST be made public; truly file-local
  helpers (the two split-icon painters, the `*State` classes) stay private.
- **FR-004**: The test-only factory `buildInputDialogContentForTesting` MUST be removed; its test now
  imports the extracted `InputDialogContent` directly.
- **FR-005**: `flutter analyze` (no new errors/warnings) and `flutter test` MUST stay green.

## Success Criteria
- **SC-001**: `terminal_screen.dart` shrinks from 4,527 to ≈3,290 lines.
- **SC-002**: 5 new files under `lib/screens/terminal/widgets/`, each a self-contained widget module.
- **SC-003**: `flutter analyze --no-fatal-infos` exits 0; `flutter test` passes (325 existing + new
  dialog test = 328), confirming behavior is unchanged.
- **SC-004**: At least one extracted widget gains a direct widget test (new-window dialog validation).

## Scope
In scope: relocating the 7 helper classes, updating call sites + the one test, one new widget test.
Out of scope: extracting controllers from `_TerminalScreenState` (polling, input/IME, copy-mode, tmux
ops) — separate follow-up slices; any behavior/UI change; translating the Japanese UI string `改行`.
