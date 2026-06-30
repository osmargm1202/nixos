# orgm-themes Go design

## Goal

Replace the slow Bash `orgm-theme` helper with a focused Go binary named `orgm-themes`, while keeping the existing user-facing commands and generated files compatible.

## Scope

First slice keeps the existing dark/light implementation and makes it faster. It does not add new theme sources, Quickshell selector UI, Chromium profile mutation, or wallpaper-derived palette generation.

## Architecture

`orgm-themes` owns theme loading, apply planning, atomic writes, wallpaper theme memory, and optional live reload. The old `orgm-theme` shell entry becomes a small compatibility wrapper that execs `orgm-themes`.

```text
cmd/orgm-themes
  -> internal/orgmtheme loader
  -> apply plan
  -> atomic writer
  -> reload runner
```

## Compatibility requirements

`orgm-themes` must support:

- `list`
- `current`
- `status`
- `apply orgm-dark`
- `apply orgm-light`
- `toggle`

It must read theme env files from:

```text
$XDG_CONFIG_HOME/orgm-theme/themes/<theme>.env
```

It must continue writing the active files used today:

- `$XDG_STATE_HOME/orgm-theme/current`
- `$XDG_STATE_HOME/orgm-theme/current.env`
- `$XDG_CONFIG_HOME/kitty/current-theme.conf`
- `$XDG_CONFIG_HOME/rofi/orgm-current.rasi`
- `$XDG_CONFIG_HOME/fuzzel/fuzzel.ini`
- `$XDG_CONFIG_HOME/waybar/orgm-current.css`
- `$XDG_CONFIG_HOME/waybar-hypr/orgm-current.css`
- `$XDG_CONFIG_HOME/nwg-dock-hyprland/orgm-current.css`
- `$XDG_CONFIG_HOME/swaync/orgm-current.css`
- `$XDG_CONFIG_HOME/quickshell/theme/theme.json`
- `$XDG_CONFIG_HOME/gtk-3.0/settings.ini`
- `$XDG_CONFIG_HOME/gtk-4.0/settings.ini`
- `$XDG_CONFIG_HOME/gtk-4.0/gtk.css`
- `$XDG_CONFIG_HOME/gtk-4.0/gtk-dark.css`
- `$XDG_DATA_HOME/icons/default/index.theme`
- `$XDG_CONFIG_HOME/qt5ct/qt5ct.conf`
- `$XDG_CONFIG_HOME/qt5ct/colors/orgm-current.colors`
- `$XDG_CONFIG_HOME/qt6ct/qt6ct.conf`
- `$XDG_CONFIG_HOME/qt6ct/colors/orgm-current.colors`
- `$XDG_CONFIG_HOME/kdeglobals`
- `$XDG_CONFIG_HOME/hypr/scheme/current.conf`
- `$HOME/.pi/agent/settings.json`, only when file exists

## Performance design

Default `apply` writes files and performs lightweight live reloads. Expensive operations are guarded:

- never scan `/nix/store` for `GSETTINGS_SCHEMA_DIR` inside Go;
- call `gsettings` only if schema access already works or `GSETTINGS_SCHEMA_DIR` is set;
- avoid fixed sleep unless dock reload explicitly needs delay;
- add `--no-reload` for fastest apply/test path;
- add `--print-reload` for inspection.

Target: generated writes under 50ms in tests, with total live apply bounded mainly by external reload commands.

## Wallpaper memory

Keep current behavior:

1. Before theme switch, save current wallpaper state to `$XDG_STATE_HOME/orgm-theme/wallpapers/<previous>.state`.
2. Save per-monitor state to `$XDG_STATE_HOME/orgm-theme/wallpapers/<previous>.monitors/*.state`.
3. After files/reload, restore incoming theme wallpaper using `orgm-wallpaper`.

## Packaging

Add Nix package `orgm-themes` in `/home/osmarg/Hobby/nixos`, based on existing `orgm-wallpaper.nix` pattern. Install it in Hyprland profile. Keep `orgm-theme` wrapper in dotfiles so current menus need minimal changes.

## Validation

- Go unit tests for loader, renderers, apply plan, wallpaper memory, and reload command planning.
- Existing shell smoke tests must keep passing through wrapper:
  - `tests/helpers/orgm-theme-light-contrast.bats.sh`
  - `tests/helpers/orgm-theme-wallpaper.bats.sh`
- `go test ./...`
- `bash tests/helpers/orgm-theme-light-contrast.bats.sh`
- `bash tests/helpers/orgm-theme-wallpaper.bats.sh`
