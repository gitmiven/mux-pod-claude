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
- 026-more-file-viewers: Extended the file viewer for more types. **In-app**: `.csv` → a scrollable table (`csv` pkg), `.zip` → a listing of its entries (`archive` pkg). **External "Open with…"**: `.html/.mp4/.webm/.xls/.doc` (and any `external`-mapped ext) download to a temp file (streamed via `SftpBrowserService.downloadToFile`, 100 MiB cap) and open in the device's system app (`open_filex` + `path_provider`) — legacy Office/video aren't renderable in-app. Added FileViewerType `csv`/`archive`/`external` (+ defaults); Settings type picker is now a dropdown. +8 tests (suite 442). New deps: csv, archive, open_filex, path_provider.
- 025-claude-history: The recent-commands picker now reads **Claude Code's own prompt history** (`~/.claude/history.jsonl`, where `project` == the working directory) over the existing SSH connection, scoped to the active pane's project, most-recent first + deduped — so it captures live/Direct-Input-typed prompts accurately. Falls back to the app-recorded history (023) when the file is absent/empty/unreadable or disconnected. Pure `parseClaudeHistory` + bounded `tail` read (`ClaudeHistoryReader`); the shared picker gained a loading state + async loader. +7 tests (suite 434).
- 024-arrow-layout-history: Re-laid the special-keys bars and added a bar history button. The **Up** arrow moved into the modifier row at **column 2**; the arrow row became **Left/Down/Right** on the same 10-column grid so **Down sits exactly under Up** (verified by a widget test comparing x-centres), with column 4 reserved. A **history button** on the bottom bar opens the same recent-commands picker as the popup (extracted to a shared `recent_commands_sheet.dart`, reusing 023's `commandHistoryProvider`) and sends the chosen command. +5 tests (suite 427).
- 023-command-history: Replaced the "Enter Command" popup's top-right "Shift+Enter" badge with a **history button** that opens a list of unique recently-sent commands (most-recent first); tapping one sends it (reusing the popup's send path, so 022 clear-then-send applies). New persisted, deduped, recency-ordered store: pure `addCommandToHistory` + `commandHistoryProvider` (JSON in prefs, cap 50); each successful send is recorded. +9 tests (suite 422).
- 022-prefill-command: Added a configurable option (Settings → Terminal → "Pre-fill command box", default off) to start the "Enter Command" popup with the current terminal input line instead of empty. Pure `InputLineExtractor` strips ANSI + a Claude input-box (`│ > `) or shell prompt (`$`/`#`/`>`), falling back to the raw line; the prefill comes from the cursor row of the captured pane. When pre-filled, Send first clears the terminal line (`C-u`, `C-a C-k`) so the command isn't duplicated. +8 tests; also raised a brittle settings-scroll test helper's reach (suite 413).
- 021-full-width-bg: Fixed full-screen TUI apps (mc, htop, vim) rendering mostly black instead of their solid background. The custom renderer never filled a line's background past the last glyph, so mc's blue showed only behind text. Added `AnsiParser.lineFillColor` (the background active at a line's end — `parseLines` already carries it across lines) and made `AnsiTextView` wrap each line in a full-width `ColoredBox`. Default-bg output (shell, which resets before newline) is unchanged. +4 parser tests (suite 405).
- 020-command-enter-send: Fixed Enter-to-send in the "Enter Command" panel on the phone soft keyboard. It worked only via a hardware key handler, and the field used `textInputAction.newline`, so on-screen Enter inserted a newline and never sent. Switched the field to `TextInputAction.send` + `onSubmitted` (keyboardType text; `maxLines: null` still grows for pasted multi-line; hardware Enter/Shift+Enter and the IME-composing guard unchanged). +2 tests incl. a soft-keyboard regression via `testTextInput.receiveAction` (suite 395 on this branch).
- 019-markdown-images: The in-app Markdown viewer now renders embedded images. A custom flutter_markdown_plus `imageBuilder` resolves a relative `![](src)` against the .md file's directory (absolute kept as-is, POSIX, percent-decoded) and fetches it over SFTP (size-capped) via a `_SftpImage` widget with loading/broken-image placeholders; `http(s)` loads over the network and `data:` URIs render inline. Pure resolver `resolveRemoteImagePath` (lib/services/viewer/markdown_image.dart). +6 tests (suite 399).
- 018-file-browser-start-dir: Made the file browser's start directory configurable (Settings → File browser → "Open at"): keep today's behaviour (the "Claude Code folder" = the pane CWD) or open at the **last visited** folder. The browser now remembers its directory **per connection** (`LastPathStore`, persisted JSON) on each navigation; `initialize(connectionId, paneId)` builds an ordered candidate chain (`startPathCandidates`) — last-visited (if that mode) → pane CWD → home — using the first that loads. Default `claudeCodeFolder` (no change unless opted in). +11 tests (suite 393).
- 017-open-in-terminal-viewer: Added a 4th file-action-menu item ("Open with <viewer>", between the name/path header and Rename) that opens a file in an **in-app** viewer — images in a zoomable Image view, .md via flutter_markdown_plus, text in a selectable monospace view (fetched over SFTP, size-capped at 5 MiB; nothing sent to the terminal). The extension→viewer-type map (`image`/`markdown`/`text`) is configurable in Settings ("File viewers" section) and persisted as JSON, with defaults (images→Image, md→Markdown, txt/log→Text). New `FileViewerType` + `FileViewerScreen`; `SftpBrowserService.readFileBytes`. Note: an earlier draft used terminal tools (timg/glow) in the pane — the user corrected this to in-app viewers. +14 tests (suite 382).
- 016-session-dropdown-order: The in-session "switch session" dropdown (top of the terminal) now orders sessions most-recently-active first, matching the startup list's "recent" feel (was tmux's natural alphabetical/creation order). The in-session fetch (`list-panes -a`) and `TmuxSession` carried no timestamp, so the fix is end-to-end: append `#{session_activity}` to the format, parse it into a new `TmuxSession.lastActivity`, and sort the dropdown with a pure `byRecencyDesc` comparator (null/unknown → bottom, ties → name). Ordering-only; startup list, selection/attach, windows/panes unchanged. +5 tests (suite 368).
- 015-function-key-bar: Added a third, data-driven "variable" key bar above the two special-key rows at the bottom of the terminal. Ships one configuration — function keys F1–F10; tapping sends the key via the existing `_sendSpecialKey` → tmux `send-keys` path, so CTRL/ALT/SHIFT toggles compose (e.g. SHIFT+F1 → `S-F1`). New `KeyBarConfig`/`KeyBarButton` model (`lib/widgets/key_bar_config.dart`); `SpecialKeysBar.variableKeyBar` defaults to it (null hides). Future button sets plug in without re-wiring the terminal. +6 tests (354→? suite 363).
- 014-translate-ui-strings: Translated the remaining user-facing Japanese UI strings to English (005 was comments-only) — file browser menus/dialogs, biometric-auth prompts, the SSH foreground-notification title, and the command-input hint. 0 Japanese left in lib UI strings; hardcoded English (no i18n framework).
- 013-fix-multiline-paste: Fixed multi-line command send silently failing. Root cause: `SshClient` only rewrote the *leading* `tmux` to the detected absolute path, so the load-buffer/paste-buffer pipeline ran bare `tmux` after `|`/`&&` → wrong binary (system 3.4 vs user 3.6a) → version mismatch. Extracted a pure `TmuxCommandResolver` (rewrites all command-position tmux), added a reproduction test, and made `_sendMultilineText` surface a SnackBar on failure (was a no-op `AppLog.d`).
- 012-coexist-app-id: Gave this Claude-focused fork its own app identity so it installs alongside upstream `moezakura/mux-pod` — Android `applicationId` `si.mox.mux_pod_claude` (was `si.mox.mux_pod`), home-screen name "MuxPod Claude" (Android label + iOS `CFBundleDisplayName`).

