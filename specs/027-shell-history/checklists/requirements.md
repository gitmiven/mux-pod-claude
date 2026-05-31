# Spec quality checklist — 027 shell history source

- [x] User value clear (P1: history button works in plain bash/zsh panes, not just Claude).
- [x] Grounded: ~/.bash_history (plain, no ts) / ~/.zsh_history (`: ts:dur;cmd`); pane currentCommand hint.
- [x] Fits the chain: Claude → shell → app (middle tier, automatic, no setting).
- [x] Requirements testable (FR-001 read+order+dedup, FR-002 shell choice, FR-003 bash/zsh parse, FR-006 pure).
- [x] Measurable SCs (SC-001 bash parse, SC-002 zsh parse, SC-003 chain order, SC-004 gate).
- [x] Edge cases: missing file/disconnected, bash mid-session flush, zsh multi-line, comments, no scoping, privacy.
- [x] Reuses 023/025 picker + send path; their behaviour unchanged.
- [x] Scope bounds: no per-dir scoping, no fish, no multi-line zsh, no setting, bounded tail.
