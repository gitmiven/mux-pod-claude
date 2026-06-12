# Tasks: Per-Connection tmux Socket Selection

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)
Gate for every task group: `flutter analyze --no-fatal-infos` (exit 0) + `flutter test` (green).

## Phase A — Core: socket-flag injection (the change that delivers FR-003/004/005/008/011)

- [x] **T001** Extend `TmuxCommandResolver.resolve` to accept `{String? tmuxSocket}` and inject a
  `-L <name>` / `-S <path>` global flag (name-vs-path inferred from a `/`; value via
  `ShellEscape.quote`) on every command-position `tmux` token. Handle `tmuxPath == null` +
  socket-set (literal `tmux` binary). Return unchanged iff path null **and** flag empty.
  *(lib/services/ssh/tmux_command_resolver.dart)*
- [x] **T002** Extend `test/services/ssh/tmux_command_resolver_test.dart`: name → `-L`, path → `-S`,
  unset → unchanged, escaping of spaced name/path, **both** tokens of the real
  load-buffer/paste-buffer pipeline flagged, socket-with-null-path uses literal `tmux`,
  idempotent double-resolve produces a single flag.

## Phase B — Transport + runtime threading

- [x] **T003** Add `String? tmuxSocket` to `SshConnectOptions`; add `_tmuxSocket` to `SshClient`
  (set in `connect()`, normalized trimmed-empty→null); pass it in `_resolveTmuxCommand`.
  Change `execPersistent` fallbacks to pass the **raw** command to `exec()` (single resolution).
  *(lib/services/ssh/ssh_client.dart)*

## Phase C — Persistence (Connection model)

- [x] **T004** Add `Connection.tmuxSocket` (field, ctor, `copyWith`, `toJson`, `fromJson`).
  *(lib/providers/connection_provider.dart)*
- [x] **T005** NEW `test/providers/connection_socket_test.dart`: json round-trip with socket set,
  absent-key ⇒ null (backward compat), `copyWith` carries the value.

## Phase D — Wire the socket from the profile into every connect path

- [x] **T006** Pass `tmuxSocket: connection.tmuxSocket` into `SshConnectOptions` at:
  `home_screen.dart`, `connections/widgets/connection_card.dart`,
  `providers/notification_panes_provider.dart`, and `terminal/terminal_screen_logic.dart`
  (`_getAuthOptions`).

## Phase E — Settings UI (FR-007)

- [x] **T007** Add a **TMUX SOCKET (OPTIONAL)** text field to `connection_form_screen.dart`
  (controller init/load/dispose; field widget with hint "fleet  — or a /path  (default if empty)");
  populate from `connection.tmuxSocket` on edit; pass into the test-connect `SshConnectOptions`
  and the saved `Connection` (blank → null).

## Phase F — Close-out

- [x] **T008** Run the full gate; update CLAUDE.md "Recent Changes" with the 031 entry.
  (Do **not** merge/release — await user go-ahead per release cadence.)

## Parallelism notes

- T001+T002 (Phase A) are the critical core and can land first/independently.
- T004/T005 (model) are independent of Phase A.
- Phase D (T006) depends on T003 (options field) + T004 (model field).
- T007 depends on T003 + T004.
