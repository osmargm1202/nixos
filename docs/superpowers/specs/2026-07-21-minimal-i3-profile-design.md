# Minimal i3 Profile Design

## Goal

Convert the shared i3 profile used by `lenovo-i3`, `orgm-i3`, `ero-i3`, `jarq-i3`, and generic `i3` into a minimal X11 desktop built around i3bar, a date/time-only `i3status`, and portable daily shortcut parity with Hyprland.

The profile must not use Picom, Polybar, Conky, Waybar, or Hyprland helpers. It keeps existing i3-native equivalents, Rofi, Kitty, Dunst, NetworkManager/Bluetooth/removable-disk tray applets, and a persistent Feh wallpaper workflow.

## Decisions

- Apply the minimal design to every i3 output, not only Lenovo.
- Remove Picom, Polybar, and Conky packages, startup commands, dotfile paths, helpers, tests, and profile artifacts.
- Use i3's native `bar` with `status_command i3status`; show only a Spanish weekday/date and a separate 12-hour AM/PM time block.
- Restore active daily Hyprland shortcut behavior with i3/X11 equivalents, but do not port `hypr-menu`, Waybar/SwayNC/NWG operations, unused helpers, autostart daemons, or theme tooling.
- Keep `nm-applet`, `blueman-applet`, and `udiskie` in session startup.
- Use Dunst with popups, history/DND bindings, and volume/microphone OSD.
- Do not add SwayNC or an i3 notification-center clone.
- Disable the G213 OpenRGB notification observer on Lenovo because that host has no G213.

## Session and Bar

The existing getty autologin and `startx` flow remains unchanged. The i3 configuration adds one native bar:

```text
bar {
  status_command i3status
  tray_output primary
}
```

The bar owns workspace buttons and the tray. A minimal i3status configuration has exactly two `tztime` blocks: Spanish `%A %d/%m/%Y` and English-locale `%I:%M %p`, separated by ` · `. This mixed-locale split is required because `es_DO.UTF-8` does not provide a reliable AM/PM marker. Battery, network, CPU/load, memory/disk, and temperature are intentionally omitted. No custom watcher or JSON helper is used.

## Helper Scope

Keep the existing i3-native helpers for Rofi, files, clipboard, SSH, menus, power profiles, keyboard layout, hotkeys, and config editing. Add daily equivalents for Zen, Obsidian, Pi prompt, calculator, devices, wallpaper, help, and direct power actions. Rofi must be built with the `rofi-calc` plugin and invoked through `i3-calc`; installing the plugin as a separate package is insufficient with Rofi 2.

The helper audit counted 55 executable Hyprland-profile helpers: 22 already matched, 15 portable gaps, and 18 compositor/panel-specific omissions. The approved daily scope closes active keyboard and menu behavior while leaving eight optional functions outside scope: battery alerts, Bluetooth auto-reconnect, stale/unbound smart-run, container autostart, Discord autostart, theme chooser, and webapp maker/remover.

Remove:

- `i3-polybar-launch`;
- `i3-status-battery`;
- `i3-status-cpu-temp`;
- `i3-status-gpu-temp`;
- `i3-wallpaper-random`, replaced by the narrower persistent wallpaper helper described below.

Move compositor-independent `volume-osd` and `mic-volume-osd` to shared dotfiles so Hyprland and i3 use one implementation.

## Persistent Wallpaper

Create `i3-wallpaper` with three operations:

- `--set FILE`: validate one local image, canonicalize it, apply `feh --bg-fill`, and persist the path;
- `--restore`: apply the persisted file when valid, otherwise choose and persist a random image;
- `--random`: choose, apply, and persist a random image from `${I3_WALLPAPER_DIR:-$HOME/.config/wallpapers}`.

State lives at `${XDG_STATE_HOME:-$HOME/.local/state}/i3/wallpaper`. Feh is invoked without `--no-fehbg`, so `~/.fehbg` remains a compatible secondary record. i3 starts `i3-wallpaper --restore` once per session.

Add executable Nautilus script:

```text
~/.local/share/nautilus/scripts/Set as Wallpaper
```

It accepts exactly one local selection from `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` and delegates to `i3-wallpaper --set`. Validation and persistence remain centralized in the helper.

## Notifications

Dunst remains the only i3 notification daemon.

Fix its configuration to:

- use PATH-resolved `xdg-open` and `rofi`, never `/usr/bin` paths;
- avoid user-specific `/home/osmar` icon paths;
- enable progress bars for OSD value hints;
- retain notification history and action support.

Bindings:

- `Mod+N`: pop the newest notification from Dunst history;
- `Mod+Shift+N`: toggle DND through `dunstctl set-paused toggle`.

Audio keys call shared `volume-osd` and `mic-volume-osd`, which continue using `pamixer` and synchronized `notify-send` hints.

The global `openrgb-notify` user service is guarded with `hostName != "lenovo"`. Other hosts retain existing G213 behavior.

## Ownership and Cleanup

Home Manager deploys only the retained i3, Rofi, Dunst, and helper paths. Delete the i3 profile's Picom, Polybar, and Conky directories and remove their manifest entries where they are no longer owned.

Unrelated Hyprland helpers remain intact for Hyprland profiles. Omission from i3 does not mean deletion from Hyprland.

## Testing

Static/TDD contracts must verify:

- no Picom, Polybar, Conky, Waybar, or `hypr-*` references in the i3 profile;
- native i3bar invokes `i3status`, owns the tray, and exposes only the requested mixed-locale date/time blocks;
- Rofi is plugin-wrapped and Mod+C invokes a working `i3-calc`;
- active daily Zen/Chromium/Obsidian/Pi, notification, media, window, workspace, device, help, and power bindings have i3 equivalents;
- selected applets remain in startup;
- obsolete panel/status helpers and dotfile paths are absent;
- wallpaper set/restore/random behavior with mocked Feh and notifications;
- Nautilus script delegates one selected path and rejects invalid selection;
- Dunst paths are portable, progress bars enabled, and history/DND bindings exist;
- shared OSD helpers remain valid for both desktops;
- Lenovo excludes the G213 observer while other hosts retain it.

No assistant-run full Nix build or broad evaluation is required; the user performs final build, boot, and physical validation.
