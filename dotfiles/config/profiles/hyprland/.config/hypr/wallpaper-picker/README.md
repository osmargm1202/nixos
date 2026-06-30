# ORGM GTK4 wallpaper picker

Standalone Python GTK4 wallpaper picker synced by `orgm-dot` through managed `.config/hypr`.

## Launch

```bash
hypr-wallpaper-picker         # auto theme
hypr-wallpaper-picker-dark    # force dark Waybar-Hypr palette
hypr-wallpaper-picker-light   # force light Waybar-Hypr palette
```

Direct app flags:

```bash
python3 ~/.config/hypr/wallpaper-picker/wallpaper_picker.py --theme dark --page-size 20 --monitor DP-1
```

## Dependencies

Runtime needs Python GTK4 PyGObject (`gi`) plus GTK4:

- Arch: `sudo pacman -S python-gobject gtk4`
- NixOS: add `python3Packages.pygobject3` and `gtk4` to the user/system environment, or rely on launcher `nix-shell`/`nix` fallback.

Launchers first use existing `python3` only when this succeeds:

```bash
python3 -c 'import gi; gi.require_version("Gtk", "4.0"); from gi.repository import Gtk'
```

If that import fails and `nix-shell` exists, launcher starts a transient shell with:

```bash
nix-shell -p 'python3.withPackages (ps: [ ps.pygobject3 ])' gtk4 gobject-introspection --run 'python3 ...'
```

## Troubleshooting

### `ModuleNotFoundError: No module named 'gi'`

Your current `python3` does not have PyGObject. Install the packages above or make sure `nix-shell` is available so launcher can provide `pygobject3`, `gtk4`, and `gobject-introspection` transiently.

## Backend contract

Picker delegates wallpaper actions to `orgm-wallpaper` only. It does not reimplement Hyprpaper/mpvpaper behavior and does not call `orgm-wallpaper pick` or picker-daemon.

Used commands:

- `orgm-wallpaper status [--monitor OUTPUT]`
- `orgm-wallpaper set-static PATH [--monitor OUTPUT]`
- `orgm-wallpaper set-video PATH [--monitor OUTPUT]`
- `orgm-wallpaper random-static [--monitor OUTPUT]`
- `orgm-wallpaper random-video [--monitor OUTPUT]`
- `orgm-wallpaper warm-page static PAGE PAGE_SIZE`
- `orgm-wallpaper warm-page video PAGE PAGE_SIZE`

## Data source

Preferred source:

```text
${XDG_STATE_HOME:-~/.local/state}/hypr-wallpaper/wallpaper-picker.json
```

Supported JSON shape:

```json
{
  "tabs": {
    "static": { "items": [{ "path": "/path/wall.jpg", "name": "Wall", "thumb": "/path/.thumb/wall.jpg.png" }] },
    "video": { "items": [{ "file": "/path/clip.mp4", "thumbnail": "/path/.thumb/clip.png" }] }
  },
  "monitors": [{ "name": "DP-1", "description": "Main display" }]
}
```

If JSON is missing, app scans:

- static: `~/Pictures/Wallpapers`
- video: `~/Videos/wallpapers`

Thumbnails are inferred next to each wallpaper in `.thumb/`.

## Style

Palette matches Waybar-Hypr defaults:

- font: `JetBrainsMono Nerd Font`
- radius: `12px`
- border: subtle `2px` surface border
- dark: `PANEL_BG=00000099`, `TEXT=cad3f5`, `BLUE=8aadf4`, `MAUVE=c6a0f6`, `SURFACE0=363a4f`
- light: `PANEL_BG=ffffffff`, `TEXT=111827`, `BLUE=0057d9`, `MAUVE=8839ef`, `SURFACE0=d1d5db`
