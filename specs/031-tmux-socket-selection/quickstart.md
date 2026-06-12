# Quickstart: Per-Connection tmux Socket Selection

## Goal

Make the app see tmux sessions that live on a non-default socket (e.g. the `fleet` socket
created with `tmux -L fleet`), which the app — talking only to the implicit default socket —
currently cannot list.

## Prerequisites

- A server reachable over SSH with sessions on a non-default socket, e.g.:
  ```bash
  tmux -L fleet new-session -d -s demo
  tmux -L fleet ls          # should show "demo"
  tmux ls                   # default socket — does NOT show "demo"
  ```

## Steps (named socket — the primary case)

1. Open the app → **Connections** → edit (or create) your connection.
2. In **TMUX SOCKET (OPTIONAL)** enter: `fleet`
3. Save and connect.
4. The session list now shows the **fleet** sessions (e.g. `demo`) and not the default-socket
   sessions.
5. Open a session: attach, send keys, and capture-pane all act on the `fleet` server.

## Steps (path socket)

- Instead of `fleet`, enter a path such as `/tmp/tmux-1000/fleet` (any value containing `/` is
  treated as a socket **path** → `tmux -S <path>`).

## Clearing / switching

- Edit the connection, blank the **TMUX SOCKET** field, save, reconnect → back to the default
  socket, identical to before the feature.

## Backward-compatibility check (SC-003)

- With the field left empty, every tmux command the app issues is unchanged. Existing saved
  connections (no `tmuxSocket` key in storage) load with the socket unset.

## Cross-check stop-gap (optional, no app change)

- Setting the connection's **tmux path** to `~/.local/bin/tmux-fleet` (a wrapper that pins
  `-L fleet`) produces the same session list as setting the socket to `fleet` — a useful
  independent confirmation that the socket field targets the right server.

## Automated gate

```bash
flutter analyze --no-fatal-infos   # exit 0
flutter test                       # all green, incl. new resolver + model round-trip tests
```
