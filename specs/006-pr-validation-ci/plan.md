# Implementation Plan: PR Validation CI

**Branch**: `006-pr-validation-ci` | **Date**: 2026-05-31 | **Spec**: [spec.md](./spec.md)

## Summary

Add a GitHub Actions workflow (`.github/workflows/ci.yml`) that runs `flutter analyze
--no-fatal-infos` and `flutter test` on every pull request and on pushes to `main`, with Flutter
pinned to 3.38.6. To make the test job meaningful, also fix the three things that kept the suite
from being green offline.

## Technical Context

**CI**: GitHub Actions, `subosito/flutter-action@v2` (matches `release.yml`), pinned `flutter-version: 3.38.6`
**Gate**: `flutter analyze --no-fatal-infos` (fatal on errors/warnings) + `flutter test`
**Test determinism fix**: bundle JetBrains Mono so google_fonts loads it from assets instead of
fetching over the network (which the test harness blocks)

## Constitution Check

| Principle | Compliance |
|-----------|------------|
| I. Type Safety | No type changes; `ref.mounted` guard is sound null-safe. |
| II. KISS & YAGNI | Single workflow; bundle only the one font the tests measure (not all 7 families). |
| III. Test-First | This feature's deliverable *is* the test gate; it makes the existing suite green (315→325) and adds CI that runs it. |
| IV. Security-First | No secrets in CI; bundling the font removes a runtime network dependency. |
| V/VI. SOLID/DRY | The provider guard fixes a real set-state-after-dispose latent bug (SRP/lifecycle correctness). |

**Result**: PASS.

## Changes

| File | Change |
|------|--------|
| `.github/workflows/ci.yml` | NEW — analyze + test on PR/push-to-main, Flutter 3.38.6, pub cache. |
| `assets/fonts/JetBrainsMono-Regular.ttf` | NEW — bundle the default terminal font (OFL). |
| `assets/fonts/JetBrainsMono-LICENSE.txt` | NEW — OFL license (matches HackGen/UDEVGothic convention). |
| `pubspec.yaml` | EDIT — declare the two new assets. |
| `test/flutter_test_config.dart` | NEW — `GoogleFonts.config.allowRuntimeFetching = false` so tests never hit the network. |
| `lib/providers/settings_provider.dart` | EDIT — `if (!ref.mounted) return;` before set-state after the async load. |
| `test/services/terminal/ansi_parser_test.dart` | EDIT — remove an unused import (the one analyzer warning). |

## Why these specific fixes

- **google_fonts (10 failures)**: `terminal_font_styles.dart` resolves `GoogleFonts.jetBrainsMono()`;
  in tests the harness stubs HTTP (returns 400), so the async font load fails and retroactively
  fails the measuring tests (`font_calculator`, and `terminal_display_provider` via it). Bundling
  `JetBrainsMono-Regular.ttf` as an asset + `allowRuntimeFetching = false` makes google_fonts load
  it locally — no fetch, no throw. Only the *measured* font needs bundling; widget tests that merely
  build with other families (e.g. Space Grotesk) do not throw.
- **settings_provider (9 of the 10)**: once fonts were fixed, the real cause surfaced — `_loadSettings`
  set state after the test container disposed. The `ref.mounted` guard fixes the latent
  "set state after dispose" bug (also reachable in the app by leaving a screen mid-load).
- **analyzer warning**: `flutter analyze` exits non-zero on the one unused-import warning; removing it
  lets `--no-fatal-infos` pass while keeping warnings fatal.

## Verification

`flutter analyze --no-fatal-infos` → exit 0; `flutter test` → 325 pass / 0 fail. Validate the
workflow on the PR itself (the first run executes against this branch).

## Complexity Tracking

> No Constitution Check violations.
