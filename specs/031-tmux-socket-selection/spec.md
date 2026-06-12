# Feature Specification: Per-Connection tmux Socket Selection

**Feature Branch**: `031-tmux-socket-selection`  
**Created**: 2026-06-12  
**Status**: Draft  
**Input**: User description: "Per-connection tmux socket selection. Add an optional per-connection tmux socket setting so the app can attach to non-default tmux sockets (e.g. the fleet socket `tmux -L fleet`). Socket may be specified by name (→ `tmux -L <name>`) or by path (→ `tmux -S <path>`). The socket flag must be applied as a global option immediately after the tmux binary on EVERY tmux invocation the app makes, including piped/chained command pipelines. Persisted per connection, surfaced in connection settings UI. Backward compatible when unset. Shell-escaped."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Attach to a named non-default socket (Priority: P1)

A user operates tmux sessions that live on a dedicated, non-default socket (for example, a `fleet` socket created with `tmux -L fleet`) so they survive editor/upgrade restarts. The app, talking only to the implicit default socket, cannot see those sessions. The user opens the connection's settings, enters the socket name `fleet`, saves, and reconnects. The session list now shows the sessions that live on the `fleet` socket, and all terminal operations target that socket.

**Why this priority**: This is the core problem the feature exists to solve. Without it the app is blind to any tmux server not on the default socket, which is the entire motivating use case.

**Independent Test**: Configure a connection with socket name `fleet` against a server that has sessions on the `fleet` socket; verify the session list shows those sessions (and not the default-socket sessions), and that opening one, sending keys, and viewing output all operate on the `fleet` socket.

**Acceptance Scenarios**:

1. **Given** a server with sessions on a non-default socket named `fleet` and a connection whose socket is set to `fleet`, **When** the user opens the session list, **Then** the sessions on the `fleet` socket are listed.
2. **Given** the same connection, **When** the user attaches to a session, sends keys, and views captured pane output, **Then** every one of those operations acts on the `fleet` socket's server.
3. **Given** a connection whose socket is left unset, **When** the user uses the app, **Then** behavior is identical to before this feature existed (the implicit default socket is used).

---

### User Story 2 - Attach to a socket by file path (Priority: P2)

A user whose tmux server listens on a socket at a specific filesystem path (rather than a name under the default socket directory) configures the connection by entering that path. The app targets the server at that socket path.

**Why this priority**: A real but less common alternative to the named-socket case; named sockets cover the primary motivating scenario, path-based sockets cover the remainder. Both map to the same persisted setting from the user's perspective.

**Independent Test**: Configure a connection with a socket path pointing at a running tmux server's socket file; verify the session list and all operations target that server.

**Acceptance Scenarios**:

1. **Given** a connection whose socket is set as a filesystem path, **When** the user opens the session list, **Then** the sessions on the server at that socket path are listed.
2. **Given** a connection with a socket path set, **When** any terminal operation runs, **Then** it targets the server at that socket path.

---

### User Story 3 - Change or clear the socket on an existing connection (Priority: P3)

A user who previously connected to the default socket edits an existing saved connection, sets (or later clears) the socket value, and saves. After reconnecting, the app reflects the new socket choice; clearing the value returns the connection to default-socket behavior.

**Why this priority**: Editing existing connections is expected behavior for a persisted per-connection setting; it must not require recreating the connection, but it is a refinement on top of the create-time capability in Stories 1 and 2.

**Independent Test**: Take an existing connection, set its socket to `fleet`, reconnect and confirm fleet sessions appear; clear the socket, reconnect, and confirm default-socket sessions appear again.

**Acceptance Scenarios**:

1. **Given** an existing connection with no socket set, **When** the user edits it to set a socket and saves, **Then** the next connection targets that socket.
2. **Given** an existing connection with a socket set, **When** the user clears the socket value and saves, **Then** the next connection targets the default socket exactly as before the feature.

---

### Edge Cases

