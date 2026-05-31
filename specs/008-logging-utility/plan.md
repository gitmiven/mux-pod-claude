# Implementation Plan: Logging Utility & Secret-Leak Audit

**Branch**: `008-logging-utility` | **Date**: 2026-05-31 | **Spec**: [spec.md](./spec.md)

## Summary

Add a single, level-gated, release-safe logging utility (`AppLog`) and route the ~84 ad-hoc
`debugPrint`/`developer.log` sites through it. Fix the one concrete secret-leak risk
(`ssh_client` logging raw command stdout/stderr) and audit the rest.

## Technical Context

**Logger**: `lib/services/logging/app_log.dart` — `AppLog` with `LogLevel {debug,info,warning,error,none}`,
an injectable `LogSink`, level gating, and a default that is **off in release** (`kReleaseMode`).
**Gate**: `flutter analyze --no-fatal-infos` + `flutter test`. **Migration**: mechanical, CRLF-preserving.

## Constitution Check

| Principle | Compliance |
|-----------|------------|
| I. Type Safety | Enum-typed levels; no `dynamic`. |
| II. KISS | One small static utility; no third-party logging package (YAGNI). |
| III. Test-First | Logger gating/sink/format unit-tested before migration. |
| IV. Security-First | Core purpose: no secret/command-output logging; release-gated. Directly satisfies the constitution's "never log secrets; gate diagnostics off in release." |
| V/VI. SOLID/DRY | Single shared logger (DRY); injectable sink (DIP) for testability. |

**Result**: PASS.

## Design

```dart
enum LogLevel { debug, info, warning, error, none }
typedef LogSink = void Function(String line);

class AppLog {
  static LogLevel level = kReleaseMode ? LogLevel.none : LogLevel.debug; // release: off
  static LogSink sink = _default;                                        // tests swap this
  static void d/i/w(String message, {String? tag});
  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace});
  // _emit: returns early if level==none or level too high; try/catch so it never throws.
}
```

## Migration mapping

| Old | New |
|-----|-----|
| `debugPrint('m')` | `AppLog.d('m')` |
| `developer.log('m', name: 'T')` | `AppLog.d('m', tag: 'T')` |
| `developer.log('m', name: 'T', error: e, stackTrace: s)` | `AppLog.e('m', tag: 'T', error: e, stackTrace: s)` |

- Remove `import 'dart:developer' as developer;`; add `import '…/services/logging/app_log.dart';`.
- ~14 files; CRLF-preserving edits. Auto-convert the common shapes via script; hand-fix any the
  script can't (multiline calls). `flutter analyze` after each pass.

## Secret-leak fixes (FR-004)

- `ssh_client.dart` `exec:`/`execWithExitCode` logs of raw `stdout`/`stderr` → log only
  **byte counts**, never content.
- Audit `persistent_shell.dart`, `terminal_screen_logic.dart` (polling), `tmux_parser.dart` for any
  raw command/pane-content logging; reduce to metadata.
- The two `connection_form_screen` password lines already log *status* only ("Saving password…") — keep.

## Files

- **New:** `lib/services/logging/app_log.dart`; `test/services/logging/app_log_test.dart`;
  `specs/008-logging-utility/*`.
- **Modified:** ~14 `lib/**` files (route logging through `AppLog`); `ssh_client.dart` (secret fix);
  `CLAUDE.md` Recent Changes.

## Verification

- Grep: 0 `print(`/`debugPrint(`/`developer.log(` in `lib/` outside `app_log.dart` (SC-001).
- Logger tests: off-level suppresses all; level gating; sink capture; never-throws (SC-002/003).
- `flutter analyze --no-fatal-infos` exit 0; `flutter test` 328+ pass (SC-005).

## Complexity Tracking
> No Constitution Check violations.
