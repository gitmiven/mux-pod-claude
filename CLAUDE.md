# MuxPod

A Flutter app for browsing and operating tmux sessions, windows, and panes on a remote server over SSH, from an Android smartphone. Optimized for Claude Code.

## Key Features

- Direct SSH connection (the server only needs sshd running)
- Navigation of tmux sessions / windows / panes
- ANSI color-capable terminal display
- Special key input (ESC / CTRL / ALT, etc.)
- Notification rules (notify on pattern match)
- SSH key management (flutter_secure_storage support)
- Deep links (jump directly from external apps via the muxpod:// URL scheme)
- Foldable device support

## Tech Stack

- Flutter 3.24+ / Dart 3.x
- flutter_riverpod (state management)
- dartssh2 (SSH connection)
- xterm (terminal display)
- flutter_secure_storage (secure storage)
- shared_preferences (settings persistence)

## Development Commands

```bash
flutter run             # Run in development
flutter run -d android  # Android device/emulator
flutter analyze         # Static analysis
flutter test            # Run tests
flutter build apk       # Build APK
```

## Documentation

- @/docs/tmux-mobile-design-v2.md - Detailed design document
- @/docs/coding-conventions.md - Coding conventions
- @/docs/ui-guidelines.md - UI/UX guidelines
- @/docs/screens/ - Screen designs
- @/docs/logo/logo.svg - Logo

## Directory Structure

```
muxpod/
├── lib/
│   ├── main.dart           # Entry point
│   ├── providers/          # Riverpod providers
│   ├── screens/            # Screens
│   │   ├── connections/    # Connection management
│   │   ├── terminal/       # Terminal
│   │   ├── keys/           # SSH key management
│   │   ├── notifications/  # Notification rules
│   │   └── settings/       # Settings
│   ├── services/           # Business logic
│   │   ├── ssh/            # SSH connection
│   │   ├── tmux/           # tmux operations
│   │   ├── terminal/       # Terminal control
│   │   ├── keychain/       # Key management
│   │   └── notification/   # Notification engine
│   ├── theme/              # Theme / design
│   └── widgets/            # Shared widgets
├── android/                # Android native config
├── ios/                    # iOS native config
└── test/                   # Tests
```

## Core Types

```dart
class Connection {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final AuthMethod authMethod;
}

class TmuxSession {
  final String name;
  final List<TmuxWindow> windows;
}

class TmuxWindow {
  final int index;
  final String name;
  final List<TmuxPane> panes;
}

class TmuxPane {
  final int index;
  final String id;
  final bool active;
}
```

## Security

- SSH keys: flutter_secure_storage (encrypted)
- Passwords: flutter_secure_storage (encrypted)
- Biometric authentication support (local_auth)

## Active Technologies

- Dart 3.10+ / Flutter 3.24+ + dartssh2 (SSH), xterm (terminal display), flutter_riverpod (state management)
- flutter_secure_storage (SSH keys/passwords), shared_preferences (connection settings)
- cryptography, pointycastle (SSH key generation)
- flutter_local_notifications, url_launcher (settings/notifications)
- Dart 3.x / Flutter 3.24+ + flutter_riverpod (state management), xterm (terminal display), dartssh2 (SSH connection) (001-terminal-width-resize)

## Recent Changes

- 007-decompose-terminal-screen: Began breaking up the `terminal_screen.dart` god-widget — extracted 7 self-contained helper classes (painters, dialogs, pane-layout visualizer) into `lib/screens/terminal/widgets/` (4,527 → 3,291 lines); behavior-identical. Controller extraction from `_TerminalScreenState` to follow.
- 006-pr-validation-ci: GitHub Actions CI (`flutter analyze` + `flutter test`) on PRs/main, Flutter pinned; made the suite green (bundled JetBrains Mono for tests, fixed a set-state-after-dispose bug)
- 005-translate-japanese-comments: Translated in-code comments to English across the codebase
- 004-ssh-security-hardening: SSH host-key verification (TOFU via dartssh2 `onVerifyHostKey`, stored per `host:port` in `lib/services/ssh/trusted_host_store.dart`, fail-closed mismatch with re-trust/forget UI) and centralized command-injection escaping (`lib/services/shell/shell_escape.dart`, used by `TmuxCommands` and the tmux-path checks)
- 001-ssh-terminal-integration: Implemented SSH connection, tmux attach, and key sending
- 003-ssh-key-management: Ed25519/RSA key generation, import, and management features
- 001-settings-notifications: Settings screen, notification rule CRUD, theme switching

---

## Fleet Commander — Decision Protocol

This workspace is registered with the Fleet Commander hub as `mux-pod-claude`. When you are blocked, need a decision, or are about to make a significant architectural choice:

**STOP. Do not ask a question in chat. Generate a DECISION_MEMO instead.**

### Session Kickstart

At the start of each session, before acting on the user's first instruction:

1. Read `progress.md`. If it doesn't exist, run `/progress` to bootstrap it from the project structure, then re-read.
2. Identify the **active phase** — the lowest-numbered phase that is not at 100% (`✅`).
3. From `README.md` and the active phase's name, identify the next unfinished item in that phase.
4. State in one line what you're about to resume: `Resuming phase {N} — {phase name}. Next: {specific task}.`
5. Then wait for the user to confirm, redirect, or give the green light before starting work.

If `progress.md` is empty, contradicts the visible project state, or there is no obvious next item — that's a DECISION_MEMO trigger. Do NOT silently guess.

### Format

```
DECISION_MEMO
=============
Current state: <one sentence — what was just completed>
Blocker: <one sentence — what is preventing progress>

Options:
1. <action> — Pro: <benefit> | Con: <risk>
2. <action> — Pro: <benefit> | Con: <risk>
3. <action> — Pro: <benefit> | Con: <risk>
```

### Trigger conditions

- A test fails and you have tried at least one fix
- An ambiguity in requirements could lead to two meaningfully different implementations
- You need a secret, credential, or environment value you don't have
- You are about to delete or overwrite existing logic and are unsure
- You have completed a unit of work and the next step is unclear

### How to send

```python
import sys
sys.path.insert(0, "agent")
from hook import FleetCommander

fc = FleetCommander()  # reads FLEET_HUB_URL / FLEET_API_KEY / FLEET_PROJECT_ID from env
option, note = fc.ask_commander(
    issue="<blocker in one sentence>",
    context="<relevant logs, file excerpts, traceback>",
    options=[
        "<option 1>",
        "<option 2>",
        "<option 3>",
    ],
)
```

`ask_commander()` blocks until the commander resolves the memo (instant via webhook, with poll fallback). Do NOT continue coding until you receive a response. If you fix the blocker yourself before getting an answer, call `fc.cancel(decision_id)`.

### What NOT to memo

- Formatting choices, variable names, minor style decisions — use your best judgement
- Errors you are confident you can fix — try first, memo only if stuck after 2 attempts

### Env wiring

Hook env vars (`FLEET_HUB_URL`, `FLEET_API_KEY`, `FLEET_PROJECT_ID`) live in `.env` and must be **exported** into the shell running Claude. Use `bash start-dev.sh` from this directory — it launches tmux sessions with the vars wired in. If the vars aren't exported, `hook.py` falls back to bad defaults and memos go nowhere silently.
