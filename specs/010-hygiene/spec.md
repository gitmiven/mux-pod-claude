# Feature Specification: Hygiene Bundle

**Feature Branch**: `010-hygiene` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: "do hygiene bundle" (analysis recommendations #9 + #10).

## Context

Three low-risk hygiene items from the analysis: the `pubspec.yaml` description is still the default
placeholder (#9); unused desktop/web platform scaffolding inflates the repo surface for an
Android+iOS-only app (#9); and `specs/` reuses `001`/`002` prefixes across the pre/post-migration
eras, which is confusing without a map (#10).

## Requirements

- **FR-001**: Replace the placeholder `pubspec.yaml` `description` with a real one describing MuxPod.
- **FR-002**: Remove the unused platform scaffolding folders `web/`, `linux/`, `macos/`, `windows/`
  (the product targets **Android + iOS** only — confirmed by `release.yml` + `release-ios.yml` and the
  README). Keep `android/` and `ios/`.
- **FR-003**: Add `specs/README.md` mapping the feature timeline and explaining the `001`/`002`
  numbering collisions (pre-migration RN/Expo era vs. the Flutter era).
- **FR-004**: No code/behavior change; `flutter analyze --no-fatal-infos` exit 0 and `flutter test`
  335 pass / 0 fail are unaffected.

## Success Criteria

- **SC-001**: `pubspec.yaml` has a meaningful description (not "A new Flutter project.").
- **SC-002**: `web/ linux/ macos/ windows/` are gone; `android/ ios/` remain; analyze + test still green.
- **SC-003**: `specs/README.md` exists and lists every feature folder with its era and status.

## Scope
In scope: the three items above. Out of scope: renaming/moving existing spec folders (the README
documents the collisions rather than renumbering, to preserve history/links).
