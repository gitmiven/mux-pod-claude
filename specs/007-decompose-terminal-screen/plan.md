# Plan — 007: Decompose `terminal_screen.dart` (Slice 1: extract helper classes)

## Context

`lib/screens/terminal/terminal_screen.dart` is 4,527 lines — the app's most important and most-churned
screen, and analysis recommendation **#1** (P1 god-widget; ~18% of `lib/` in one file). It's two parts:
a ~3,180-line `_TerminalScreenState` plus **7 fully self-contained helper classes** (painters, dialogs,
a pane-layout visualizer; ~1,230 lines) sitting below it. CI now guards every change (006), so this can
proceed incrementally and safely.

This PR does **Slice 1 only** (user-chosen): move the 7 helper classes into their own files. They are
behavior-identical pure moves — no logic change — that immediately cut ~1,230 lines and make those
widgets independently testable. Harder work (extracting controllers from `_TerminalScreenState`) is
deferred to follow-up PRs.

Dependency analysis (done): none of the 7 classes reference any top-level private symbol above line 3294
(`_TerminalViewData`, `ScrollModeSource`, etc.), and every import they need is already present in
`terminal_screen.dart`. So extraction is mechanical and low-risk.

## Approach

Create 5 files under `lib/screens/terminal/widgets/`, each holding one cohesive group, with the classes
made **public** (`_Foo` → `Foo`). Then in `terminal_screen.dart`: delete the moved classes, add the 5
imports, and rename the call-site references.

### New files (classes grouped by cohesion)

| New file | Classes moved (made public) | Imports needed (all already used in the file today) |
|----------|------------------------------|------------------------------------------------------|
| `widgets/pane_layout_visualizer.dart` | `PaneLayoutPainter`, `PaneLayoutVisualizer`(+State), `SplitRightIconPainter`, `SplitDownIconPainter` | `material`, `google_fonts`, `services/tmux/tmux_parser.dart` (TmuxPane), `services/tmux/tmux_commands.dart` (SplitDirection), `theme/design_colors.dart` |
| `widgets/input_dialog_content.dart` | `InputDialogContent`(+State) | `material`, `services` (HardwareKeyboard/LogicalKeyboardKey), `google_fonts`, `theme/design_colors.dart` |
| `widgets/new_window_dialog.dart` | `NewWindowDialog`(+State) | `material`, `google_fonts`, `theme/design_colors.dart` |
| `widgets/resize_pane_chooser_dialog.dart` | `ResizePaneChooserDialog`(+State) | `material`, `services/tmux/tmux_parser.dart` (TmuxPane), `theme/design_colors.dart` |
| `widgets/resize_window_chooser_dialog.dart` | `ResizeWindowChooserDialog`(+State) | `material`, `services/tmux/tmux_parser.dart` (TmuxWindow/TmuxPane), `theme/design_colors.dart` |

`SplitRightIconPainter`/`SplitDownIconPainter` are referenced only inside the visualizer, so they live in
the same file and need no call-site change in the state class.

### Edits to `lib/screens/terminal/terminal_screen.dart`

- Remove the helper-class region (≈ lines 3294–4527), **including** the `buildInputDialogContentForTesting`
  factory at the end (it existed only to expose the private dialog to the test).
- Add the 5 new `import 'widgets/…';` lines.
- Rename the call-site references in `_TerminalScreenState` (keep behavior identical):
  - `_PaneLayoutPainter(` → `PaneLayoutPainter(` (in `_buildPaneOverlay`)
  - `_PaneLayoutVisualizer(` → `PaneLayoutVisualizer(` (in the pane-select sheet)
  - `_InputDialogContent(` → `InputDialogContent(` (in the command-input sheet)
  - `_NewWindowDialog(` → `NewWindowDialog(` (in `_showCreateWindowDialog`)
  - `_ResizePaneChooserDialog(` → `ResizePaneChooserDialog(` (in the resize-pane dialog)
  - `_ResizeWindowChooserDialog(` → `ResizeWindowChooserDialog(` (in the resize-window dialog)
- Leave the existing Japanese UI string `'Shift+Enter: 改行'` as-is (UI-string localization is out of scope;
  consistent with 005).

### Test update

- `test/widgets/input_dialog_test.dart`: import the new `widgets/input_dialog_content.dart` and use
  `InputDialogContent` directly instead of `buildInputDialogContentForTesting` (which is being removed).
- Add a small widget test for one extracted dialog (e.g. `new_window_dialog.dart`'s name validation) to
  demonstrate the testability win the extraction unlocks.

### Spec-Kit artifacts

Scaffold `specs/007-decompose-terminal-screen/` (`spec.md`, `plan.md`, `tasks.md`) per the methodology,
scoped to this slice with the incremental roadmap noted.

## Files

- **New:** the 5 `lib/screens/terminal/widgets/*.dart` files above; `specs/007-decompose-terminal-screen/*`.
- **Modified:** `lib/screens/terminal/terminal_screen.dart` (remove classes + factory, add imports, rename
  references); `test/widgets/input_dialog_test.dart` (import new widget); CLAUDE.md Recent Changes (optional).

## Verification

- `flutter analyze --no-fatal-infos` → exit 0 (no new errors/warnings).
- `flutter test` → 325 pass / 0 fail (plus the one new dialog test) — behavior unchanged.
- Line count: `terminal_screen.dart` drops from 4,527 to ≈ 3,290.
- Sanity: a quick read of each new file confirms only public-rename + import changes (no logic edits).
- Branch already exists (`007-decompose-terminal-screen`, off `main`). Commit, push, open PR; CI runs the gate.

## Out of scope (follow-up PRs)

Extracting controllers from `_TerminalScreenState` — polling/capture engine, input/IME/key handling,
copy-mode/scroll, tmux session/window/pane operations — each with unit tests (recommendation #5). These
carry the real god-widget risk and are intentionally separate, smaller PRs.
