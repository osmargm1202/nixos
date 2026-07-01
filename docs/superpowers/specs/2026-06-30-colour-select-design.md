# ColourSelect — Theme Chooser Design

**Date:** 2026-06-30
**Repo:** osmargm1202/shell (fork of caelestia-dots/shell)
**Replaces:** stub `ColourSelect.qml` ("Page under construction")

---

## Problem

The `modules/nexus/pages/wallandstyle/ColourSelect.qml` is a non-functional placeholder. The old `controlcenter/appearance` pane was removed on 2026-06-07 when the nexus replaced the control center. No colour selection UI exists in the current shell.

---

## Solution Overview

Replace the stub with a working theme chooser. Two colour sources:

1. **From Wallpaper** — activates `dynamic` mode; matugen auto-derives the M3 palette from the current wallpaper (existing caelestia behaviour, no changes needed to this path)
2. **Predefined Themes** — fixed seed-color themes defined in `themes/predefined.json` in the fork repo; matugen generates the full M3 palette from the seed color

Per-mode persistence: each dark/light mode saves its own theme selection. Switching modes auto-applies the saved theme for that mode.

---

## Architecture

### New / modified files

```
osmargm1202/shell
├── services/ThemeEngine.qml          [NEW — pragma Singleton]
├── modules/nexus/pages/wallandstyle/
│   └── ColourSelect.qml              [REPLACE stub]
└── themes/
    └── predefined.json               [NEW — theme data]
```

No changes needed to `Colours.qml` or `GSFLoader.qml`: ThemeEngine is a `pragma Singleton` and observes `Colours.light` directly via import. Quickshell auto-discovers Singletons at startup.

### Component responsibilities

**`ThemeEngine.qml`** (Quickshell Singleton):
- Loads `themes/predefined.json` at startup via `FileView`
- Exposes: `themeList`, `currentDarkTheme`, `currentLightTheme`, `activeTheme` (computed from `Colours.light`)
- `applyTheme(id)`: writes to `GlobalConfig` (shell.json `colours.darkTheme` / `colours.lightTheme`) and calls the caelestia CLI
- Observes `Colours.light` directly → auto-applies saved theme when mode changes

**`ColourSelect.qml`** (pure UI, consumes ThemeEngine):
- Section 1 — Source selector: two cards ("From Wallpaper" / "Custom Theme"), mutually exclusive
- Section 2 — Theme grid (visible only when Custom Theme selected): one card per theme with 2×2 color swatch (primary, secondary, bg, surface); swatches reflect **current mode** (dark or light) and update live when mode changes
- Status row at bottom: "🌙 Dark: Teal · ☀️ Light: Teal"

**`themes/predefined.json`**:
- Array of theme objects (see Data Model below)
- Shipped in the fork repo; adding a theme = edit JSON + push + nixos rebuild

---

## Data Model

### `themes/predefined.json`

```json
{
  "themes": [
    {
      "id": "teal",
      "name": "Teal",
      "seedColorDark": "25856e",
      "seedColorLight": "006b57",
      "preview": {
        "dark":  { "primary": "62bba2", "secondary": "abcec1", "bg": "101413", "surface": "1c211f" },
        "light": { "primary": "006b57", "secondary": "3d6b60", "bg": "f0f7f5", "surface": "e4f2ef" }
      }
    }
  ]
}
```

- `seedColorDark` / `seedColorLight`: hex seed fed to matugen to generate the full M3 palette
- `preview.*`: the 4 key colors shown in the swatch (pre-computed, no runtime matugen call needed for display)
- Initial themes: "Teal" (dark seed from current waybar/matugen scheme, `primary_paletteKeyColor: 25856e`)

### `shell.json` additions

```json
{
  "colours": {
    "darkTheme": "teal",
    "lightTheme": "teal"
  }
}
```

- Value `"dynamic"` means "From Wallpaper" mode
- Default (if key absent): `"dynamic"` for both modes

---

## CLI Integration

### Applying a predefined theme
```
caelestia scheme gen --color <seedColor>
```
Calls matugen with the fixed seed color to generate the M3 palette, then activates it. This is the same mechanism as dynamic mode but with a fixed input color instead of the wallpaper.

> **Implementation note:** Verify exact flag during implementation — may be `caelestia scheme gen --colour` or `caelestia scheme set --color`. Check caelestia-dots/cli Python source at implementation time.

### Applying dynamic (From Wallpaper)
No CLI call needed — set `colours.darkTheme = "dynamic"` in GlobalConfig. The existing `Wallpapers.qml` → `caelestia wallpaper` flow already handles matugen regeneration on wallpaper change.

---

## UI Behaviour

| Action | Result |
|---|---|
| Select "From Wallpaper" | `darkTheme`/`lightTheme` = `"dynamic"`, theme grid hides |
| Select "Custom Theme" | theme grid appears, shows last active predefined theme |
| Click theme card | applies theme for current mode only, saves to GlobalConfig |
| Toggle dark ↔ light | ThemeEngine auto-applies saved theme for new mode |
| Hover theme card | shows name + seed colors (no preview colour change for v1) |

---

## Out of Scope (v1)

- Live colour preview on hover (colour morphing to preview theme before applying)
- In-app theme creation / colour picker
- Light-only or dark-only themes (all themes must define both variants)
- Sync themes across machines (shell.json is local)

---

## Files to Clone Locally

The shell fork (`osmargm1202/shell`) must be cloned to make changes, then pushed to GitHub, and the NixOS flake.lock updated to the new commit.

```
git clone https://github.com/osmargm1202/shell /tmp/caelestia-shell
```
