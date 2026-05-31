# Feature Specification: Logging Utility & Secret-Leak Audit

**Feature Branch**: `008-logging-utility`
**Created**: 2026-05-31
**Status**: Draft
**Input**: User: "logging utility + secret audit" (analysis recommendation #6 / §04-security item 3).

## Context

The app logs via ~84 ad-hoc sites: **39 `debugPrint`** and **45 `developer.log`** (0 raw `print`).
`debugPrint` is **not stripped in release builds**, so diagnostics ship to production logs. The
most concrete risk: `ssh_client.dart` logs **raw remote command stdout/stderr** (`exec: stdout="…"`)
— command output can contain sensitive data (capture-pane content, command results, anything a
user runs). There is no consistent, level-gated, release-safe logging path.

## User Scenarios & Testing

### User Story 1 - No diagnostics (or secrets) leak in release (Priority: P1)

In a release build, the app emits no debug diagnostics, and in no build does it log secrets
(passwords, passphrases, private keys) or raw remote command output that may contain them.

**Acceptance Scenarios**:
1. **Given** a release build, **When** any logging call runs, **Then** nothing is emitted (the
   logger is gated off).
2. **Given** a debug build, **When** a logging call runs at or above the active level, **Then** it
   is emitted with a consistent tag/level format.
3. **Given** SSH command execution, **When** it completes, **Then** raw stdout/stderr content is
   NOT logged (only non-sensitive metadata, e.g. byte counts, may be logged).

### User Story 2 - Consistent, level-gated diagnostics for developers (Priority: P2)

A developer can log at debug/info/warning/error levels through one utility, and gate verbosity.

**Acceptance Scenarios**:
1. **Given** the logger's level set to `warning`, **When** a `debug` call runs, **Then** it is
   suppressed; a `warning`/`error` call is emitted.
2. **Given** a test, **When** logging is exercised, **Then** output can be captured via an
   injectable sink and asserted (the logger is unit-testable).

### Edge Cases
- Logging must never throw (a logging failure must not crash the app).
- `error`-level logs may include an error object + stack trace, but never secret values.
- Existing `developer.log(name:)` tags map to the new logger's tag.

## Requirements

### Functional Requirements
- **FR-001**: Provide a single logging utility with levels (debug, info, warning, error) and a tag.
- **FR-002**: The utility MUST be gated so that it emits **nothing in release builds** by default
  (e.g. level defaults to off when `kReleaseMode`).
- **FR-003**: All existing `debugPrint`/`developer.log` sites in `lib/` MUST be routed through the
  utility (no direct `debugPrint`/`print`/`developer.log` left in `lib/`, except inside the utility).
- **FR-004**: No log call may emit secret material — passwords, passphrases, private keys — or raw
  remote command stdout/stderr. The `ssh_client` command-output logs MUST be reduced to
  non-sensitive metadata (or removed).
- **FR-005**: The utility MUST be unit-testable: level gating and output are verifiable via an
  injectable sink, without depending on build mode.
- **FR-006**: Logging MUST never throw out of the utility.

### Success Criteria
- **SC-001**: 0 direct `print(`/`debugPrint(`/`developer.log(` calls remain in `lib/` outside the
  logging utility (verified by grep).
- **SC-002**: With the level off (release default), a logging call produces no sink output (test).
- **SC-003**: Level gating works: a below-threshold call is suppressed, at/above is emitted (test).
- **SC-004**: No log statement in `lib/` emits a password/passphrase/private-key value or raw
  command stdout/stderr (verified by audit + the `ssh_client` fix).
- **SC-005**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` 328+ pass / 0 fail.

## Scope
In scope: a `lib/services/logging/` utility; migrating the 84 sites; fixing the `ssh_client`
command-output logs; tests for the utility.
Out of scope: a third-party logging package; remote log shipping; changing what non-sensitive
events are logged (only the mechanism + secret fixes).
