# ORGM helper script refactor design

## Goal

Remove `orgm-hypr` as an installed or called command. Keep only the high-cost Go helpers for now: `orgm-dot`, `orgm-calendar`, and `orgm-wallpaper`. Restore all lower-cost Hyprland glue as tracked shell scripts under `config/shared/.local/bin`.

## Current state

- `orgm-hypr` is still packaged and installed by the NixOS repo through `orgmHypr` in `flake.nix` and `nixos/profiles/hyprland.nix`.
- Dotfiles still call `orgm-hypr` from Hyprland Lua, Waybar config, Quickshell calendar/wallpaper, and a few scripts.
- Host has `orgm-dot`, `orgm-calendar`, `orgm-wallpaper`, and `orgm-hypr`; `dot` does not exist.
- `Win+/` is broken because it calls `orgm-hypr helper toggle`.
- Calendar is broken because callers use `orgm-hypr calendar`, and the Go calendar helper invokes `gcalcli` with an invalid flag order for installed `gcalcli 4.5.1`.
- Waybar appears on both `DP-3` and `HDMI-A-1` because the Waybar config has no `output` constraint.
- Wallpaper picker and Go wallpaper state are global; they do not model one static wallpaper per monitor.

## Target command model

Only these Go binaries remain first-class NixOS packages:

- `orgm-dot` — dotfiles status/diff/sync/add/remove/daemon.
- `orgm-calendar` — calendar sync, daemon, status, UI toggle, web/event actions.
- `orgm-wallpaper` — wallpaper restore, picker data, picker daemon, static wallpaper set/random/carousel, status.

`orgm-hypr` should not be installed by the NixOS Hyprland profile and should not be referenced by dotfiles. Existing high-level behavior should be reached through shell scripts in `config/shared/.local/bin`.

## Shell script responsibilities

Restore or create small scripts for Hyprland glue that does not need a Go binary:

- Session/environment:
  - `hypr-session-import-env`
  - `hypr-start-containers`
  - `hypr-start-discord`
- Key helper:
  - `hypr-keyhelper init`
  - `hypr-keyhelper toggle`
- Waybar:
  - keep `waybar-watch` as the launcher/watcher script
  - Waybar date/swap/workspace helpers can remain scripts where already present
- Menus and UI glue:
  - use existing `hypr-main-menu`, `hypr-system-menu`, `hypr-tools-menu`, `hypr-power-menu`, etc.
  - add missing scripts only where current `orgm-hypr` calls have no script equivalent
- Misc launchers:
  - `hypr-pi-prompt`
  - `hypr-obsidian-open-or-focus`

Shell scripts should be POSIX sh or bash only where arrays/process handling are needed. They should prefer host tools already on NixOS and avoid calling `orgm-hypr`.

## Dotfiles rewiring

Replace every tracked `orgm-hypr` reference in dotfiles:

- `config/shared/.config/hypr/lua/autostart.lua`
  - `orgm-hypr session import-env` → `hypr-session-import-env`
  - `orgm-hypr wallpaper restore` → `orgm-wallpaper restore`
  - `orgm-hypr wallpaper picker-daemon` → `orgm-wallpaper picker-daemon`
  - `orgm-hypr calendar daemon` → `orgm-calendar daemon`
  - session container/Discord calls → restored shell scripts
- `config/shared/.config/hypr/lua/keybindings.lua`
  - `Win+/` → `hypr-keyhelper toggle`
  - wallpaper → `orgm-wallpaper pick`
  - calendar → `orgm-calendar toggle-ui`
  - other calls → existing or new scripts
- `config/shared/.config/waybar-hypr/config`
  - date click actions → `orgm-calendar toggle-ui`
  - wallpaper click → `orgm-wallpaper pick`
  - key helper click → `hypr-keyhelper toggle/init`
  - constrain `top_bar` and `bottom_bar` to the main monitor `DP-3`
- `config/shared/.config/quickshell/calendar/shell.qml`
  - calendar actions run `orgm-calendar` directly
- `config/shared/.config/quickshell/wallpaper-picker/shell.qml`
  - default script becomes `orgm-wallpaper`
  - script args default becomes empty

## NixOS packaging changes

In `/home/osmarg/Hobby/nixos`:

