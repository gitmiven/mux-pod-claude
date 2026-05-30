# Feature Specification: SSH Security Hardening (Host-Key Verification & Command-Injection Prevention)

**Feature Branch**: `004-ssh-security-hardening`
**Created**: 2026-05-30
**Status**: Draft
**Input**: User description: "SSH security hardening (next phase): (1) SSH host-key verification with trust-on-first-use; (2) shell command-injection prevention for all user-derived values entering shell/tmux commands. Must not break existing connect/reconnect/keep-alive/deep-link/SFTP flows. Test-first. Out of scope: changing auth methods, server-side changes."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Detect a changed/forged server identity (Priority: P1)

A user connects to a remote server they have used before. Unknown to them, the server they are reaching has changed identity (a key rotation, a rebuilt host, or an attacker intercepting the connection). The app recognizes that the server's identity no longer matches what was trusted previously and refuses to connect silently, warning the user that the server identity changed and that this could indicate interception. The user must explicitly decide whether to trust the new identity before any session data or credentials are exchanged.

**Why this priority**: This is the core protection. Without it, the app can be silently man-in-the-middled, exposing credentials and session contents. It is the single highest-value security outcome of this phase.

**Independent Test**: Connect once to establish a trusted identity, then connect again presenting a different server identity; verify the app blocks the silent connection, shows a clear warning, and only proceeds after explicit user re-trust. Delivers value on its own.

**Acceptance Scenarios**:

1. **Given** a host whose identity was trusted on a previous connection, **When** the user connects and the presented identity matches the stored one, **Then** the connection proceeds normally with no extra prompts.
2. **Given** a host whose identity was trusted previously, **When** the user connects and the presented identity does NOT match the stored one, **Then** the app does not complete the connection automatically, presents a clear warning that the host identity changed (including the old and new fingerprints), and offers the choice to abort or to explicitly re-trust.
3. **Given** the mismatch warning, **When** the user chooses to abort, **Then** no session is established and no credentials are sent beyond what is required to read the host identity.
4. **Given** the mismatch warning, **When** the user explicitly chooses to re-trust, **Then** the stored identity is replaced with the new one and the connection proceeds.

### User Story 2 - Establish trust on first connection (Priority: P1)

A user adds a new server and connects for the first time. The app has no prior record of that server's identity. The app records the server's identity as trusted so future connections can be verified against it, and makes that identity visible to the user so they can verify it out-of-band if they wish.

**Why this priority**: TOFU only works if the first connection reliably captures and stores the identity. Without this, Story 1 has nothing to compare against. It is the necessary foundation and ships together with Story 1.

**Independent Test**: Connect to a never-before-seen host; verify the identity is captured, stored, and subsequently shown as the trusted identity for that host.

**Acceptance Scenarios**:

1. **Given** a host with no stored identity, **When** the user connects, **Then** the connection proceeds and the presented identity is recorded as the trusted identity for that host.
2. **Given** a first connection has completed, **When** the user views the host/connection details, **Then** the trusted identity (a human-readable fingerprint) is displayed.

### User Story 3 - Manage trusted server identities (Priority: P2)

A user wants to review or reset which server identities the app trusts — for example after a legitimate server rebuild, or to clear a stale record. The user can view a host's trusted fingerprint and forget/reset it so the next connection re-establishes trust.

**Why this priority**: Needed for real-world operation (legitimate key changes happen) and to recover from an accidental re-trust, but the app is already safer once Stories 1–2 exist, so this can follow.

**Independent Test**: For a host with a stored identity, view its fingerprint, choose "forget," and verify the next connection is treated as a first connection (Story 2).

**Acceptance Scenarios**:

1. **Given** a host with a stored trusted identity, **When** the user opens its details, **Then** the fingerprint and the date it was first trusted are shown.
2. **Given** a host with a stored trusted identity, **When** the user chooses to forget it and confirms, **Then** the stored identity is removed and the next connection re-establishes trust on first use.

### User Story 4 - Use unusual names and paths safely (Priority: P2)

A user works with tmux sessions, windows, or files whose names contain spaces, quotes, or shell-meaningful characters (e.g. a session named `my project` or a file named `report;backup`). The app operates on these correctly and never lets such characters cause unintended commands to run on the server.

**Why this priority**: Prevents command injection and also fixes correctness bugs for legitimate names with special characters. Invisible when benign, critical when abused; pairs naturally with the host-key work as the second half of "security hardening."

**Independent Test**: Drive operations (select/rename/navigate/send-keys/file operations) using names and paths containing spaces, quotes, `;`, `$()`, backticks, and newlines; verify the intended operation succeeds and no extra/unintended command executes.

**Acceptance Scenarios**:

1. **Given** a tmux session or window whose name contains spaces or quotes, **When** the user selects or operates on it, **Then** the operation targets exactly that session/window and nothing else.
2. **Given** a file or directory whose name contains shell-meaningful characters, **When** the user performs a file operation on it, **Then** only that file/directory is affected and no injected command runs.
3. **Given** any user-provided value used to locate a program or target on the server (including a custom path to the terminal-multiplexer binary), **When** it contains shell-meaningful characters, **Then** it is treated as literal data and cannot execute additional commands.

### Edge Cases

