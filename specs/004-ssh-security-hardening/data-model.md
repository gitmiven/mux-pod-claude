# Phase 1 — Data Model

## TrustedHostIdentity

A record that a particular server endpoint's host-key identity has been trusted (TOFU).

| Field | Type | Notes |
|-------|------|-------|
| `host` | `String` | Hostname or IP as configured on the `Connection`. |
| `port` | `int` | SSH port. `host:port` is the identity key (spec Assumption: per endpoint). |
| `fingerprint` | `String` | Human-comparable host-key fingerprint, `MD5:xx:xx:...` (D2). |
| `keyType` | `String` | Negotiated host-key algorithm, e.g. `ssh-ed25519`, `rsa-sha2-256`. |
| `firstTrustedAt` | `DateTime` | When the identity was first trusted (FR-008 display). |
| `lastVerifiedAt` | `DateTime` | Updated on each successful matching connection. |

- Immutable; `copyWith`; `toJson`/`fromJson` (ISO-8601 dates).
- `endpointKey` getter → `"$host:$port"`.
- One record per endpoint. Re-trust (FR-005) **replaces** the record (new fingerprint/keyType,
  `firstTrustedAt` reset to now, since it is a newly trusted identity).

## HostKeyFingerprint (value/formatter)

Not persisted; a small helper that converts the dartssh2 MD5 digest into the display/storage form.

| Member | Type | Notes |
|--------|------|-------|
| `formatMd5(Uint8List digest)` | `String` | → `MD5:` + lowercase hex joined by `:`. |

## HostKeyVerificationOutcome (enum)

Pure decision result, given `(stored?, presentedFingerprint)`:

- `firstUse` — no stored identity for the endpoint → trust on first use (commit after auth).
- `match` — presented == stored → proceed.
- `mismatch` — presented != stored → fail closed, surface to user.

## TrustedHostStore (abstraction)

Injectable persistence boundary (DIP), default backed by `shared_preferences`.

```
Future<TrustedHostIdentity?> get(String host, int port)
Future<List<TrustedHostIdentity>> getAll()
Future<void> save(TrustedHostIdentity identity)   // upsert by endpointKey
Future<void> remove(String host, int port)        // "forget" (FR-009)
```

Storage shape: one `shared_preferences` String key `trusted_host_identities` holding a JSON object
`{ "host:port": {…identity…}, … }`.

## SshState additions (provider)

New, nullable field describing a pending host-key change so the UI can prompt:

| Field | Type | Notes |
|-------|------|-------|
| `hostKeyChange` | `HostKeyChange?` | null normally; set on `SshHostKeyChangedError`. |

`HostKeyChange { String host; int port; String storedFingerprint; String presentedFingerprint; String keyType; }`

When set, the provider has stopped auto-reconnect and awaits the user's abort/re-trust decision.

## Errors

- `SshHostKeyChangedError(host, port, storedFingerprint, presentedFingerprint, keyType)` —
  thrown by `SshClient.connect` on mismatch (extends the existing typed-exception convention
  alongside `SshConnectionError` / `SshAuthenticationError`).

## Relationships

- `Connection` (existing) → relates to a `TrustedHostIdentity` by `host:port` (no FK stored on
  the connection; looked up at connect time). Forgetting an identity has no effect on the
  `Connection` itself.
