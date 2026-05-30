# Tasks — SSH Security Hardening

TDD order: write the failing test (Red) → implement (Green) → refactor. `[P]` = parallelizable
(independent files). Pure-logic tasks come before wiring; UI last.

## Phase A — Command-injection prevention (User Story 4 · FR-011–013)

- [x] **T001** [P] Test: `test/services/shell/shell_escape_test.dart` — adversarial cases for
  `ShellEscape.quote`: plain word unquoted; spaces, single/double quotes, `;`, `|`, `&`, `$`,
  `$()`, backticks, `<`, `>`, newline, empty string (`""`), already-safe paths (`%0`, `/usr/bin/tmux`).
- [x] **T002** Impl: `lib/services/shell/shell_escape.dart` — `ShellEscape.quote` (selective
  double-quote, empty→`""`). Make green.
- [x] **T003** Edit: `lib/services/tmux/tmux_commands.dart` — `_escapeArg` delegates to
  `ShellEscape.quote`. Run `tmux_commands_test.dart` — all existing assertions still green.
- [x] **T004** Edit + Test: `lib/services/ssh/ssh_client.dart` — escape user `tmuxPath` in the
  `test -x` check via `ShellEscape.quote`; escape resolved tmux path in `_resolveTmuxCommand`.
- [x] **T005** [P] Test: extend `tmux_commands_test.dart` with explicit injection cases
  (`report;backup`, `$(id)`, backticks, newline) asserting they are quoted, not executable.

## Phase B — Host-key model & store (User Story 2/3 foundation · FR-001, 008–010)

- [x] **T006** [P] Test: `test/services/ssh/host_key_fingerprint_test.dart` — `formatMd5` →
  `MD5:` + colon-hex lowercase; zero-padding; known vector.
- [x] **T007** Impl: `lib/services/ssh/host_key_fingerprint.dart`.
- [x] **T008** [P] Test: `test/services/ssh/trusted_host_identity_test.dart` — `copyWith`,
  `toJson/fromJson` round-trip, `endpointKey`.
- [x] **T009** Impl: `lib/services/ssh/trusted_host_identity.dart`.
- [x] **T010** Test: `test/services/ssh/trusted_host_store_test.dart` — CRUD with
  `SharedPreferences.setMockInitialValues`: save/get, upsert replace, getAll, remove, per-`host:port`.
- [x] **T011** Impl: `lib/services/ssh/trusted_host_store.dart`.

## Phase C — Verifier (User Story 1 · FR-002–006)

- [x] **T012** Test: `test/services/ssh/host_key_verifier_test.dart` — decision logic: firstUse
  (no record), match, mismatch; `trustNewHostKey` override replaces; fail-closed contract.
- [x] **T013** Impl: `lib/services/ssh/host_key_verifier.dart` — `HostKeyVerificationOutcome`
  decision + a builder producing the dartssh2 `onVerifyHostKey` callback + pending-trust capture +
  mismatch capture. `SshHostKeyChangedError`.

## Phase D — SshClient & provider wiring (FR-002, 006, 007)

- [x] **T014** Edit: `lib/services/ssh/ssh_client.dart` — accept `hostKeyVerifier` +
  `trustNewHostKey`; pass `onVerifyHostKey`; commit pending trust / refresh `lastVerifiedAt` after
  `authenticated`; map `SSHHostkeyError` + stashed mismatch → `SshHostKeyChangedError`; fail closed.
- [x] **T015** Edit: `lib/providers/ssh_provider.dart` — build store+verifier; pass to connect for
  `connect`, `connectWithoutShell`, `_doReconnect`; add `hostKeyChange` to `SshState`; on
  `SshHostKeyChangedError` set state and STOP reconnect (no loop); add
  `trustChangedHostKeyAndReconnect()` and `forgetHostKey(host, port)`.

## Phase E — UI (User Story 1/2/3 · FR-004, 005, 008, 009)

- [x] **T016** New: `lib/screens/terminal/widgets/host_key_mismatch_dialog.dart` — shows old/new
  fingerprint + key type; returns abort/re-trust.
- [x] **T017** Edit: `lib/screens/terminal/terminal_screen.dart` — in `_connectAndSetup` catch,
  detect `SshHostKeyChangedError` → show dialog; on re-trust call
  `trustChangedHostKeyAndReconnect()` and continue setup.
- [x] **T018** Edit: `lib/screens/connections/connection_form_screen.dart` — "Server identity"
  section (edit mode): show trusted fingerprint + first-trusted date; "Forget host identity" button.

## Phase F — Gate & docs

- [x] **T019** `flutter analyze` (0 new issues) · `flutter test` (only the 10 pre-existing
  google_fonts failures remain) · `dart format`.
- [x] **T020** Update `CLAUDE.md` Recent Changes / note; confirm constitution Security-First items
  (host-key verify + escaping) now satisfied.

## Traceability

| FR | Tasks |
|----|-------|
| FR-001 | T013, T014 |
| FR-002, 003 | T012–T015 |
| FR-004, 005 | T015, T016, T017 |
| FR-006 (fail closed) | T013, T014 |
| FR-007 (reconnect/deep-link) | T015, T017 |
| FR-008, 009 | T010, T011, T015, T018 |
| FR-010 | T011 (dedicated namespace, no logging) |
| FR-011, 012, 013 | T001–T005 |
| FR-014 (no regression) | T003, T019 |
| FR-015 (no secret logging) | T013, T014 (assert no fingerprint/secret in logs) |
