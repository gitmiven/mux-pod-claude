# Feature Specification: PR Validation CI

**Feature Branch**: `006-pr-validation-ci`
**Created**: 2026-05-31
**Status**: Draft
**Input**: User description: "Add a GitHub Actions workflow that runs flutter analyze + flutter test on push/PR (pinned to the project's Flutter version). Make this the next feature." (Analysis recommendation #11.)

## Context

CI today only **releases** (`release.yml`, `release-ios.yml`) — nothing validates pushes or PRs,
even though the `Makefile` defines `analyze` and `test`. Quality depends on contributors running
checks locally. A lightweight validation workflow is a cheap, high-leverage guard for every change.

A prerequisite surfaced while building this: the test suite was **not green** in a sandboxed/CI
environment (10 failures). Those had to be fixed for the test job to be meaningful — they are
included in this feature.

## User Scenarios & Testing

### User Story 1 - Every PR is automatically validated (Priority: P1)

A contributor opens a PR. GitHub automatically runs `flutter analyze` and `flutter test`; the PR
shows a clear pass/fail status before review/merge.

**Acceptance Scenarios**:

1. **Given** a PR with code that passes analysis and tests, **When** it is opened/updated, **Then**
   the CI check runs and reports success.
2. **Given** a PR that introduces an analyzer error/warning or a failing test, **When** it is
   opened/updated, **Then** the CI check fails and blocks a clean merge signal.
3. **Given** a push to `main`, **When** it lands, **Then** the same validation runs.

### User Story 2 - The test suite is green in CI (Priority: P1)

For the test job to be meaningful, `flutter test` must pass in a clean/offline CI runner.

**Acceptance Scenarios**:

1. **Given** a fresh CI runner (no font cache, network-restricted test harness), **When**
   `flutter test` runs, **Then** all tests pass (no environment-dependent failures).

## Requirements

### Functional Requirements

- **FR-001**: A GitHub Actions workflow MUST run on `pull_request` and on `push` to `main`.
- **FR-002**: The workflow MUST run `flutter analyze` and fail on analyzer **errors or warnings**
  (pre-existing deprecation *infos* are not treated as fatal).
- **FR-003**: The workflow MUST run `flutter test` and fail if any test fails.
- **FR-004**: The Flutter toolchain MUST be pinned to the project's version (`3.38.6`, per
  `.mise.toml`) for reproducible results.
- **FR-005**: The test suite MUST pass deterministically in CI. Specifically, the google_fonts
  network dependency that made 10 tests fail MUST be removed so tests run offline.
- **FR-006**: No production behavior change beyond what is required to make tests deterministic and
  the analyzer clean of warnings.

## Success Criteria

- **SC-001**: On a PR, the CI workflow runs analyze + test and reports a single clear status.
- **SC-002**: `flutter analyze --no-fatal-infos` exits 0 on `main` (zero errors/warnings).
- **SC-003**: `flutter test` passes 100% (0 failures) on a clean runner — verified locally at
  325 passing / 0 failing.
- **SC-004**: A deliberately-broken PR (analyzer error or failing test) is caught by CI.

## Scope

In scope: the CI workflow; the minimal fixes to make the suite green (bundle the default terminal
font so google_fonts does not fetch in tests; guard one provider against set-state-after-dispose;
remove one unused import that produced an analyzer warning).

Out of scope: fixing the 32 pre-existing deprecation *infos*; broader test coverage; release-flow
changes; bundling all google_fonts families (only the one the tests measure is bundled).
