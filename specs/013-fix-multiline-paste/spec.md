# Feature Specification: Fix silent multi-line command send (tmux path resolution)

**Feature Branch**: `013-fix-multiline-paste` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: Bug — the "enter command" panel accepts input but the command never reaches the terminal,
with no error shown.

## Root cause

The terminal sends multi-line input via tmux `load-buffer` + `paste-buffer` (PR #51):
`printf '%s' '<b64>' | base64 -d | tmux load-buffer -b '<n>' - && tmux paste-buffer -p -b '<n>' -t <t>`.

`SshClient._resolveTmuxCommand` rewrites the bare word `tmux` to the detected **absolute** tmux path
so the right binary is used — but its regex only matches `tmux` at the **start of the command or
after `;`** (`(^|;\s*)tmux\b`). In the paste pipeline the `tmux` tokens come **after `|` and `&&`**,
so they are left bare. In the app's non-interactive SSH shell, bare `tmux` resolves to whatever is
on `PATH` — which on a host with two tmux installs (e.g. user `~/.local/bin/tmux` 3.6a vs system
`/usr/bin/tmux` 3.4) is the **wrong version**, and a client/server version mismatch makes the command
fail (`server exited unexpectedly`). Single keystrokes work because `send-keys` starts with `tmux`
(so it *is* rewritten).

The failure is **invisible** because `_sendMultilineText` swallows it with `AppLog.d` (a no-op in
release builds) and the planned user-facing error was a `// TODO`.

## Requirements

- **FR-001**: `SshClient` MUST rewrite **every command-position** `tmux` token to the detected
  absolute path — not just the leading one — so piped/chained tmux commands (`| tmux`, `&& tmux`,
  `; tmux`, `(tmux`) all use the same binary.
- **FR-002**: The rewrite MUST NOT alter `tmux` occurring inside argument data (e.g. a base64 payload
  or a quoted literal) — only command-position tokens.
- **FR-003**: When a multi-line send fails after its retries, the app MUST show the user an error
  (not fail silently).
- **FR-004**: The path-resolution logic MUST be a pure, unit-testable function (it is currently a
  private method with no tests).

## Success Criteria

- **SC-001**: Unit tests prove `| tmux`, `&& tmux`, `; tmux`, `(tmux`, and leading `tmux` are all
  rewritten to the absolute path; `tmux` inside data is not.
- **SC-002**: The full `loadBufferAndPaste` command has **both** its `tmux` tokens rewritten.
- **SC-003**: A failed multi-line send surfaces a SnackBar.
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ 348 pass (+ new tests).

## Scope
In scope: extract + fix the tmux command resolver (`lib/services/ssh/`), wire it into `SshClient`,
add the failure SnackBar in `_sendMultilineText`. Out of scope: changing the paste mechanism itself,
or how `_detectTmuxPath` chooses the binary.

## Reproduction (verified on the affected host)
`tmux new-session` on the 3.6a server, then run the paste pipeline with the bare (3.4) tmux →
`server exited unexpectedly`, text not pasted. With the absolute 3.6a path for all tokens → pastes OK.
