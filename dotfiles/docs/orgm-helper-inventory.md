# ORGM helper inventory

Inventory was generated in dotfiles worktree `/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore` and NixOS companion worktree `/home/osmarg/Hobby/nixos/.worktrees/orgm-helper-packaging`; repos remain separate.

## Dotfiles status before restoration

```text
# /home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore
?? docs/superpowers/plans/2026-05-29-orgm-helper-restoration.md
?? docs/superpowers/specs/2026-05-29-orgm-helper-restoration-design.md
```

## NixOS status before restoration

```text
# /home/osmarg/Hobby/nixos/.worktrees/orgm-helper-packaging
## orgm-helper-packaging
```

## Deleted helper paths from git history

- config/shared/.local/bin/brightness-osd
- config/shared/.local/bin/fuzzel-calc
- config/shared/.local/bin/fuzzel-hypr-window
- config/shared/.local/bin/fuzzel-open-file
- config/shared/.local/bin/fuzzel-open-file-dir
- config/shared/.local/bin/fuzzel-open-file-terminal
- config/shared/.local/bin/fuzzel-ssh-host
- config/shared/.local/bin/fuzzel-tmux-arch
- config/shared/.local/bin/hypr-bluetooth-menu
- config/shared/.local/bin/hypr-current-wallpaper
- config/shared/.local/bin/hypr-focus-notification-app
- config/shared/.local/bin/hypr-fuzzel
- config/shared/.local/bin/hypr-keybindings-help
- config/shared/.local/bin/hypr-keyboard-menu
- config/shared/.local/bin/hypr-kill-windows
- config/shared/.local/bin/hypr-lock
- config/shared/.local/bin/hypr-main-menu
- config/shared/.local/bin/hypr-nwg-dock
- config/shared/.local/bin/hypr-performance-menu
- config/shared/.local/bin/hypr-power-menu
- config/shared/.local/bin/hypr-random-wallpaper
- config/shared/.local/bin/hypr-smart-run
- config/shared/.local/bin/hypr-system-menu
- config/shared/.local/bin/hypr-tools-menu
- config/shared/.local/bin/hypr-webapp-maker
- config/shared/.local/bin/hypr-webapp-remover
- config/shared/.local/bin/hypr-wifi-menu
- config/shared/.local/bin/hypr-workspace-button
- config/shared/.local/bin/hypr-zen-new-window
- config/shared/.local/bin/mic-volume-osd
- config/shared/.local/bin/volume-osd
- config/shared/.local/bin/waybar-date-es
- config/shared/.local/bin/waybar-day-month-es
- config/shared/.local/bin/waybar-swap-usage
- config/shared/.local/bin/waybar-time-ampm
- config/shared/.local/bin/waybar-watch

## Target ownership

| Helper or area | Target owner | Recovery source | First action |
| --- | --- | --- | --- |
| `brightness-osd` | shell helper | `b4ccf50^` | restore and test notify payload |
| `volume-osd` | shell helper | `b4ccf50^` | restore and test notify payload |
| `mic-volume-osd` | shell helper | `b4ccf50^` | restore and test notify payload |
| `waybar-date-es` | shell helper | `b4ccf50^` | restore and test output |
| `waybar-day-month-es` | shell helper | `b4ccf50^` | restore and test output |
| `waybar-time-ampm` | shell helper | `b4ccf50^` | restore and test output |
| `waybar-swap-usage` | shell helper | `b4ccf50^` | restore and test meminfo parsing |
| `waybar-watch` | shell helper | `b4ccf50^` | restore and test print/launch plan |
| `hypr-main-menu` and submenus | shell helper | `b4ccf50^` | restore before changing keybindings |
| `hypr-power-menu` | shell helper | `b4ccf50^` | restore and test selection commands |
| `hypr-random-wallpaper` | shell helper + `orgm-wallpaper` | `b4ccf50^` plus NixOS Go wallpaper code | restore daemon, keep Go for data/thumbs |
| `fuzzel-*` helpers | shell helper | `b4ccf50^` | restore and test command generation |
| `hypr-workspace-button` | shell helper | `b4ccf50^` | restore and test JSON output/click command |
| `hypr-focus-notification-app` | shell helper | `b4ccf50^` | restore and wire SwayNC later |
| Wallpaper thumbnail/data | `orgm-wallpaper` Go | `/home/osmarg/Hobby/nixos/cmd/orgm-hypr` + `internal/wallpaper` | split after shell helpers exist |
| Calendar daemon | `orgm-calendar` Go | `/home/osmarg/Hobby/nixos/internal/calendar` | split after caller audit |
| Dotfile manager | `orgm-dot` Go | `/home/osmarg/Hobby/nixos/cmd/orgm-dot` + `internal/dot*` | move source to dotfiles, keep NixOS package consumer |

## Follow-up blocker fix

Diff review found that restored helper names were present, but many bodies were still thin `orgm-hypr` wrappers. The blocker was fixed by checking out the real historical shell implementations from the per-helper commits listed in the review. `hypr-random-wallpaper` was intentionally not overwritten.

## Final audit

Task 8 final audit is recorded in [`docs/orgm-helper-final-audit.md`](orgm-helper-final-audit.md).

Summary:

- Dotfiles active config and helper scripts are clean: no `orgm-hypr` refs remain in `config/shared` or `tests`.
- Remaining dotfiles refs are documentation/history snapshots.
- NixOS companion worktree still contains the deferred broad `orgm-hypr` package, compatibility internals, and tests until later package cleanup.
- `orgm-dot sync` was not run because this is an unmerged feature worktree and `orgm-dot diff` showed unrelated removal-only entries for `~/.local/bin/engram`, `orgmai`, `orgmos`, and `orgmweb`.
