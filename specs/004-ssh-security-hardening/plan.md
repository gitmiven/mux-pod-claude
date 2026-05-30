# Implementation Plan: SSH Security Hardening (Host-Key Verification & Command-Injection Prevention)

**Branch**: `004-ssh-security-hardening` | **Date**: 2026-05-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/004-ssh-security-hardening/spec.md`

## Summary

Two security hardenings for the SSH layer, delivered test-first:

1. **Host-key verification (TOFU).** Capture the server's host-key fingerprint on first
   successful connection, store it per host endpoint (`host:port`), and verify it on every
   subsequent connection — including automatic reconnect and deep-link launches. On a
   mismatch, fail closed (abort the handshake before auth/credentials), warn the user with
   the old and new fingerprints, and let them abort or explicitly re-trust. Users can view a
   host's trusted fingerprint + first-trusted date and forget it.

2. **Command-injection prevention.** Route every user-derived fragment that enters a
   shell/tmux command through a single shared escaping mechanism (`ShellEscape`), and fix the
   one concrete unescaped interpolation (`ssh_client.dart` `test -x ${tmuxPath}`). SFTP file
   operations already travel over the SFTP protocol (not a shell), so they are not a shell-
   injection surface and are left as-is.

Technical approach: dartssh2's `SSHClient` exposes `onVerifyHostKey(String type, Uint8List md5)`
(the MD5 digest of the server host key, already signature-verified by the protocol). We hook
this callback with a `HostKeyVerifier` backed by a `TrustedHostStore`. Trust is committed only
after a *successful* authentication (so a failed auth never poisons the trust store). Mismatch
returns `false` from the callback → handshake aborts → `SshClient.connect` rethrows a typed
`SshHostKeyChangedError(host, port, stored, presented)` that the provider surfaces to the UI.

## Technical Context

**Language/Version**: Dart 3.10+ / Flutter 3.38.6-stable (pinned in `.mise.toml`)
**Primary Dependencies**: dartssh2 ^2.13.0 (SSH transport + `onVerifyHostKey`), crypto (digests),
shared_preferences (trusted-host persistence), flutter_riverpod (state)
**Storage**: `shared_preferences` under a dedicated key `trusted_host_identities` (fingerprints
are public data, kept in their own namespace, never co-mingled with the connection JSON and
never logged). Secrets remain in `flutter_secure_storage` (unchanged).
**Testing**: `flutter test` — unit tests at the command/parser/store boundary (constitution III)
**Target Platform**: Android (primary); pure-Dart logic is platform-agnostic
**Project Type**: Mobile (Flutter), single app module under `lib/`
**Performance Goals**: Verification adds one map lookup + one digest format per connect; negligible
**Constraints**: Must not break manual connect, reconnect (backoff/offline pause-resume),
keep-alive/disconnect detection, deep-link navigation, or SFTP browsing/transfer (FR-014)
**Scale/Scope**: ~6 new source files, ~6 new test files, edits to `ssh_client.dart`,
`tmux_commands.dart`, `ssh_provider.dart`, `terminal_screen.dart`, `connection_form_screen.dart`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Compliance |
|-----------|------------|
| I. Type Safety | New models are non-nullable, immutable with `copyWith`; host-key data parsed/validated at the dartssh2 boundary before entering domain logic. No `dynamic` except JSON decode at the store boundary. |
| II. KISS & YAGNI | Plain TOFU only (no CA/known_hosts import). Reuse existing `_escapeArg` behavior as the shared escaper rather than inventing a new format. No strict-mode/first-use prompt (deferred per spec Assumptions). |
| III. Test-First | Pure units (fingerprint format, TOFU decision, store CRUD, `ShellEscape`) are TDD'd red→green before wiring. SshClient/provider wiring covered by store/verifier tests + targeted provider tests. |
| IV. Security-First | This feature *is* the security work: host-key verification (TOFU, fail-closed), central command escaping, no secret/keymaterial logging in warnings or diagnostics. |
| V. SOLID | `TrustedHostStore` is an injectable abstraction (DIP); `HostKeyVerifier` has one responsibility (SRP); `ShellEscape` is a focused shared utility. |
| VI. DRY | `ShellEscape` is the single command-escaping mechanism (FR-013); `TmuxCommands._escapeArg` delegates to it. |

**Naming**: new dirs/files use `snake_case`; no `utils/helpers/common/misc`. New service lives under
`lib/services/ssh/` (host-key) and `lib/services/shell/` (escaping) — concrete domain names.

**Result**: PASS (no violations; Complexity Tracking not required).

## Project Structure

### Documentation (this feature)

```text
specs/004-ssh-security-hardening/
├── plan.md              # This file
├── research.md          # Phase 0 — decisions & rejected alternatives
├── data-model.md        # Phase 1 — entities
├── quickstart.md        # Phase 1 — how to exercise the feature
├── tasks.md             # Phase 2 — ordered task list (/speckit.tasks)
└── checklists/
    └── requirements.md  # spec quality gate (already PASS)
```

### Source Code (repository root)

```text
lib/
├── services/
│   ├── shell/
│   │   └── shell_escape.dart            # NEW — single shared escaping mechanism (FR-013)
│   └── ssh/
│       ├── host_key_fingerprint.dart    # NEW — MD5 digest → "MD5:xx:.." formatting
│       ├── trusted_host_identity.dart   # NEW — model + JSON
│       ├── trusted_host_store.dart       # NEW — SharedPreferences-backed CRUD (per host:port)
│       ├── host_key_verifier.dart        # NEW — TOFU decision + dartssh2 callback builder
│       └── ssh_client.dart               # EDIT — wire onVerifyHostKey, escape tmuxPath,
│                                          #        SshHostKeyChangedError, commit-on-auth
├── providers/
│   └── ssh_provider.dart                 # EDIT — pass verifier, surface mismatch, no reconnect-loop
├── services/tmux/tmux_commands.dart      # EDIT — _escapeArg delegates to ShellEscape
└── screens/
    ├── terminal/terminal_screen.dart     # EDIT — show mismatch dialog on SshHostKeyChangedError
    ├── terminal/widgets/host_key_mismatch_dialog.dart  # NEW — warning + abort/re-trust
    └── connections/connection_form_screen.dart         # EDIT — show fingerprint + Forget

test/
├── services/shell/shell_escape_test.dart           # NEW
├── services/ssh/host_key_fingerprint_test.dart     # NEW
├── services/ssh/trusted_host_identity_test.dart    # NEW
├── services/ssh/trusted_host_store_test.dart       # NEW
├── services/ssh/host_key_verifier_test.dart        # NEW
└── services/tmux/tmux_commands_test.dart           # EDIT — add adversarial escaping cases
```

**Structure Decision**: Single Flutter app module. Pure, unit-testable logic (escaping,
fingerprint formatting, TOFU decision, store) lives in `lib/services/**` and is mocked at the
command/store boundary per the constitution. UI (dialog, form section) lives in `lib/screens/**`.
State orchestration stays in `lib/providers/ssh_provider.dart`.

## Complexity Tracking

> No Constitution Check violations — section intentionally empty.
