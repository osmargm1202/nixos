# Hyprland shared theme workflow

Goal: generate theme files once, track them under `config/shared`, and sync the same defaults to every host with `orgm-dot`.

## Recommended layout

```text
config/shared/.config/hypr/themes/
  catppuccin-macchiato.conf
  catppuccin-latte.conf
  generated/
    current.conf
config/shared/.config/rofi/themes/
  catppuccin-macchiato.rasi
config/shared/.config/waybar-hypr/themes/
  catppuccin-macchiato.css
```

## Tool choice

- `matugen`: best if wallpaper-derived colors should generate multiple app templates.
- `wallust`: simpler, fast wallpaper color extraction.
- `pywal16`: legacy-compatible, many existing templates, but less Nix-native.

Use one generator for generated themes. Keep hand-written preset themes tracked separately.

## Shared preset model

1. Commit curated presets under `config/shared`.
2. Use one symlink/current file per app:
   - `~/.config/hypr/themes/current.conf`
   - `~/.config/waybar-hypr/theme.css`
   - `~/.config/rofi/theme.rasi`
3. A script changes the current preset and reloads apps:

```bash
hyprctl reload
pkill -SIGUSR2 waybar || true
```

## Wallpaper-generated model

1. Pick wallpaper.
2. Run generator into `~/.cache/hypr-theme/generated` first.
3. Review output.
4. Copy approved result to `config/shared/.config/...` only when it should become shared default.

Do not commit random generated cache output directly. Commit curated themes only.
