# Quickstart — Exercising SSH Security Hardening

Prereqs: `mise install` (Flutter 3.38.6-stable), `flutter pub get`.

## Run the gate

```bash
flutter analyze        # zero errors/warnings
flutter test           # new unit tests green; pre-existing google_fonts network failures unrelated
dart format --set-exit-if-changed lib test
```

## Unit tests (no server needed)

```bash
flutter test test/services/shell/shell_escape_test.dart
flutter test test/services/ssh/host_key_fingerprint_test.dart
flutter test test/services/ssh/trusted_host_identity_test.dart
flutter test test/services/ssh/trusted_host_store_test.dart
flutter test test/services/ssh/host_key_verifier_test.dart
flutter test test/services/tmux/tmux_commands_test.dart
```

## Manual: host-key verification (TOFU)

1. **First use** — Add a connection and connect. The connection succeeds; open the connection's
   detail/edit screen → a "Server identity" section shows the trusted fingerprint (`MD5:…`),
   key type, and the date first trusted.
2. **Match** — Reconnect to the same server. No extra prompt; it connects normally.
3. **Mismatch** — Point the connection at a host presenting a *different* key (e.g. rebuild the
   server / change `HostKey`, or repoint host/port to another sshd). Connecting now shows the
   **Host identity changed** warning with the old and new fingerprints, and an Abort / Re-trust
   choice. Abort → no session. Re-trust → stored fingerprint is replaced and it connects.
4. **Reconnect/deep-link** — Trigger an auto-reconnect (drop the network) or launch via a
   `muxpod://` deep link against a changed key: the same warning appears; it must NOT silently
   re-trust or loop.
5. **Forget** — In the connection detail screen, tap "Forget host identity" → next connection is a
   clean first-use (step 1 again).

## Manual: command-injection safety

1. Create a tmux session named `my project` (space) and another `report;backup` (semicolon).
2. Select / rename / send keys / navigate to them in the app — each operation targets exactly that
   object; nothing extra runs.
3. In the connection's advanced settings, set a custom tmux path containing shell metacharacters
   (e.g. `x; touch /tmp/pwned`). Verify no file `/tmp/pwned` is created on the server (the value is
   treated as literal data; detection simply fails to find a binary at that path).
