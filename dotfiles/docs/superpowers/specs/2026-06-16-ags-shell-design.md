# AGS Shell — Design Spec
**Date**: 2026-06-16  
**Branch**: `feat/ags-shell`  
**Replaces**: `waybar-hypr` (top bar) + `nwg-dock-hyprland` (dock)  
**Status**: Approved

---

## Overview

Replace waybar and nwg-dock-hyprland with a single AGS v2 (Astal) TypeScript shell. AGS manages both the top bar and bottom dock. Matugen color integration is wired from the first commit. Master branch keeps waybar untouched — this work lives on a separate branch with phased visual validation before merge.

---

## Technology

| Choice | Rationale |
|--------|-----------|
| AGS v2 / Astal (TypeScript) | Full control, active Hyprland community, typed widgets |
| Single AGS process | One config, one theme, barra + dock coherent |
| Matugen via orgm-themes pipeline | Already used by waybar/swaync — extend same template system |
| Git branch `feat/ags-shell` | Waybar stays on master, AGS iterated visually before cutover |

Config location: `config/shared/.config/ags/`

---

## Top Bar

### Layout

```
LEFT                     CENTER            RIGHT
[ ⊞  1  2  ③  4  5 ]   [ 14:32  Lun 16 ]  [ 🔊  🌐  🔵  🖼️  ❓  📊 ]
```

### Left — Workspaces
- Menu button `⊞` → calls `hypr-main-menu`
- Workspace pills 1–10, custom per-workspace script (`hypr-workspace-button status/click`)
- Active workspace highlighted with matugen primary color
- Empty workspaces dimmed

### Center — Clock
- Time: large font (34px+), bold, matugen primary color
- Date: secondary text, day-of-week + date in Spanish (`waybar-date-es` logic ported)

### Right — System Modules
| Module | Behavior |
|--------|----------|
| Privacy/Tray | System tray icons (same as waybar `tray` + `privacy`) |
| 📋 Clipboard | Click → `hypr-rofi-clipboard` |
| 🎨 Theme | Click → `waybar-theme-toggle` logic (dark/light) |
| 🔊 Audio | Click → volume popup with slider |
| 🌐 Network | Status icon, click → `hypr-wifi-menu` |
| 🔵 Bluetooth | Status icon, click → `hypr-bluetooth-menu` |
| 🖼️ Wallpaper | Click → wallpaper dropdown panel |
| ❓ Help | Click → help panel |
| 📊 Specs | Hover → specs panel with rings |

### Visual Style
- Floating bar, `margin: 10px 12px`, `border-radius: 12px`
- Material You solid: `background: @base`, `border: 1.5px solid @surface1`
- Box shadow for elevation
- All colors from matugen-generated `ags-colors.css`

---

## Specs Panel (hover 📊)

Appears on hover over the 📊 button. Slides down with CSS opacity + transform transition.

### Rings Layout
7 circular SVG ring gauges in a grid:

```
[ CPU uso% ]  [ CPU temp° ]  [ GPU uso% ]  [ GPU temp° ]
[ RAM %  ]    [ SWAP %   ]   [ SSD %   ]
```

### Ring Spec
- SVG circle with `stroke-dashoffset` fill
- Inner text: value (percentage or °C) + unit label below
- Label below ring: component name

### Color Thresholds
| Range | Color | Matugen var |
|-------|-------|-------------|
| < 60% | Green | `@green` |
| 60–80% | Yellow | `@yellow` |
| > 80% | Red | `@red` |

Applies to: uso% rings. Temp rings use same thresholds mapped to °C ranges (CPU: <70/70-85/>85, GPU: <65/65-80/>80).

### Data Sources
- CPU uso%: `/proc/stat` or `top`
- CPU temp: `/sys/class/thermal/thermal_zone*/temp`
- GPU uso%/temp: `nvidia-smi` (nvidia) or `/sys/class/drm/*/device/gpu_busy_percent` (AMD)
- RAM/SWAP: `/proc/meminfo`
- SSD: `df -h /`

Update interval: 2s

### Panel Style
- `background: @base`, `border: 1.5px solid @surface1`, `border-radius: 16px`
- Padding: 20px 24px
- Elevation shadow matching bar

---

## Wallpaper Dropdown (click 🖼️)

### Layout
Grid 3 columns of thumbnails:
- Current wallpaper: highlighted with `@primary` border (2px)
- Other wallpapers: thumbnails from `~/.config/wallpapers/` and `~/Pictures/Wallpapers`
- Filename label below each thumbnail
- "+" cell to open file picker

### Action Buttons
- `🎲 Random` → calls `orgm-wallpaper set-random`
- `▶ Video` → opens file picker filtered to video, calls `orgm-wallpaper set-video`

### Thumbnail Generation
- Static: use image directly (scaled)
- Video: use existing thumbnail from `orgm-wallpaper` state (`.thumb.jpg`)

---

## Help Panel (click ❓)

