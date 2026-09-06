# Hyprland theme workflow

`orgm-themes` is the declaratively packaged theme CLI. Hyprland installs the same derivation exposed as `packages.orgm-themes`; menu helpers resolve it through `command -v orgm-themes`, without a separate preference for `~/go/bin`.

## Source ownership

`nixos/common-dotfiles.nix` discovers individual files in these layers, in ascending precedence:

1. `dotfiles/config/shared/<target>`
2. Persistent Hyprland compositor, Waybar and helper files from `profiles/hyprland`
3. `dotfiles/config/profiles/<profile>/<target>`
4. `dotfiles/config/hosts/<host>/shared/<target>`
5. `dotfiles/config/hosts/<host>/profiles/<profile>/<target>`

The last file for a target wins. Home Manager links each file to the mutable checkout, so shared files and host overrides can coexist in one directory. Metadata and backup files are omitted. Versioned symlinks are valid sources and must resolve.

Hyprland helpers remain available when switching to i3. Its three Rofi support files are remapped under `.config/orgm-hypr/rofi/`; the active profile owns general Rofi and Dunst configuration. Host-specific Hyprland monitor and display overrides do not follow the user into i3.

There is no JSON inventory to update. Add managed configuration to its owning layer; keep application state, caches and generated theme output outside managed layers. Repository ignore rules document local generated output and must not be bypassed when staging files. First-run runtime defaults are initialized without overwriting existing user configuration.

## Curated presets

Preset sources live in:

```text
dotfiles/config/profiles/hyprland/.config/orgm-theme/themes/
  orgm-dark.env
  orgm-light.env
```

The CLI reads `~/.config/orgm-theme/themes`, or `ORGM_THEMES_DIR` when explicitly set. Current theme state lives under `$XDG_STATE_HOME/orgm-theme` (default `~/.local/state/orgm-theme`).

```bash
orgm-themes list
orgm-themes current
orgm-themes status
orgm-themes apply orgm-light
orgm-themes toggle
```

`apply` and `toggle` accept `--no-reload`. Theme switching writes generated colors without changing runtime-owned GTK preferences or system GSettings. Commit curated preset changes, not captured runtime output.

## Wallpaper memory

The active wallpaper implementation is the shell helper `hypr-wallpaper`:

```bash
hypr-wallpaper set /absolute/path/background.png
hypr-wallpaper set /absolute/path/left.png --monitor DP-1
hypr-wallpaper set /absolute/path/right.mp4 --monitor HDMI-A-1
hypr-wallpaper hide
hypr-wallpaper restore
```

A global selection clears prior per-monitor overrides. A monitor selection changes only that output. Hide/restore preserves global and per-monitor static/video selections, including monitor-only setups without a global default. Managed video processes are tracked separately from unrelated processes.

`orgm-themes` saves the outgoing global path and monitor snapshots, then restores the incoming global selection followed by its monitor overrides after live reload. Wallpaper state is stored under `$XDG_STATE_HOME/hypr-wallpaper`; per-theme snapshots live under `$XDG_STATE_HOME/orgm-theme/wallpapers`.

## Development and verification

There is one Go module at the repository root, with `cmd/orgm-themes` and `internal/{cli,orgmtheme}`. The Nix package source contains only this code, `go.mod`, and the preset fixtures.

From the repository root:

```bash
rtk go test ./internal/orgmtheme ./cmd/orgm-themes -count=1
rtk nix build 'path:.#orgm-themes' --no-link --print-out-paths
rtk bash tests/dotfile-layering.bats.sh
rtk bash tests/hypr-minimal-wallpaper.bats.sh
```

Use the printed package path with `ORGM_THEMES_BIN=/nix/store/.../bin/orgm-themes` when running the theme helper smoke tests under `dotfiles/tests/helpers/`. `path:.` includes new or moved files without staging. These checks do not activate NixOS or Home Manager.
