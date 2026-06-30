# Wallpaper-Driven Color Theme

**Date:** 2026-06-16
**Status:** Approved

## Problem

When the wallpaper changes via `orgm-wallpaper`, the waybar, dock, and all themed components keep the static Catppuccin Macchiato palette. Colors should auto-derive from the active wallpaper while preserving the user's dark/light mode preference.

## Approach

Integrate color extraction directly into `orgm-wallpaper` (Go). After each wallpaper set operation, run `matugen` on the source image, map Material You roles to the existing `orgm.Theme` struct, and call the existing `BuildWrites()` to regenerate all themed component files.

## Source Image Selection

| Wallpaper mode | Source for color extraction |
|---|---|
| `static`, `static-random` | wallpaper path directly |
| `video`, `video-random` | thumbnail via `Manager.WallpaperThumb(path)` — generated with ffmpeg at `<dir>/.thumb/<name>.jpg` |

## Color Mapping: matugen → orgm Theme

matugen outputs a `dark` and `light` palette. Selection follows current theme's `ColorScheme` field (`prefer-dark` → `dark`, `prefer-light` → `light`).

```
Material You role             → Theme field
─────────────────────────────────────────────
background                    → BASE
surface_container_low         → MANTLE
surface_container_lowest      → CRUST
surface_container             → SURFACE0
surface_container_high        → SURFACE1
surface_container_highest     → SURFACE2
outline_variant               → OVERLAY0
outline                       → OVERLAY1
on_surface_variant            → OVERLAY2
on_background                 → TEXT
on_surface_variant            → SUBTEXT0
on_surface                    → SUBTEXT1
primary                       → BLUE
tertiary                      → MAUVE
secondary                     → TEAL
primary_fixed_dim             → SKY
secondary_fixed               → GREEN
tertiary_fixed                → YELLOW
primary_container             → PEACH
error                         → RED
tertiary_container            → PINK
on_secondary_container        → FLAMINGO
on_tertiary_container         → ROSEWATER
on_primary                    → ON_ACCENT
```

Computed fields:
- `PANEL_BG` = `background` hex + `"99"` alpha (dark) or `"dd"` (light)
- `MENU_BG`  = `background` hex + `"dd"` alpha (dark) or `"ee"` (light)
- `QS_OVERLAY`, `QS_CARD`, `QS_CARD_STRONG`, `QS_CARD_SOFT`, `QS_EVENT`, `QS_HOVER` = derived from surface_container variants with fixed alpha prefixes matching current theme pattern

Fields preserved from current `orgm-themes` theme (not changed by wallpaper):
`GTKTheme`, `IconTheme`, `CursorTheme`, `CursorSize`, `QTStyle`, `KittyBackgroundOpacity`, `ColorScheme`, `PITheme`, `Name`

## Files Affected

Same set as `orgm-themes apply` / `BuildWrites()`:
- `waybar/orgm-current.css`
- `waybar-hypr/orgm-current.css`
- `nwg-dock-hyprland/orgm-current.css`
- `kitty/current-theme.conf`
- `rofi/orgm-current.rasi`
- `fuzzel/fuzzel.ini`
- `swaync/orgm-current.css`
- `quickshell/theme/current.json` + `theme.json`
- `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `gtk-4.0/gtk.css`, `gtk-4.0/gtk-dark.css`
- `qt5ct/qt5ct.conf`, `qt5ct/colors/orgm-current.colors`
- `qt6ct/qt6ct.conf`, `qt6ct/colors/orgm-current.colors`
- `kdeglobals`
- `hypr/scheme/current.conf`

## Implementation Files

**New:**
- `internal/wallpaper/colors.go` — matugen subprocess runner, JSON parser, color mapper, `ApplyColors()` method on `Manager`

**Modified:**
- `internal/wallpaper/manager.go` — add `applyColorsQuiet()`, call it at end of `SetStatic`, `SetVideo`, `SetStaticForMonitor`, `SetVideoForMonitor`. NOT called from `Restore()` or daemon loops.
- `cmd/orgm-wallpaper/main.go` — add `"apply-colors"` case with `--no-reload` and `--dry-run` flags

## New Subcommand

```
orgm-wallpaper apply-colors [--no-reload] [--dry-run]
```

- `--dry-run`: print planned writes to stdout, no disk writes, no reload
- `--no-reload`: write files but skip reload signals
- Standalone: re-applies colors for current wallpaper without changing the wallpaper

## Reload Sequence

After writing files:
1. `pkill -SIGUSR2 waybar` — reload CSS
2. `swaync-client -rs` — reload swaync (if binary present, errors ignored)
3. nwg-dock: no reload signal; picks up CSS on next start

## Error Handling

| Failure | Behavior |
|---|---|
| `matugen` not found or exits non-zero | `notify-send "orgm-wallpaper" "Color extraction failed: <err>"` + log to stderr + return (wallpaper change still succeeds) |
| thumb generation fails (video) | same notify-send pattern |
| no wallpaper in state | silent return, nothing to process |
| `BuildWrites` / file write fails | notify-send + log stderr |

## matugen Invocation

```sh
matugen image <source-path> --json hex
```

JSON output structure parsed:
```json
{
  "colors": {
    "dark": { "primary": "#rrggbb", ... },
    "light": { "primary": "#rrggbb", ... }
  }
}
```

## Testing

- Unit test `MapColors()`: given fixture matugen JSON + dark/light theme, assert Theme fields map correctly
- Unit test `ColorSourceImage()`: static → path; video → thumb path
- Integration: `orgm-wallpaper apply-colors --dry-run` prints writes without touching disk
