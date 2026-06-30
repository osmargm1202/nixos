# Explore: orgm-hypr-theme-system

## Status

explored

## User goal

Build an `orgm-hypr` theme system for Hyprland dotfiles. Final project is split in two parts:

1. Theme application engine.
2. Theme selection UI with Quickshell.

First cycle should start with `themes.json`, capture the current configuration as a neutral theme, and make theme apply update wallpaper-derived colors plus light/dark mode across Waybar, nwg-dock, Zen Browser, Chromium, GTK, Qt, and adjacent desktop components.

## Current repo map

- `cmd/orgm-hypr/main.go` already owns wallpaper commands and has placeholder groups: `waybar`, `dock`, `zen`, `menu`, `updates`, `webapp`, `windows`, `notify`, `smart-run`.
- `internal/wallpaper/*` stores wallpaper state under `$XDG_STATE_HOME/hypr-wallpaper`, uses atomic state writes, manages static/video wallpapers, and produces Quickshell picker data.
- `tests/orgm-hypr.bats.sh` is current smoke-test harness for `orgm-hypr`; it builds binary and validates wallpaper picker/status/cleanup behavior.
- `docs/hyprland-theme-workflow.md` already recommends generated theme files, `matugen`/`wallust`/`pywal16`, current symlink files, and reloading Hyprland/Waybar.
- `config/shared/.config/hypr/hyprland.conf` sources split hyprlang files and `90-noctalia-colors.conf`.
- `config/shared/.config/hypr/hyprland.lua` is active Lua entrypoint for Hyprland 0.55 style config; legacy `.conf` files remain as fallback.
- Existing themed targets under `config/shared/.config`: `waybar-hypr`, `nwg-dock-hyprland`, `gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct`, `fuzzel`, `rofi`, `kitty`, `yazi`, `helix`, `quickshell/wallpaper-picker`, `Kvantum`, `dunst`, `swaync`, `wlogout`, `zathura`, `kdeglobals`, and icons/cursors.
- `config/dotfiles.json` tracks all major shared config paths, including `.config/hypr`, `.config/waybar-hypr`, `.config/nwg-dock-hyprland`, `.config/gtk-*`, `.config/qt*ct`, `.config/quickshell`, `.config/rofi`, `.config/kitty`, `.config/yazi`, `.config/Kvantum`, `.icons`, and `.local/bin`.

## HyDE reference findings

HyDE was shallow-cloned to `/tmp/HyDE-sdd-theme` from `https://github.com/HyDE-Project/HyDE`.

Relevant files inspected:

- `Configs/.local/lib/hyde/theme.switch.sh`
- `Configs/.local/lib/hyde/wallbash.sh`
- `Configs/.config/hyde/config.toml`
- `Configs/.config/hyde/wallbash/scripts/chrome.sh`
- `Configs/.config/hypr/themes/colors.conf`
- `Configs/.config/waybar/theme.css`, `style.css`, `modules/theme.jsonc`
- `Configs/.config/gtk-3.0/settings.ini`
- `Configs/.config/qt5ct/qt5ct.conf`, `qt6ct/qt6ct.conf`
- `Configs/.config/kitty/theme.conf`
- `Configs/.config/rofi/theme.rasi`
- `Configs/.config/Kvantum/wallbash/*`

HyDE model:

- Theme state is environment-driven (`HYDE_THEME`, `GTK_THEME`, icon/cursor/font variables) and persisted through HyDE config/state helpers.
- Theme switching loads theme metadata, sanitizes Hyprland theme fragments, writes generated files, updates GTK/Qt/KDE/cursor config, handles Flatpak overrides, and then applies wallpaper.
- Wallbash extracts colors from wallpaper using ImageMagick, detects dark/light mode automatically from brightness, generates primary/text/accent color variables, and writes both shell and app-specific formats.
- Generated Hyprland colors live in hyprlang files such as `colors.conf` and `wallbash.conf`.
- Browser theming is handled by generating a Chromium extension/theme manifest (`wallbash/scripts/chrome.sh`) using palette RGB values and wallpaper image.
- HyDE covers many targets but uses many shell scripts and global side effects.

Safe ideas to copy/adapt:

- Separate theme metadata from generated outputs.
- Generate files into cache/state first, then atomically publish current files.
- Keep per-target renderers/templates: Hyprland, Waybar, GTK, Qt, Kitty, Rofi/Fuzzel, Kvantum, Chromium theme.
- Detect dark/light from wallpaper brightness when theme mode is `auto`.
- Use a stable palette vocabulary: background, foreground, accent, surface, muted, error/warning/success, plus app-specific aliases.
- Keep reload hooks per target, with dry-run/preview support.

Unsafe to copy blindly:

- Large shell-sprawl and global `source`/environment coupling.
- Direct `sed -i` mutation of live config without backups/atomicity.
- Hyprland hyprlang fragments that may not match current Lua-first setup.
- Flatpak override behavior without explicit user control.
- Browser profile mutation without identifying profile path and rollback.

## Gaps and risks

- Current repo has a Lua Hyprland entrypoint; theme engine should not assume HyDE hyprlang-only model.
- Browser theming differs by profile: Chromium can load generated extension/theme, Zen/Firefox may need `userChrome.css`, prefs, or extension support; these are harder to apply safely.
- GTK/Qt/Kvantum changes may need XDG settings, `gsettings`/`dconf`, `xsettingsd`, Flatpak overrides, and restart hints.
- Waybar/nwg-dock can reload, but CSS changes must be template-based so user edits are not overwritten.
- Current dotfile sync tracks `config/shared`, but runtime theme application should mostly write to `$XDG_STATE_HOME`/`$XDG_CACHE_HOME` and `~/.config/.../current.*` generated files, not commit random wallpaper output.
- Nix/Arch mixed environment means external binaries (`matugen`, `wallust`, `magick`, `gsettings`, `hyprctl`) must be detected and reported.
- User may edit unrelated files during session; only target SDD artifacts and later approved theme files should be treated as ours.

## Recommended boundary

### Phase 1: theme application engine

- Add `orgm-hypr theme` commands.
- Store curated theme definitions in `config/shared/.config/orgm-hypr/themes.json`.
- Capture current config into `neutral` dark/light variants as initial source of truth.
- Render target outputs from Go templates with atomic writes and backups.
- Support dry-run, status, apply, validate, and export-neutral.
- Cover full initial target list with safe modes and explicit unsupported/browser notes.

### Phase 2: Quickshell selector

- Reuse engine APIs/data.
- Add theme picker UI after engine is stable.
- UI should call `orgm-hypr theme apply <id> --mode <dark|light|auto>` instead of duplicating theme logic.

## Evidence

Repo evidence: `cmd/orgm-hypr/main.go`, `internal/wallpaper/manager.go`, `tests/orgm-hypr.bats.sh`, `docs/hyprland-theme-workflow.md`, `config/shared/.config/hypr/hyprland.conf`, `config/shared/.config/hypr/hyprland.lua`, `config/dotfiles.json`, and theme-related files listed by `find config/shared/.config`.

HyDE evidence: shallow clone `/tmp/HyDE-sdd-theme`; files listed above.