### Sections
1. **Keybindings** — reads from `hypr-keyhelper` output or parses `keybindings.lua`, displays as searchable list grouped by category
2. **System Info** — machine model, kernel version, uptime, hostname

### Style
- Scrollable panel, max-height: 60vh
- Category headers with matugen accent color
- Monospace font for key combos

---

## Bottom Dock

### Layout
```
[ kitty  nautilus  zen  chromium  obsidian ] | [ 🔌  🧹  ❄️  🥧  🎧  ⚙️  ⏻ ]
  pinned apps + running window indicators       utility buttons (from old waybar)
```

### App Section
- Pinned apps: kitty, nautilus, zen-browser, chromium, obsidian
- Running indicator: colored dot below icon when app has open windows
- Active window indicator: brighter dot or icon highlight
- Click → focus or launch

### Utility Buttons (moved from waybar right)
| Button | Action |
|--------|--------|
| 🔌 USB | `hypr-usb-menu` |
| 🧹 MemClean | `memclean-dev` |
| ❄️ NixClean | nixclean script |
| 🥧 Pi Status | `waybar-pi-status` logic |
| 🎧 Headset | `hypr-bluetooth-reconnect` |
| ⚙️ Config | `hypr-config-editor` |
| ⏻ Logout | `hypr-power-menu` |

### Visual Style
- Same Material You solid as top bar
- `border-radius: 12px`, floating with margin
- App icons: 38px, utility buttons: 24px with SVG icons

### Auto-hide
- Dock visible by default (always-on-top, layer: bottom)
- Auto-hide toggle available via keybind or utility button

---

## Matugen Integration

### New Template
`config/shared/.config/ags/ags-colors.css.jinja2`

Maps matugen palette variables to CSS custom properties consumed by all AGS widgets:
```css
@define-color base {{ colors.background }};
@define-color surface0 {{ colors.surface_variant }};
@define-color primary {{ colors.primary }};
/* ... same pattern as existing waybar orgm-current.css */
```

### Pipeline Hook
`orgm-themes` apply-colors step adds AGS CSS generation alongside existing waybar/swaync step. After wallpaper change → matugen runs → AGS colors regenerated → `ags request refresh` signal.

---

## Autostart Change (Phase 10)

In `config/shared/.config/hypr/lua/autostart.lua`, swap:
```lua
-- Remove:
"sh -lc '$HOME/.local/bin/hypr-display-targets ensure && $HOME/.local/bin/waybar-watch ~/.config/waybar-hypr'",
"sh -lc '$HOME/.local/bin/hypr-nwg-dock 2>/tmp/hypr-nwg-dock.log'",

-- Add:
"sh -lc 'ags run ~/.config/ags/ 2>/tmp/ags.log'",
```

---

## Implementation Phases

| Phase | Deliverable | Validates |
|-------|-------------|-----------|
| 1 | Branch + AGS scaffold + matugen template | `ags run` starts, colors load |
| 2 | Top bar: workspaces + clock | Workspaces switch, time updates |
| 3 | Top bar: right modules (audio, net, bt) | Icons show, clicks open menus |
| 4 | Specs hover panel (rings) | All 7 rings show live data |
| 5 | Wallpaper dropdown (grid) | Thumbnails load, random/video work |
| 6 | Help panel (keybindings + sysinfo) | Keybindings render, info shows |
| 7 | Dock: pinned apps + running indicators | Apps launch/focus, dots update |
| 8 | Dock: utility buttons | All 7 buttons call correct scripts |
| 9 | Animations + transitions polish | Hover/click transitions smooth |
| 10 | Autostart swap: waybar → AGS | Cold boot uses AGS only |

Each phase ends with visual sign-off before proceeding. Waybar stays live on master throughout.

---

## Files Created

```
config/shared/.config/ags/
├── app.ts                    # AGS entry point
├── widget/
│   ├── Bar.tsx               # Top bar
│   ├── Dock.tsx              # Bottom dock
│   ├── SpecsPanel.tsx        # Hover specs with rings
│   ├── WallpaperMenu.tsx     # Wallpaper dropdown
│   └── HelpPanel.tsx         # Help panel
├── service/
│   ├── SystemMetrics.ts      # CPU/GPU/RAM/SWAP/SSD polling
│   └── Workspaces.ts         # Hyprland workspace state
├── style/
│   ├── main.css              # Base styles
│   └── ags-colors.css        # Generated by matugen (gitignored)
└── ags-colors.css.jinja2     # Matugen template (tracked)
```

---

## Prerequisites

- `ags` v2 / Astal must be installed on host (`nix-env` or NixOS package)
- GPU metrics: detects `nvidia-smi` first, falls back to AMD sysfs (`/sys/class/drm/*/device/gpu_busy_percent`)

## Out of Scope

- Notification center (swaync stays)
- Lock screen (hyprlock stays)
- Rofi menus (unchanged, called from AGS buttons)
- NixOS module for AGS (tracked separately)
