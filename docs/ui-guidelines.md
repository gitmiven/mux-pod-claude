# MuxPod UI/UX guidelines

## Color palette

Based on a Material Design 3 dark theme.

| Use | Color | Description |
|------|--------|------|
| Background | `#1E1E1E` | Main background |
| Surface | `#2D3133` | Cards, containers |
| Primary | `#00C0D1` | Accent, buttons, active state |
| Text | `#FFFFFF` | Primary text |
| Text (secondary) | `#9E9E9E` | Supporting text |
| Error | `#CF6679` | Error state |
| Success | `#4CAF50` | Connected, etc. |

## Design tokens

### Corner radius
- Card/container: `40px` (MD3 style)
- Button: `20px`
- Input: `12px`
- Indicator (pill): `10px`

### Spacing
- xs: `4px`
- sm: `8px`
- md: `16px`
- lg: `24px`
- xl: `32px`

## Screen layout

### Bottom navigation

| Icon | Label | Screen |
|----------|--------|------|
| Server | Net | Connection list |
| Terminal | Term | Terminal view |
| Key | Keys | SSH key management |
| Gear | Settings | Settings |

### Connection list (Net)
- Connection cards are expandable
- Sessions shown as a tree
- Attached/Detached status badge
- "+ New Session" button

### Terminal (Term)
- Top: session / window / pane tabs
- Center: terminal output
- Bottom: special-keys bar (ESC/TAB/CTRL/ALT)
- Very bottom: input field + cmd button

### Notification-rule settings
- List of active rules
- Add-rule form
- Condition types: TEXT/REGEX/IDLE/ANY
- Pattern-test feature

## Fonts

| Use | Font |
|------|----------|
| Terminal (English) | JetBrainsMono, FiraCode |
| Terminal (Japanese) | HackGen, PlemolJP |
| UI | System font |

## Foldable-device support

- Left panel: session tree
- Right panel: terminal view
- Portrait: regular single column

## Icons

- Use Material Icons or Lucide Icons
- Connection state: green dot (connected), grey dot (disconnected), red dot (error)

## Logo

See `docs/logo/logo.svg`.