- **Invalid / malformed socket name**: A socket name containing shell-significant characters or whitespace must not break or alter the command structure (it is treated as data and shell-escaped). The value is passed through to tmux verbatim; if tmux rejects it, the resulting tmux error is surfaced to the user as a normal connection/listing error rather than causing the app to send a malformed command.
- **No tmux server running on the chosen socket**: When the named or path socket has no server, listing sessions returns an empty result (or tmux's "no server" message), and the app shows an empty/normal "no sessions" state rather than crashing or silently falling back to the default socket.
- **Switching socket on a live/existing connection**: Changing the socket value takes effect on the next connection/refresh; the change is persisted and the prior socket is not retained.
- **Chained / piped command pipelines**: Operations that chain multiple tmux invocations in a single command line (notably the multi-line paste pipeline that uses load-buffer/paste-buffer) must apply the socket flag to **every** tmux invocation in the chain, not only the first. A pipeline where only the leading tmux token carries the socket would target two different servers and fail.
- **Whitespace-only or empty socket value**: Treated as "unset" (default-socket behavior); the app does not emit an empty `-L`/`-S` flag.
- **Name vs path supplied together**: The setting is a single socket choice; the user provides either a name or a path, not both (see Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A connection profile MUST support an optional socket setting that selects a non-default tmux socket, expressible either as a socket **name** or as a socket **file path**.
- **FR-002**: When a connection's socket setting is a name, the app MUST target that named socket (equivalent to `tmux -L <name>`); when it is a path, it MUST target that socket path (equivalent to `tmux -S <path>`).
- **FR-003**: The socket flag MUST be applied as a global option positioned immediately after the tmux binary, before the tmux subcommand, on **every** tmux invocation the app issues — including but not limited to listing sessions, attaching, capturing pane content, sending keys, and creating sessions.
- **FR-004**: In command lines that chain or pipe multiple tmux invocations (e.g. the multi-line paste pipeline), the socket flag MUST be applied to **every** command-position tmux token in the chain, not only the first.
- **FR-005**: The socket value MUST be shell-escaped wherever it is interpolated into a command string executed over the connection, so that names/paths containing shell-significant characters are treated as literal data.
- **FR-006**: The socket setting MUST be persisted as part of the connection profile so it survives app restarts and is restored when the connection is loaded.
- **FR-007**: The socket setting MUST be surfaced in the connection settings UI so users can set, view, edit, and clear it without recreating the connection.
- **FR-008**: When the socket setting is unset (absent, empty, or whitespace-only), every tmux invocation the app issues MUST be byte-for-byte identical to its current behavior (implicit default socket); no `-L`/`-S` flag is emitted.
- **FR-009**: Changing the socket value on an existing connection MUST take effect on the next connection/refresh and MUST NOT retain the previously configured socket.
- **FR-010**: When the chosen socket has no running tmux server, the app MUST present a normal empty/"no sessions" state (or surface tmux's message) and MUST NOT silently fall back to the default socket.
- **FR-011**: The socket setting MUST coexist with the existing per-connection tmux binary path setting: both the resolved binary path and the socket flag are applied together to every invocation (binary path first, then socket flag, then subcommand).

### Key Entities *(include if feature involves data)*

- **Connection profile**: The persisted per-connection configuration. Gains one optional attribute — the tmux socket selection (a name or a path, or unset). Relates to the existing tmux binary path attribute; both shape how tmux commands are constructed for that connection.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a connection's socket set to a named non-default socket that has active sessions, 100% of those sessions appear in the app's session list, and none of the default-socket sessions appear.
- **SC-002**: With a connection's socket set, attach, send-keys, and capture-pane operations all act on the chosen socket's server in 100% of cases (no operation silently uses the default socket).
- **SC-003**: With a connection's socket unset, every tmux command the app issues is identical to the pre-feature command for the same action (verifiable by command-string comparison), confirming zero behavior change for existing users.
- **SC-004**: In a command pipeline that chains N tmux invocations, all N carry the socket flag when a socket is set (0 unflagged tmux tokens).
- **SC-005**: A socket value containing shell-significant characters or spaces does not alter command structure (the value reaches tmux as a single literal argument) and never causes execution of unintended commands.
- **SC-006**: A user can set, change, and clear the socket on an existing connection through the settings UI and observe the corresponding change on the next connection, without recreating the connection.

## Assumptions

- **Single socket choice per connection**: A connection targets one socket at a time. The user supplies either a name or a path; the app does not combine both. How the two forms are distinguished (an explicit name-vs-path toggle, or inference from the presence of a path separator) is an implementation/planning detail, not a scope decision.
- **No validation of socket existence at save time**: The app does not pre-validate that a server exists on the chosen socket when the user saves; correctness is observed at connect/list time (consistent with how the existing tmux binary path is treated). Invalid values surface as normal tmux errors.
- **Scope is the tmux command-construction path plus settings storage/UI**: The feature changes how tmux commands are built and the connection-settings storage/UI. It does not change the SSH transport, host-key handling, or terminal rendering.
- **Default remains unset**: New and existing connections default to no socket (default-socket behavior); the feature is strictly opt-in per connection.
- **The known-good wrapper (`tmux-fleet`) is not a dependency**: A shell wrapper that pins `-L fleet` exists for manual validation only; the implemented feature must not depend on it.

## Dependencies

- Relies on the existing single choke point through which all tmux invocations are routed and rewritten (the command resolver that already rewrites command-position tmux tokens to an absolute binary path) as the natural injection point for the socket flag.
- Relies on the existing connection-profile persistence and connection-settings UI to store and surface the new setting.
- Relies on the existing shell-escaping utility used for interpolating values into SSH command strings.
