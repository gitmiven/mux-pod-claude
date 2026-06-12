# Phase 1 Data Model: Per-Connection tmux Socket Selection

## Entity: `Connection` (modified)

`lib/providers/connection_provider.dart`. Gains **one** optional attribute, mirroring the
existing `tmuxPath`.

| Field        | Type      | Default | Persisted | Notes |
|--------------|-----------|---------|-----------|-------|
| `tmuxSocket` | `String?` | `null`  | yes (JSON key `tmuxSocket`) | Socket name (`-L`) or path (`-S`). `null`/empty/whitespace ⇒ default socket. Name vs path inferred from a `/` separator (see research R1). |

### Validation rules
- No save-time validation of server existence (Assumptions; consistent with `tmuxPath`).
- Trimmed empty ⇒ stored as `null` (UI converts blank → `null` on save).
- Any value is treated as literal data and shell-escaped at command-construction time (FR-005).

### Serialization
- `toJson`: add `'tmuxSocket': tmuxSocket`.
- `fromJson`: add `tmuxSocket: json['tmuxSocket'] as String?` — **absent key ⇒ `null`**, so
  existing persisted connections load unchanged (FR-006 / FR-008 backward compatibility).
- `copyWith`: add `String? tmuxSocket` param with `tmuxSocket ?? this.tmuxSocket` (same nullable
  pattern as `tmuxPath`; clearing happens via constructing a new `Connection` on save).

## Transport: `SshConnectOptions` (modified)

`lib/services/ssh/ssh_client.dart`. Gains `final String? tmuxSocket;` (const ctor param,
default unset), mirroring `tmuxPath`. Threaded in at every construction site:
`home_screen.dart`, `connections/widgets/connection_card.dart`,
`providers/notification_panes_provider.dart`, `connections/connection_form_screen.dart`
(test path), and `terminal/terminal_screen_logic.dart` (`_getAuthOptions`).

## Runtime: `SshClient` (modified)

- New field `String? _tmuxSocket;`, set in `connect()` from `options.tmuxSocket` (normalized:
  trimmed-empty ⇒ `null`).
- `_resolveTmuxCommand(command)` passes it through:
  `TmuxCommandResolver.resolve(command, _tmuxPath, tmuxSocket: _tmuxSocket)`.

## Pure logic: `TmuxCommandResolver.resolve` (modified)

Signature: `resolve(String command, String? tmuxPath, {String? tmuxSocket})`.

Socket-flag construction (pure, table-testable):

| `tmuxSocket` (trimmed) | emitted flag fragment |
|------------------------|-----------------------|
| `null` / `''`          | `''` (nothing)        |
| `fleet`                | ` -L fleet`           |
| `my sock`              | ` -L "my sock"`       |
| `/tmp/t.sock`          | ` -S /tmp/t.sock`     |
| `/tmp/a b.sock`        | ` -S "/tmp/a b.sock"` |

Each command-position `tmux` token → `<binary><flag> <rest>`, where `binary` is the quoted
`tmuxPath` or literal `tmux`. Command returned unchanged iff `tmuxPath == null` **and** flag is
empty.
