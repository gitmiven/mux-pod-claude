# Implementation Plan: Per-Connection tmux Socket Selection

**Branch**: `031-tmux-socket-selection` | **Date**: 2026-06-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/031-tmux-socket-selection/spec.md`

## Summary

Add an optional per-connection tmux socket so the app can attach to a non-default tmux
server (e.g. the `fleet` socket created with `tmux -L fleet`). The socket is persisted on
the `Connection` profile, surfaced in the connection-settings form, and injected as a global
option immediately after the tmux binary on **every** tmux invocation — including the chained
load-buffer/paste-buffer pipeline — at the single existing choke point
(`TmuxCommandResolver.resolve`). A bare value becomes `tmux -L <name>`; a value containing a
`/` becomes `tmux -S <path>` (name-vs-path inferred from the path separator, so the UI stays a
single text field). Unset → byte-for-byte identical to today. The value is shell-escaped via
the existing `ShellEscape`.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.24+ (toolchain pinned to mise flutter 3.38.6)
**Primary Dependencies**: flutter_riverpod, dartssh2, shared_preferences, google_fonts
**Storage**: `shared_preferences` (connection profiles persisted as JSON by `connectionsProvider`)
**Testing**: `flutter test` (pure unit tests for the resolver + model round-trip); `flutter analyze --no-fatal-infos`
**Target Platform**: Android + iOS
**Project Type**: Mobile (single Flutter app)
**Performance Goals**: N/A — change is in command-string construction, no hot path
**Constraints**: Backward compatible (FR-008); no new dependencies; injection only at the existing resolver choke point
**Scale/Scope**: One new optional string field + one resolver branch + one form field + tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/`) and conventions emphasise: a single shared shell-escaping
mechanism (no ad-hoc quoting), a single tmux-command choke point, TDD via the analyze+test gate,
and backward compatibility for existing users. This plan:

- **Reuses** `ShellEscape.quote` for the socket value (no new escaping) ✓
- **Reuses** the single `TmuxCommandResolver` choke point — no new injection sites ✓
- **Adds pure, unit-testable logic** (socket-flag construction inside the resolver) ✓
- **Preserves** unset behavior byte-for-byte (FR-008 / SC-003) ✓
- **Mirrors** the existing `tmuxPath` per-connection field end-to-end (model → options → UI) ✓

No violations. No Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/031-tmux-socket-selection/
├── spec.md              # Feature spec (already written)
├── plan.md              # This file
├── research.md          # Phase 0 — name-vs-path inference + injection-point decisions
├── data-model.md        # Phase 1 — Connection.tmuxSocket
├── quickstart.md        # Phase 1 — manual validation against the fleet socket
└── checklists/
    └── requirements.md   # Spec quality checklist (already written)
```

### Source Code (repository root)

```text
lib/
├── services/
│   ├── ssh/
│   │   ├── tmux_command_resolver.dart   # MODIFIED — inject -L/-S socket flag (core change)
│   │   └── ssh_client.dart              # MODIFIED — SshConnectOptions.tmuxSocket; store + pass _tmuxSocket
│   └── shell/shell_escape.dart          # REUSED — no change
├── providers/
│   └── connection_provider.dart         # MODIFIED — Connection.tmuxSocket (field/json/copyWith)
└── screens/
    ├── connections/connection_form_screen.dart  # MODIFIED — socket text field + save/test wiring
    ├── home_screen.dart                          # MODIFIED — pass tmuxSocket into SshConnectOptions
    └── terminal/terminal_screen_logic.dart       # MODIFIED — pass tmuxSocket in _getAuthOptions
    └── connections/widgets/connection_card.dart  # MODIFIED — pass tmuxSocket into SshConnectOptions
    └── providers/notification_panes_provider.dart # MODIFIED — pass tmuxSocket into SshConnectOptions

test/
├── services/ssh/tmux_command_resolver_test.dart  # MODIFIED — socket-flag cases
└── providers/connection_socket_test.dart          # NEW — Connection json round-trip for tmuxSocket
```

**Structure Decision**: Single Flutter app. The change rides the existing `tmuxPath`
end-to-end path; the only architecturally significant edit is the resolver, which already
rewrites every command-position `tmux` token for piped/chained commands — so applying the
socket flag there satisfies FR-003/FR-004 for free.

## Phase 0 — Research (see research.md)

Key decisions resolved:

1. **Name vs path = inferred from `/`** (single text field, no toggle) — keeps the model and UI
   to one optional string; matches how tmux users distinguish `-L name` from `-S /path`.
2. **Inject at `TmuxCommandResolver.resolve`**, extended to also handle the `tmuxPath == null`
   case (literal `tmux` binary + socket flag), so the socket still applies when the binary
   wasn't detected.
3. **Idempotency**: `execPersistent`'s fallback re-runs `exec()` (which re-resolves). Change the
   fallback to pass the **raw** command so resolution happens exactly once — avoids a double
   `-L` flag in the (rare) literal-`tmux` path. With an absolute path, resolution was already
   idempotent.

## Phase 1 — Design (see data-model.md, quickstart.md)

- `Connection` gains one nullable `String? tmuxSocket` (persisted in `toJson`/`fromJson`,
  threaded through `copyWith`), mirroring `tmuxPath`.
- `SshConnectOptions` gains `String? tmuxSocket`; `SshClient` stores `_tmuxSocket` and passes it
  to `_resolveTmuxCommand` → `TmuxCommandResolver.resolve(command, _tmuxPath, tmuxSocket: _tmuxSocket)`.
- The connection form gets a "TMUX SOCKET (OPTIONAL)" text field between TMUX PATH and DEEP LINK ID.

## Complexity Tracking

No constitution violations — table omitted.
