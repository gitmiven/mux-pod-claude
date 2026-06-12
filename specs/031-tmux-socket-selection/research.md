# Phase 0 Research: Per-Connection tmux Socket Selection

## R1 — How to distinguish a socket *name* from a socket *path*

**Decision**: Infer from the presence of a `/` path separator in the (trimmed) value.
- No `/` → socket **name** → `tmux -L <value>`
- Contains `/` → socket **path** → `tmux -S <value>`
- Empty / whitespace-only → **unset** (no flag emitted)

**Rationale**:
- Keeps the persisted model and the settings UI to a **single optional string** (no extra
  name-vs-path toggle/enum to store, migrate, or render). The spec explicitly leaves the
  distinction mechanism to planning (Assumptions: "an explicit name-vs-path toggle, or
  inference from the presence of a path separator").
- Matches the mental model of tmux users: `-L` takes a bare name living under the default
  socket dir; `-S` takes a filesystem path. A name with a `/` in it is not a valid `-L`
  name anyway, so the inference never misclassifies a legitimate name.
- Symmetric with the existing `tmuxPath` field, which is also a single free-text string.

**Alternatives considered**:
- *Explicit radio/segmented toggle (name | path)*: more UI, an extra persisted enum, and a
  migration concern, for no real user benefit — rejected.
- *Always `-L` (names only)*: drops the FR-002 path case (User Story 2) — rejected.

## R2 — Where to inject the socket flag

**Decision**: Inside `TmuxCommandResolver.resolve`, the single choke point through which every
tmux invocation already passes (it rewrites the command-position `tmux` token to the absolute
binary path, including tokens after `| & ; (` for piped/chained pipelines).

**Rationale**:
- FR-003 (every invocation) and FR-004 (every token in a chained pipeline) are satisfied
  automatically because `resolve` already uses `replaceAllMapped` over every command-position
  `tmux` token. The multi-line paste pipeline (`… | tmux load-buffer … && tmux paste-buffer …`)
  gets the flag on **both** tokens with no extra code.
- Position is correct by construction: each token becomes `<binary> <socketFlag> <subcommand …>`,
  satisfying FR-011 (binary first, then socket flag, then subcommand).

**Extension required**: today `resolve` returns the command unchanged when `tmuxPath == null`.
When a socket is set but the binary wasn't detected, we still want the flag. So `resolve` now:
- builds `binary = tmuxPath != null ? quote(tmuxPath) : 'tmux'`,
- builds `socketFlag` (`''`, ` -L <esc>`, or ` -S <esc>`),
- returns the command unchanged only when **both** `tmuxPath == null` **and** the socket flag is
  empty (preserving FR-008 byte-for-byte for the unset case).

## R3 — Shell escaping

**Decision**: Reuse `ShellEscape.quote` for the socket value (FR-005 / SC-005). Bare names
(`fleet`) pass through unquoted (no special chars); values with spaces/metacharacters are
double-quoted with `\\ " $ \`` escaped. No new escaping mechanism is introduced, consistent with
the constitution's "single shared mechanism" rule.

## R4 — Idempotent resolution (avoid a double `-L` flag)

**Observation**: `SshClient.execPersistent` resolves the command, then on the no-persistent-shell
fallback calls `exec(resolvedCommand)`, and `exec` resolves **again**.
- With an absolute `tmuxPath`, the second pass is a no-op (the rewritten `/usr/bin/tmux` token is
  preceded by `/`, so the `(^|[|&;(])tmux\b` pattern doesn't match) → already idempotent.
- With `tmuxPath == null` + a socket, the first pass yields a leading `tmux -L fleet …`; a second
  pass would match the leading `tmux` again and prepend a second `-L fleet`.

**Decision**: Change `execPersistent`'s fallback to pass the **raw** `command` to `exec()` (which
resolves exactly once), instead of the already-resolved string. Net behavior is identical for the
absolute-path case and correct for the literal-`tmux` case. tmux tolerates a repeated `-L` (last
wins), so this is a cleanliness/correctness fix, not a crash risk.

## R5 — Detection commands must stay on the default socket

`SshClient._detectTmuxPath` and the `test -x <path>` verification call `_client!.execute(...)`
**directly** (not through `_resolveTmuxCommand`), so they are unaffected by the socket — tmux
binary detection correctly probes the binary itself, not a specific server. `tmux -V` (version
probe) does go through the resolver and becomes `tmux -L fleet -V`, which prints the version
without needing a server — harmless.

## R6 — Manual-validation stop-gap (no app dependency)

The `~/.local/bin/tmux-fleet` wrapper (`exec /usr/bin/tmux -L fleet "$@"`) exists only to validate
expected behavior by setting the connection's **tmux path** to it. The implemented socket field
does **not** depend on it (FR / Assumptions). It remains useful as a cross-check during quickstart.
