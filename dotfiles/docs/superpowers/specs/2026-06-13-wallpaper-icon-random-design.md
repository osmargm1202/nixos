# Wallpaper icon random click design

Date: 2026-06-13

## Goal

Clicking the Waybar wallpaper icon should immediately select a random wallpaper and apply it to all Hyprland screens.

## Current state

- Waybar-Hypr defines `custom/wallpaper` in `config/shared/.config/waybar-hypr/config`.
- The original left click ran `orgm-wallpaper pick`, which opened the picker instead of changing wallpaper immediately.
- The first implementation used `hypr-random-wallpaper next`, but that helper targets Hyprpaper. Current Hyprland session uses `orgm-wallpaper daemon`; `hyprctl hyprpaper` cannot connect.
- `orgm-wallpaper random-static` is the active backend command for random static wallpapers.

## Chosen approach

Use the active `orgm-wallpaper` backend directly from Waybar.

Waybar `custom/wallpaper` changes:

- `on-click`: `orgm-wallpaper random-static`
- `on-click-right`: `orgm-wallpaper pick`
- `tooltip-format`: `Wallpaper aleatorio`

No new wrapper is needed. No changes to the wallpaper daemon or keybindings are included.

## Alternatives considered

1. Use `hypr-random-wallpaper next`. Rejected after live debugging because Hyprpaper is not running in the current backend.
2. Create a new wrapper for Waybar click behavior. This adds indirection without current need.

## Testing

Add a focused helper test assertion that `custom/wallpaper` uses `orgm-wallpaper random-static` for left click and `orgm-wallpaper pick` for right click.

Run:

```bash
bash tests/helpers/waybar-hypr-custom-icons.bats.sh
```

Then inspect and apply dotfiles with:

```bash
distrobox-host-exec orgm-dot diff
distrobox-host-exec orgm-dot sync
```

## Acceptance criteria

- Clicking the wallpaper icon in Waybar-Hypr changes to a random wallpaper.
- The random wallpaper applies through the active `orgm-wallpaper` backend.
- Waybar config test covers left and right click commands.
- Dotfiles diff is reviewed and synced.