- Remove `orgmHypr` from `flake.nix` package set and installed package lists.
- Remove `orgmHypr` from `nixos/profiles/hyprland.nix`.
- Keep `orgmDot`, `orgmCalendar`, and `orgmWallpaper` configured through `dotfiles-orgm-source`.
- `nixos/packages/orgm-hypr.nix` may remain as dead file only if not referenced, but preferred cleanup is to remove it in a separate commit.

## Calendar fix

Update calendar Go helper so `gcalcli` command order matches installed `gcalcli 4.5.1`:

```text
gcalcli --nocolor agenda --tsv --details calendar --details url
```

This fixes the local parse/argument error. Google OAuth/authentication may still be required after the command order is fixed; that is a runtime credential task, not a dotfiles refactor task.

## Wallpaper per-monitor design

Initial support covers static wallpapers per monitor only.

### State

`orgm-wallpaper` keeps backward compatibility with the current global state, and adds per-monitor state:

```text
~/.local/state/hypr-wallpaper/state                    # legacy/global
~/.local/state/hypr-wallpaper/monitors/<OUTPUT>.state  # per monitor
```

Each state file stores:

```text
mode=static
path=/absolute/path/to/wallpaper
```

Monitor names must be sanitized for file paths but preserve the original output name inside command execution where needed.

### Commands

Add monitor-aware static commands:

```text
orgm-wallpaper set-static PATH --monitor DP-3
orgm-wallpaper random static --monitor HDMI-A-1
orgm-wallpaper status --monitor DP-3
orgm-wallpaper restore
```

Behavior:

- Without `--monitor`, commands keep current global behavior.
- With `--monitor`, `hyprpaper wallpaper "OUTPUT,PATH"` is used.
- `restore` applies all saved per-monitor static states; if no per-monitor state exists, it falls back to current global restore.
- Random/carousel can choose independently per monitor.
- Video wallpapers remain global/unsupported per-monitor for this phase.

### Quickshell picker

Update wallpaper picker to support a target monitor:

- Read monitor list from generated JSON data or a separate state field generated by `orgm-wallpaper`.
- Show a simple monitor selector using Hyprland output names, e.g. `DP-3`, `HDMI-A-1`.
- Apply selected wallpaper using:

```text
orgm-wallpaper set-static PATH --monitor OUTPUT
```

The picker should keep defaulting to the primary/main monitor when opened from Waybar or `Win+Shift+W` if no monitor is selected.

## Waybar main monitor

For host `orgm`, Waybar should show only on `DP-3` for this phase. Add `"output": "DP-3"` to both `top_bar` and `bottom_bar` in `config/shared/.config/waybar-hypr/config`.

Future improvement: derive main monitor from host-specific monitor layout config. That is out of scope for this refactor.

## Testing and verification

### Dotfiles repo

- Search for `orgm-hypr` after rewiring; result should be zero except historical docs/specs if intentionally retained.
- Run `distrobox-host-exec orgm-dot diff` before sync.
- Run `distrobox-host-exec orgm-dot sync` after changes.
- Verify Waybar logs only configure bars for `DP-3`.
- Verify `Win+/` launches the key helper Quickshell or writes a useful log/error.

### NixOS repo

- Run Go tests for changed helpers:

```bash
go test ./cmd/orgm-hypr ./internal/calendar ./internal/wallpaper ./internal/helper ./internal/waybar ./cmd/orgm-dot ./internal/dot...
```

During transition, tests under `cmd/orgm-hypr` may remain until the package is removed or split. New tests should focus on `internal/calendar` and `internal/wallpaper` behavior.

- Build/install profile after removing `orgm-hypr` references.
- Verify host commands:

```bash
command -v orgm-dot
command -v orgm-calendar
command -v orgm-wallpaper
! command -v orgm-hypr
```

## Migration order

1. Fix calendar command order in Go.
2. Add/restore missing shell scripts in dotfiles.
3. Rewire dotfiles away from `orgm-hypr`.
4. Add Waybar `DP-3` output restriction.
5. Add static wallpaper per-monitor state and commands.
6. Update Quickshell wallpaper picker for monitor target.
7. Remove `orgm-hypr` from NixOS packaging/profile.
8. Sync dotfiles and verify host runtime.

## Out of scope

- Per-monitor video wallpaper support.
- Rewriting every existing menu script in Go.
- Creating a `dot` alias or symlink unless requested separately.
- Dynamic main-monitor discovery for Waybar.
- Fixing Google OAuth credentials beyond reporting the auth state after command-order fix.