- 011-terminal-tests: Added the first terminal characterization tests (+13): `SpecialKeysBar` modifier/special-key behavior and `AnsiTextView` hardware-key handling, driven through the widgets' public callbacks (no SSH harness). Silenced `AppLog` in tests. Suite 335→348.
- 010-hygiene: Set a real `pubspec.yaml` description; pruned the unused `web/linux/macos/windows` platform scaffolding (the app targets Android + iOS only); added `specs/README.md` mapping the feature timeline and the 001/002 numbering collisions.
- 009-decompose-large-files: Decomposed the next god-files (behavior-identical). `connections_screen.dart` 1,180→494 (extracted 4 widget classes to `widgets/`); `ansi_text_view.dart` 1,399→472 (extracted gesture recognizer; `AnsiTextViewState` → Logic/View part-file mixins); `special_keys_bar.dart` 1,064→107 (`_SpecialKeysBarState` → Logic/View mixins).
- 008-logging-utility: Added a level-gated, release-safe logger (`lib/services/logging/app_log.dart`, `AppLog`); routed all ~84 ad-hoc `debugPrint`/`developer.log` sites through it; stopped logging raw SSH command stdout/stderr and raw tmux output (log byte counts only) to prevent secret leakage.
- 007-decompose-terminal-screen: Broke up the `terminal_screen.dart` god-widget (4,527 → 389 lines), behavior-identical. Slice 1: extracted 7 helper classes (painters, dialogs, pane-layout visualizer) into `lib/screens/terminal/widgets/`. Slice 2: split `_TerminalScreenState` into `part`-file mixins — `_TerminalScreenLogic` (fields + engine) and `_TerminalScreenView` (build helpers/dialogs).
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
