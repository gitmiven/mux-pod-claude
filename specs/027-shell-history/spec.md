# Feature Specification: Shell history as a recent-commands source (bash/zsh)

**Feature Branch**: `027-shell-history` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: make the recent-commands history useful in plain-shell panes too — read the shell's
own history (`~/.bash_history` / `~/.zsh_history`), as a middle tier between Claude Code's history and
the app-recorded history.

## Context

Feature 025 reads Claude Code's prompt history (`~/.claude/history.jsonl`) for the recent-commands
picker, falling back to the app-recorded history (023). But that Claude source only exists in panes
running Claude Code. In a **plain shell** pane, the picker only shows app-recorded (popup-sent)
commands — not what the user typed directly at the prompt.

The shell keeps its own history on the server (verified: `~/.bash_history` here, 1000 lines). This adds
it as a **middle tier** in the resolution chain:

> **Claude history** (Claude pane) → **shell history** (bash/zsh) → **app-recorded history** (fallback)

The active pane's foreground command (`TmuxPane.currentCommand`) hints which shell to prefer.

### Formats (verified / known)
- **bash** `~/.bash_history`: one command per line, **no timestamps**, chronological (newest last).
- **zsh** `~/.zsh_history`: extended entries `: <epoch>:<dur>;<command>` (or plain), newest last.

## User Scenarios & Testing

### User Story 1 — Recent shell commands in a shell pane (Priority: P1)

In a bash/zsh pane, tapping the ⏱ history button lists the user's **recent shell commands**
(deduplicated, newest first); tapping one sends it to the pane.

**Acceptance scenarios**:
1. **Given** a pane whose foreground command is `bash`, **when** the picker opens (and there's no Claude
   history for the project), **then** it lists recent `~/.bash_history` commands, newest first, deduped.
2. **Given** a `zsh` pane, **then** it reads `~/.zsh_history`, extracting the command from each
   `: ts:dur;cmd` entry.
3. **Given** a Claude Code pane, **then** Claude history still takes precedence (shell history is the
   fallback, not a replacement).
4. **Given** neither Claude nor shell history is available, **then** it falls back to the app-recorded
   history (023); if nothing, the empty state.

### Edge cases

- **No history file / not connected / unreadable**: skip to the next tier (no crash).
- **Bash mid-session**: bash writes history on shell exit, so the *current* session's just-typed
  commands may not appear until the shell flushes — accepted (documented).
- **zsh multi-line entries** (trailing `\`): v1 treats each physical line independently (no
  reconstruction) — accepted.
- **Comment lines / blanks**: skipped.
- **No per-folder scoping**: shell history is global (unlike Claude's project scoping) — accepted.
- **Privacy**: reads the user's shell history over their own SSH connection (may contain secrets typed
  inline) — same consideration as 025.

## Requirements

- **FR-001**: When Claude history yields nothing for the active pane, the picker MUST read the **shell
  history** over the existing SSH connection (bounded `tail`), parse it newest-first + deduped, and show
  the top N — slotted **between** Claude history and the app-recorded history.
- **FR-002**: The shell to read MUST be chosen from the pane's foreground command (`zsh` →
  `~/.zsh_history`; `bash`/`sh`/other → `~/.bash_history`, trying the other if the first is empty).
- **FR-003**: **bash** parsing MUST treat each line as a command (skip blanks/comments); **zsh** parsing
  MUST extract the command from `: <ts>:<dur>;<cmd>` (and accept plain lines). Both newest-first, deduped.
- **FR-004**: Any failure (missing file, unreadable, disconnected) MUST fall through to the next source;
  never crash.
- **FR-005**: Selecting a command MUST send it to the pane via the existing path — unchanged from
  023/025.
- **FR-006**: Parsing MUST be **pure, unit-testable** functions.
- **FR-007**: The Claude-history and app-history behaviour MUST be unchanged; this only inserts the
  middle tier.

## Key Entities

- **Shell history entry** — a command string parsed from `~/.bash_history` / `~/.zsh_history`.

## Success Criteria

- **SC-001**: `parseBashHistory` returns recent unique commands newest-first, capped, skipping
  blanks/comments — unit test.
- **SC-002**: `parseZshHistory` extracts commands from extended (`: ts:dur;cmd`) and plain lines,
  newest-first, deduped — unit test.
- **SC-003**: The resolution chain prefers Claude → shell → app (verified by the wiring; shell read
  returns null when unavailable).
- **SC-004**: `flutter analyze --no-fatal-infos` exit 0; `flutter test` ≥ (current) pass + new tests.

## Assumptions

- **Middle tier, automatic** (no setting): Claude → shell → app.
- **Shell choice by `currentCommand`** hint; default bash, try zsh if bash empty (and vice-versa).
- **Bounded `tail`** read (~2000 lines); v1 ignores zsh multi-line reconstruction.
- English, hardcoded UI strings (no i18n framework).

## Scope

**In scope**: pure `parseBashHistory` / `parseZshHistory`; `ShellHistoryReader.read` (SSH tail, shell
hint); insert the shell tier into `_loadRecentCommands`; unit tests for the parsers.

**Out of scope**: per-directory scoping; fish/other shells; multi-line zsh reconstruction; live
mid-session bash flush; a source-selection setting; timestamp-merging bash+zsh.
