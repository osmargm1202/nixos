# Waybar Follow-Up Tweaks Design

**Date:** 2026-06-19
**Project:** dotfiles
**Status:** Approved design

## Goal

Adjust Waybar after edge-to-edge bars implementation: fix right-edge gap, increase blur aggressiveness, regroup custom buttons, change power symbol to I/O with red color.

## User Requirements

1. Bars do not reach right edge — fix so top and bottom bars truly touch both edges
2. Blur must be more aggressive than current
3. Reorganize custom buttons:
   - Top-right modules-right: keep `privacy`, `tray`, then `theme_toggle`, `clipboard`, `power` (as I/O red, last)
   - Bottom-right modules-right: all other custom buttons grouped with wider gaps
4. Power button symbol: change `󰐥` to `⏻` (I/O power symbol), color `@red`

## Current State

### Right-edge gap
- `window.top_bar .modules-right` has `padding-right: 24px` in both CSS files — creates visible gap on right edge
- Dock spacer (`dock_spacer` bar) at 80px width may also contribute if visible; verify after removing padding

### Blur
- Hyprland: `look-and-feel.lua` sets `blur = { size = 5, passes = 3, vibrancy = 0.17 }` and `blur-waybar` layer rule with `blur = true, ignore_alpha = 0.10`
- Sway: `config` sets `blur_passes 3`, `blur_radius 5`

### Custom buttons layout
- Top bar (`modules-right`): `privacy`, `tray`, `custom/clipboard`, `custom/theme_toggle`, `custom/wallpaper`, `custom/usb_devices`, `custom/memclean`, `custom/nixclean`, `custom/hardware_fetch`, `custom/pi_status`, `custom/headset_reconnect`, `custom/hypr_config_editor`, `custom/logout_menu`
- Bottom bar (`modules-right`): `custom/conky_toggle`, `custom/kbd_layout`, `custom/keybindings_help`, `custom/power_profile`

## Proposed Changes

### 1. Fix right edge
- Set `window.top_bar .modules-right` `padding-right` to `0` (or `4px` minimal)
- Ensure `dock_spacer` bar does not introduce visible gap

### 2. Blur more aggressive
- Hyprland: `size 5→8`, `passes 3→4`, `ignore_alpha 0.10→0.0` on waybar layer rule
- SwayFX: `blur_radius 5→8`, `blur_passes 3→4`
- Make bar background slightly more translucent: `rgba(0,0,0,0.6)` → `rgba(0,0,0,0.45)` so blur shows through more

### 3. Custom buttons regrouping

**Top bar `modules-right`** (left-to-right):
```
privacy, tray, custom/clipboard, custom/theme_toggle, custom/logout_menu
```

`custom/logout_menu` changed:
- `"󰐥"` → `"⏻"` (I/O power symbol, U+23FB)
- CSS: `color: @red; font-weight: bold;`
- Remains last element in top-right

**Bottom bar `modules-right`:** move all remaining custom buttons here:

```
custom/wallpaper, custom/usb_devices, custom/headset_reconnect,
// gap
custom/memclean, custom/nixclean,
// gap
custom/hardware_fetch, custom/pi_status, custom/hypr_config_editor,
// gap
custom/conky_toggle, custom/kbd_layout, custom/keybindings_help, custom/power_profile
```

Gaps achieved via CSS `margin-left: 12px` (or `margin-right: 12px`) on the first element of each group, without visual separators.

### 4. Power symbol and color
- Config: change `custom/logout_menu.format` from `"󰐥"` to `"⏻"`
- CSS: `#custom-logout_menu { color: @red; font-weight: bold; }`

## Theme Strategy
Same as before: no touch theme toggle. Changes go into `config/shared/.config/waybar-hypr/` (and `waybar/` for Sway equivalent where applicable). Light/dark compatibility via `@import "orgm-current.css"`.

## Files to Modify
- `config/shared/.config/waybar-hypr/config` — reorder modules, change power format
- `config/shared/.config/waybar-hypr/style.css` — right-edge padding, power color, regroup gaps, more translucent background
- `config/shared/.config/waybar/config` — reorder modules, change power format (Sway equivalent)
- `config/shared/.config/waybar/style.css` — right-edge padding, power color, regroup gaps, more translucent background
- `config/shared/.config/hypr/lua/look-and-feel.lua` — blur size 5→8, passes 3→4, ignore_alpha 0.10→0.0
- `config/shared/.config/sway/config` — blur_radius 5→8, blur_passes 3→4

## Non-Goals
- No change to theme toggle
- No functional module changes (same exec/on-click/tooltip)
- No visual separators between groups (gap only)
- No change to dock spacer

## Verification
1. `git diff` shows expected files changed
2. Apply via `orgm-dot sync` targeted paths
3. Visual: top/bottom bars touch right edge
4. Visual: blur clearly stronger
5. Visual: power shows as I/O red, last in top-right
6. Visual: bottom-right custom buttons grouped with visible gaps