- **First connection captures no identity**: if the server identity cannot be read, the connection MUST fail closed (do not proceed as if trusted).
- **Same host, different port**: identities are tracked per host endpoint; a different port is treated as a distinct endpoint unless an explicit policy says otherwise (see Assumptions).
- **Concurrent/automatic reconnect**: an automatic reconnect to a host whose identity changed MUST be subject to the same verification and MUST NOT silently re-trust; it surfaces the same warning rather than looping.
- **Deep-link launch**: a connection initiated by an external deep link is subject to identical verification before any session is attached.
- **Forgotten then reconnected**: after a user forgets an identity, the next connection is a clean first-use.
- **Empty/degenerate names**: empty or whitespace-only session/window/file names are handled without error and without breaking command construction.
- **Very long or multi-line input**: names/paths containing newlines or unusually long content are handled as literal data.
- **No secret leakage**: warnings, errors, and any diagnostic output never reveal passwords, passphrases, or private keys.

## Requirements *(mandatory)*

### Functional Requirements

**Host-key verification (TOFU)**

- **FR-001**: On the first successful connection to a host endpoint with no stored identity, the system MUST record the server's identity (as a fingerprint) as trusted for that endpoint.
- **FR-002**: On every subsequent connection, the system MUST compare the presented server identity against the stored trusted identity before establishing a usable session.
- **FR-003**: When the presented identity matches the stored identity, the system MUST proceed without additional prompts.
- **FR-004**: When the presented identity does NOT match the stored identity, the system MUST NOT establish the session automatically; it MUST warn the user that the host identity changed, showing both the previously trusted fingerprint and the newly presented fingerprint.
- **FR-005**: After a mismatch warning, users MUST be able to either abort (no session established) or explicitly re-trust the new identity (which replaces the stored identity and proceeds).
- **FR-006**: If the server identity cannot be determined, the system MUST fail closed (refuse the connection) rather than proceed unverified.
- **FR-007**: Automatic reconnection and deep-link-initiated connections MUST be subject to the same verification rules as a manual connection.
- **FR-008**: Users MUST be able to view the trusted fingerprint (and the date first trusted) for a host/connection.
- **FR-009**: Users MUST be able to forget/reset a host's trusted identity, after which the next connection is treated as a first connection.
- **FR-010**: Stored trusted identities MUST persist across app restarts and MUST be stored such that they are not exposed in plaintext logs or shared/exported with other data unintentionally.

**Command-injection prevention**

- **FR-011**: All user-derived values that flow into commands executed on the server (including but not limited to session names, window names, pane identifiers, sent key sequences, file and directory paths, and any user-specified path to the terminal-multiplexer binary) MUST be treated as literal data and MUST NOT be able to cause additional or altered commands to execute.
- **FR-012**: Values containing shell-meaningful characters (spaces, single and double quotes, `;`, `|`, `&`, `$`, `$()`, backticks, `<`, `>`, newlines) MUST be handled correctly so that the intended operation still targets exactly the intended object.
- **FR-013**: The system MUST route command construction through a single, shared mechanism responsible for safe encoding of user-derived values, so the protection is consistent and centrally testable.

**Compatibility & safety**

- **FR-014**: The feature MUST NOT break existing flows: manual connect, automatic reconnect (including backoff and offline pause/resume), keep-alive/disconnect detection, deep-link navigation, and file browsing/transfer.
- **FR-015**: No security-relevant warning, error, or diagnostic output may include passwords, passphrases, or private key material.

### Key Entities *(include if feature involves data)*

- **Trusted Host Identity**: a record that a particular server endpoint's identity has been trusted. Key attributes: the host endpoint it applies to, a human-readable fingerprint of the server identity, the identity/key type, the date first trusted, and the date last verified. One record per host endpoint; referenced when any connection to that endpoint is attempted.
- **Connection** (existing): a saved server the user connects to. Relates to a Trusted Host Identity via its host endpoint.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of connections (manual, automatic reconnect, and deep-link) verify the server identity before a session is attached; none attach a session on an unverified or mismatched identity without explicit user re-trust.
- **SC-002**: A connection to a host whose identity differs from the stored one is never completed silently — the user is always warned and must explicitly choose, in 100% of mismatch cases.
- **SC-003**: When the server identity cannot be read, the connection fails closed in 100% of cases (no unverified sessions).
- **SC-004**: 100% of user-derived values containing the tested shell-meaningful characters (spaces, quotes, `;`, `$()`, backticks, newlines) result in the intended operation only, with zero unintended command execution, as demonstrated by automated tests.
- **SC-005**: Operations on tmux sessions/windows and files whose names contain spaces or quotes succeed (correctness), measured by automated tests covering representative names.
- **SC-006**: No regression in existing connect/reconnect/keep-alive/deep-link/SFTP behavior, demonstrated by the existing test suite continuing to pass plus new tests for this feature.
- **SC-007**: A user can view and forget a host's trusted identity, and a forgotten identity is re-established on the next connection, verified end-to-end.

## Assumptions

- **First-use policy**: Trust is established automatically on first connection (silent trust-on-first-use), with the fingerprint made viewable afterward, rather than prompting on every first connection. Rationale: least friction, matches common SSH-client TOFU behavior, and preserves the app's current first-connect experience. (A future enhancement could add an optional "confirm on first use" strict mode.)
- **Identity scope**: Trusted identities are keyed by host endpoint (host + port). Connections sharing the same endpoint share the trusted identity.
- **Mismatch override**: Users are allowed to explicitly re-trust a changed identity (the app does not hard-block forever), because legitimate key rotations and server rebuilds occur.
- **Fingerprint format**: The fingerprint shown to users is a standard, human-comparable representation suitable for out-of-band verification.
- **Out of scope**: No changes to authentication methods (password/key) themselves; no server-side changes; no enterprise key-distribution/CA trust model (plain TOFU only this phase).
