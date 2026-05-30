# Phase 0 — Research & Decisions

## D1. Host-key hook in dartssh2

**Decision**: Use `SSHClient(onVerifyHostKey: ...)`.

**Findings** (dartssh2 2.13.0 source):
- `typedef SSHHostkeyVerifyHandler = FutureOr<bool> Function(String type, Uint8List fingerprint)`.
- The transport computes `fingerprint = MD5Digest().process(hostkey)` and calls the handler
  *after* it has cryptographically verified the host key's signature against the exchange hash
  (`_verifyHostkey(...)`), and *before* `SSH_MSG_NEWKEYS` / authentication. Returning `false`
  → `closeWithError(SSHHostkeyError('Hostkey verification failed'))`.
- `type` is the negotiated host-key algorithm name (e.g. `ssh-ed25519`, `rsa-sha2-256`,
  `ecdsa-sha2-nistp256`). `FutureOr<bool>` means the callback may be async (we can read
  persisted trust inside it).

**Consequence**: The fingerprint we receive is the **MD5** digest of the host key. The raw key
bytes are not surfaced to the callback, so we cannot compute SHA256 there.

**Rejected alternatives**:
- *Patch/fork dartssh2 to expose the raw key for SHA256*: violates KISS; adds a maintenance fork.
- *`disableHostkeyVerification: true` + manual*: would also disable the protocol signature check
  — strictly worse. We keep it `false`.

## D2. Fingerprint format

**Decision**: Store/compare/display the OpenSSH **legacy MD5** representation:
`MD5:` + lowercase hex bytes joined by `:` (e.g. `MD5:16:27:ac:...`), paired with the key type.

**Rationale**: It is exactly what dartssh2 surfaces, it is a standard OpenSSH format
(`ssh-keygen -l -E md5`) so it is comparable out-of-band, and TOFU only needs a stable,
collision-detecting identity. MD5 second-preimage resistance (≈2^123) still holds; an attacker
would additionally need a key whose signature validates with a private key they control — the
protocol signature check (D1) already blocks simple key substitution.

**Note**: Modern OpenSSH defaults to SHA256 fingerprints. Documented limitation: users verifying
out-of-band should use `ssh-keygen -l -E md5`. A future enhancement could surface SHA256 if a
newer dartssh2 exposes the raw key.

**Rejected**: SHA256-only display — impossible without the raw key (D1).

## D3. When is trust committed?

**Decision**: On **first use**, the verifier records the presented identity as *pending* and
returns `true`; `SshClient.connect` commits it to the store **only after `authenticated`
completes successfully**. On a **match**, `lastVerifiedAt` is refreshed after auth success.

**Rationale**: FR-001 says "first *successful* connection." Committing inside the callback (pre-
auth) would let an unauthenticated peer (right key exchange, no credentials) poison the trust
store, which would then make the *legitimate* server look like a mismatch later. Tying the
commit to auth success closes that hole.

**Rejected**: commit inside the callback — simpler but poisons trust on failed auth.

## D4. Mismatch surfacing without UI in the transport callback

**Decision**: On mismatch the callback returns `false` (handshake aborts). `SshClient.connect`
detects the resulting `SSHHostkeyError` together with the stashed mismatch info and rethrows a
typed **`SshHostKeyChangedError(host, port, storedFingerprint, presentedFingerprint)`**. The
provider catches it, exposes the fingerprints in `SshState`, and (critically) does **not**
schedule another reconnect. The UI shows a warning dialog; on explicit re-trust the provider
re-runs connect with `trustNewHostKey: true`, which makes the verifier replace the stored
identity and return `true`.

**Rationale**: Keeps all UI out of the transport layer; satisfies "abort before credentials are
sent" (scenario 3, since the callback fires before auth); satisfies "no silent re-trust on
auto-reconnect, no loop" (edge case) by stopping the reconnect cycle on this specific error.

**Rejected**: showing a dialog from inside `onVerifyHostKey` via a completer — couples services to
UI, fights Riverpod/`BuildContext` lifecycle, and risks deadlock during the handshake.

## D5. Persistence for trusted identities

**Decision**: `shared_preferences`, dedicated key `trusted_host_identities`, JSON map of
`"host:port" → TrustedHostIdentity`. Injected behind a `TrustedHostStore` abstraction.

**Rationale**: Fingerprints are public, not secrets, so `flutter_secure_storage` is unnecessary
(and its Keystore round-trips are slower). FR-010 ("persist across restarts; not exposed in
plaintext logs; not shared/exported with other data unintentionally") is met by a dedicated
namespace separate from the connection list, plus never logging fingerprints. The abstraction
keeps it swappable and unit-testable via `SharedPreferences.setMockInitialValues`.

**Rejected**: storing fingerprints alongside `Connection` JSON — would entangle public host-key
data with connection export/import and complicate "forget."

## D6. Identity scope (per assumptions)

**Decision**: Key by `host:port`. Different ports = distinct endpoints. Matches spec Assumption.

## D7. Command-injection: reuse vs. rewrite the escaper

**Decision**: Extract the existing, proven selective double-quote escaper from
`TmuxCommands._escapeArg` into a public `ShellEscape.quote(String)` (the single shared mechanism,
FR-013), add an empty-string → `""` guard, and have `_escapeArg` delegate to it. Fix the one
unescaped site (`ssh_client.dart` `test -x ${tmuxPath}`) to use `ShellEscape.quote`, and escape
the resolved tmux path during command substitution.

**Rationale**: The current escaper already wraps in double quotes and escapes `\ " $ \``, which
neutralizes every character the spec enumerates (`spaces ' " ; | & $ $() backticks < > newlines`)
because they are inert inside double quotes. Reusing it keeps **all ~30 existing
`tmux_commands_test` assertions green** (no `"my session"` → `'my session'` churn) — protecting
SC-006 — while still centralizing the logic.

**Rejected**: switching to always-single-quote POSIX escaping (`'...'\''...'`). It is the textbook
"most provably safe" form, but it changes every command's output (`-t %0` → `-t '%0'`), breaking
the entire existing test suite for zero security gain over the double-quote form here.

**SFTP note**: `sftp_service.dart` uses the dartssh2 SFTP *protocol* (`sftp.open/mkdir/stat/remove`)
— paths travel as protocol fields, not through a shell. There is no shell-injection surface, so no
escaping change is required there (confirmed by reading the file). `sanitizeFilename` (for
generated upload names) is retained as-is.

## D8. Backward compatibility of `SshClient.connect`

**Decision**: Add `HostKeyVerifier? hostKeyVerifier` and `bool trustNewHostKey = false` as
*optional* params. When `hostKeyVerifier` is null (existing tests, non-app callers), behavior is
unchanged (accept). The app always injects a verifier via the provider, so SC-001/003 (fail-closed
for 100% of app connections) hold without breaking other call sites.
