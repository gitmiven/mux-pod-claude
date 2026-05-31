# Feature Specs — Timeline & Numbering Guide

This directory holds the [Spec-Kit](https://github.com/github/spec-kit) feature folders. Each is
`NNN-feature-name/` with `spec.md` → `plan.md` → `tasks.md`.

## ⚠️ The `001`/`002` numbering collisions

The project began as **TypeScript + React Native + Expo + Zustand**, then migrated to
**Flutter + Dart + Riverpod** (see `001-flutter-migration/` and `../.specify/memory/constitution.md`,
re-baselined to v2.0.0). The two eras independently used `001…`/`002…` prefixes, so several numbers
collide (e.g. two `001-ssh-…`, two `002-…`, two `*-ssh-key-management`). Rather than renumber
(which would break history/links), this table maps them. **For new features, continue from the
highest existing number** (currently `010`).

## Timeline

### Pre-migration era — React Native / Expo / TypeScript (historical)

These were authored against the original RN/Expo design; the code was later migrated to Flutter.

| Folder | What |
|--------|------|
| `001-phase1-mvp` | Initial MVP scope |
| `001-component-tests` | Component test setup |
| `001-ssh-terminal-integration` | SSH connect → tmux attach → key send |
| `001-settings-notifications` | Settings screen + notification rules |
| `002-ssh-key-management` | SSH key generation/import/management |
| `002-ssh-reconnect` | Auto-reconnect / resilience |

### The pivot

| Folder | What |
|--------|------|
| `001-flutter-migration` | Migrate the app from React Native/Expo to Flutter/Dart/Riverpod |

### Flutter era (current stack)

| Folder | What | Status |
|--------|------|--------|
| `001-terminal-width-resize` | Terminal width/resize handling | merged |
| `003-ssh-key-management` | SSH key management on the Flutter stack | merged |
| `004-ssh-security-hardening` | Host-key verification (TOFU) + command-injection escaping | merged (PR #1) |
| `005-translate-japanese-comments` | Translate in-code comments to English | merged (PR #2) |
| `006-pr-validation-ci` | GitHub Actions CI (analyze + test) + green suite | merged (PR #3) |
| `007-decompose-terminal-screen` | Break up the `terminal_screen.dart` god-widget (4,527→389) | merged (PR #4) |
| `008-logging-utility` | Level-gated, release-safe logger + secret-leak audit | merged (PR #5) |
| `009-decompose-large-files` | Decompose connections_screen / ansi_text_view / special_keys_bar | merged (PR #6) |
| `010-hygiene` | pubspec description, prune unused platforms, this README | in progress |

> Status/PR numbers refer to the `gitmiven/mux-pod-claude` fork. The broader risk/recommendation
> backlog that drove 004–010 lives in `miven/analysis/06-risks-and-recommendations.md` (git-ignored).
