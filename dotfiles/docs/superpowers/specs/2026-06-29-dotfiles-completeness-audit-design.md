---
title: Dotfiles Completeness Audit
date: 2026-06-29
status: approved
---

# Dotfiles Completeness Audit

## Goal

Verify that `dotfiles` repo + `nixos` repo together reproduce a fully working desktop on a fresh host after `nh os switch`. Any gap found during the live test gets added to the appropriate repo.

## Test Procedure

1. `tests/dotfiles-backup.sh` — rename `~/.config` to `~/.config.bak-YYYYMMDD-HHMMSS`
2. `nh os switch` — fresh NixOS + Home Manager rebuild
3. `tests/dotfiles-audit.sh` — compare backup vs current state, generate categorized report
4. Review report → add missing configs to dotfiles / packages to NixOS
5. `tests/dotfiles-restore.sh` — emergency rollback if desktop breaks

## Audit Categories

| Symbol | Category | Meaning | Action |
|--------|----------|---------|--------|
| ✅ | TRACKED | In dotfiles.json, deployed correctly | None |
| ⚠️ | TRACKED BUT MISSING | In dotfiles.json, not deployed after rebuild | Fix deploy |
| ➕ | ADD TO DOTFILES | Had config in backup, missing after rebuild, not auto-gen | Add to dotfiles |
| 🔄 | AUTO-GENERATED | Program writes this itself (themes, monitors, state) | Do not track |
| ⏭️ | SKIP | Cache / browser / KDE-Plasma state | Do not track |
| 🆕 | NEW FROM REBUILD | Created fresh by NixOS/HM, not in backup | Already managed |
| 📦 | ADD TO NIXOS | Config gap AND binary missing from PATH | Add to NixOS |
| 🗂️ | IN REPO NOT DECLARED | In `config/shared/.config/` but not in dotfiles.json | Add to dotfiles.json |

## AUTO-GENERATED Classification

Configs explicitly managed by the program itself — tracking them causes conflicts on every launch:

- **Theme outputs**: `rofi-hyprchy`, `waybar-hyprchy`, `orgm-theme` generated files
- **Desktop state**: `hyprpanel`, `caelestia`, `nwg-displays`, `xsettingsd`
- **Warp terminal**: `warp`, `warp-terminal`
- **App databases**: `orgm*` family (orgmai, orgmcalc, orgmenv, etc.)
- **DE-managed**: `background`, `autostart`, `environment.d`, `mimeapps.list`
- **GTK auto-writes**: `gtkrc`, `gtkrc-2.0`, `fontconfig`, `session`
- Anything in `local_only.paths` in dotfiles.json (program-generated theme outputs)

## Scripts

| Script | Purpose |
|--------|---------|
| `tests/dotfiles-backup.sh` | Rename `~/.config` → timestamped backup |
| `tests/dotfiles-audit.sh` | Categorized gap report after rebuild |
| `tests/dotfiles-restore.sh` | Restore backup if desktop breaks |

## Notes

- `AGENTS.md` still references `orgm-dot` — update to current deploy workflow when replacement is confirmed.
- `dotfiles.json` settings block (`state_dir`, `poll_seconds`) is orgm-dot specific — remove when dotfiles.json format is updated.
- Report is saved to `~/dotfiles-audit-YYYYMMDD-HHMMSS.md`.
