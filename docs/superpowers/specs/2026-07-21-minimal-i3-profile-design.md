# Minimal i3 Profile Design

## Goal

Convert the shared i3 profile used by `lenovo-i3`, `orgm-i3`, `ero-i3`, `jarq-i3`, and generic `i3` into a minimal X11 desktop built around i3bar, date/time-only Bumblebee Status with Nord Powerline, and portable daily shortcut parity with Hyprland.

The profile must not use Picom, Polybar, Conky, Waybar, or Hyprland helpers. It keeps existing i3-native equivalents, Rofi, Kitty, Dunst, NetworkManager/Bluetooth/removable-disk tray applets, and a persistent Feh wallpaper workflow.

## Decisions

- Apply the minimal design to every i3 output, not only Lenovo.
- Remove Picom, Polybar, and Conky packages, startup commands, dotfile paths, helpers, tests, and profile artifacts.
- Use i3's native bar with Bumblebee Status modules `shortcut date time` and theme `nord-powerline`; preserve Spanish `%A %d/%m/%Y` and 12-hour `%I:%M %p` formats with separate locales. The shortcut is a clickable caffeine toggle.
- Restore active daily Hyprland shortcut behavior with i3/X11 equivalents, but do not port `hypr-menu`, Waybar/SwayNC/NWG operations, unused helpers, autostart daemons, or theme tooling.
- Keep `nm-applet`, `blueman-applet`, `udiskie`, and one PipeWire/PulseAudio volume applet in session startup. Pasystray uses its packaged XDG autostart and must not also be launched explicitly by i3.
- Use Dunst with popups, history/DND bindings, volume/microphone OSD, and an eight-second timeout for every urgency; no notification remains permanent.
- Do not add SwayNC or an i3 notification-center clone.
- Disable the G213 OpenRGB notification observer on Lenovo because that host has no G213.
- Expose only normal split and grouped/tabbed layouts: `Mod+G` enters grouped tabs and `Mod+Shift+G` returns to normal; do not reserve `Mod+S` for scratchpad or stacking.
- Install the runtime-selected Colloid/Catppuccin GTK assets in i3 so Nautilus does not fall back to default icons.
- Bind Lenovo XF86 audio, microphone, brightness, WLAN, and RFKill symbols; all helper commands must remain independently runnable.
- Require a normal username/password login on TTY1, then start i3 automatically through `startx`; PAM login owns GNOME Keyring startup/unlock and no getty autologin is permitted.
- After Home Manager links a new generation during a live i3 switch, reload the running i3 instance through its IPC socket so keyboard grabs remain active; never restart i3 or reload Hyprland from activation.
- Use Rofi for clipboard selection from both `Mod+V` and the main menu.
- Enable Autorandr for DRM hotplug and suspend/resume detection. Saved profiles remain runtime-owned under `~/.config/autorandr`; unmatched monitor sets fall back to a horizontal layout.
- Use a neutral, borderless `i3-menu.rasi` with the same palette, dimensions, typography, padding and icon sizing as the active Hyprland Rofi menus; never deploy a `hypr-menu` artifact in i3.
- `Mod+W` follows Hyprland behavior: launch Zen when absent, otherwise create a blank tab and focus its i3 window.
- Use packaged `meskarune/i3lock-fancy` to capture and blur the live desktop with its lock icon and Spanish prompt; expose caffeine through the bar plus `Mod+Shift+C`.
- Run the pinned `morrolinux/i3expo-ng` screenshot daemon once per i3 session. `Mod+Escape` signals its Expo overview, `Alt+Tab` remains the themed Rofi window selector, and `Mod+Tab` uses `workspace back_and_forth`.
- Install `ffcast` for X11 region recording. Enable UPower with its stock package for power telemetry and keep power-profiles-daemon for profile management.

## Session and Bar

Getty presents a normal login prompt on TTY1. After successful password authentication, the Fish login shell runs `startx /etc/X11/xinit/xinitrc`; PAM uses the same password to unlock GNOME Keyring before X starts. Exiting i3 ends that login session and returns to getty. The i3 configuration adds one native bar:

```text
bar {
  font pango:Noto Sans 14
  height 36
  status_command bumblebee-status -m shortcut date time -p shortcut.cmds="i3-caffeine-toggle" shortcut.labels="" date.format="%A %d/%m/%Y" date.locale="es_DO.UTF-8" time.format="%I:%M %p" time.locale="en_US.UTF-8" -i i3-clean -t nord-powerline
  tray_output primary
}
```

The 36px bar uses Noto Sans 14 for larger workspace labels and status text. Font Awesome and Symbols Nerd Font remain fallbacks for Nord Powerline separators. The `i3-clean` iconset removes date/time prefixes that overlap text. Pasystray provides one interactive volume icon through its packaged XDG autostart. Bumblebee adds one clickable coffee shortcut before date/time; battery, network, CPU/load, memory/disk, and temperature remain omitted.

## Helper Scope

Keep the existing i3-native helpers for themed Rofi, i3 Expo overview, persistent clipboard history, files, SSH, menus, power profiles, monitor profiles, keyboard layout, hotkeys, caffeine, lock routing, and config editing. Add daily equivalents for Zen, Obsidian, Pi prompt, calculator, devices, wallpaper, help, and direct power actions. Rofi must be built with the `rofi-calc` plugin and invoked through `i3-calc`; installing the plugin as a separate package is insufficient with Rofi 2.

The helper audit counted 55 executable Hyprland-profile helpers: 22 already matched, 15 portable gaps, and 18 compositor/panel-specific omissions. The approved daily scope closes active keyboard and menu behavior while leaving eight optional functions outside scope: battery alerts, Bluetooth auto-reconnect, stale/unbound smart-run, container autostart, Discord autostart, theme chooser, and webapp maker/remover.

Remove:

- `i3-polybar-launch`;
- `i3-status-battery`;
- `i3-status-cpu-temp`;
- `i3-status-gpu-temp`;
- `i3-wallpaper-random`, replaced by the narrower persistent wallpaper helper described below.

Move compositor-independent `volume-osd` and `mic-volume-osd` to shared dotfiles so Hyprland and i3 use one implementation.

## Monitor Profiles

`services.autorandr` installs the package, DRM hotplug rules, and suspend/resume hook. It selects profiles by EDID and uses Autorandr's virtual `horizontal` target when no saved profile matches. The packaged Autorandr XDG desktop is hidden in i3; i3 runs exactly one `i3-monitor-profile --apply` command at login so monitor selection and wallpaper restoration are serialized.

`Mod+P`, `Mod+Ctrl+,`, and Devices → Displays open `i3-monitor-profile`. Its menu provides ARandR configuration, detected-profile apply, current-profile save, and saved-profile load. ARandR only edits the current XRandR layout; saving through the helper is what makes Autorandr restore it later.

`~/.config/autorandr` is real runtime state and is listed under dotfiles `local_only`; Nix/Home Manager must never create, replace, or symlink it. The user configures the desired layout in ARandR, then chooses **Save current** with a stable profile name such as `mobile` or `docked`.

## Persistent Wallpaper

Create `i3-wallpaper` with three operations:

- `--set FILE`: validate one local image, canonicalize it, apply `feh --bg-fill`, and persist the path;
- `--restore`: apply the persisted file when valid, otherwise choose and persist a random image;
- `--random`: choose, apply, and persist a random image from `${I3_WALLPAPER_DIR:-$HOME/.config/wallpapers}`.

State lives at `${XDG_STATE_HOME:-$HOME/.local/state}/i3/wallpaper`. Feh is invoked without `--no-fehbg`, so `~/.fehbg` remains a compatible secondary record. `i3-monitor-profile --apply` restores this wallpaper only after Autorandr finishes, preventing XRandR from clearing a concurrently applied background.

Add executable Nautilus script:

```text
~/.local/share/nautilus/scripts/Set as Wallpaper
```

It accepts exactly one local selection from `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` and delegates to `i3-wallpaper --set`. Validation and persistence remain centralized in the helper.

## Lock Screen

`i3-lock` delegates every manual, idle, power-menu, and suspend-aware lock path to stock Nixpkgs `i3lock-fancy`. The package captures the X11 root window with Scrot, blurs it through ImageMagick, adds its adaptive lock icon and Spanish prompt, then invokes its wrapped `i3lock-color`. Its Nix closure supplies Bash, coreutils, fontconfig, Gawk, getopt, ImageMagick, Scrot, and `i3lock-color`; do not install standalone `i3lock-color`, because both packages expose `bin/i3lock`. A uniquely named `i3lock-color-fallback` wrapper provides a solid Nord lock if screenshot or ImageMagick preprocessing fails, including on the foregrounded `xss-lock --nofork` path.

## Notifications

Dunst remains the only i3 notification daemon.

Fix its configuration to:

- use PATH-resolved `xdg-open` and `rofi`, never `/usr/bin` paths;
- avoid user-specific `/home/osmar` icon paths;
- enable progress bars for OSD value hints;
- retain notification history and action support;
- set low, normal, and critical urgency timeouts to eight seconds.

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
- native i3bar invokes Bumblebee Status with caffeine/date/time modules, Nord Powerline, larger Noto typography, clean date/time icons, and the requested mixed-locale formats;
- Rofi is plugin-wrapped, borderless, uses the neutral Hyprland-parity theme everywhere, Mod+C invokes a working `i3-calc`, and Win+Alt+Space has a physical-keycode binding plus fallback;
- i3expo-ng is source/hash pinned, single-instance, receives `Mod+Escape`, while `Alt+Tab` remains Rofi and `Mod+Tab` is workspace back-and-forth;
- active daily Zen/Chromium/Obsidian/Pi, notification, media, window, workspace, device, help, and power bindings have i3 equivalents;
- normal/grouped layout bindings are explicit and scratchpad/stacking bindings are absent;
- Nautilus's selected icon theme is installed and its wallpaper action resolves the helper outside Nautilus's restricted PATH;
- XF86 audio/mic/brightness/WLAN bindings and the tray volume applet remain declared;
- `ffcast`, the UPower service/package, and power-profiles-daemon remain available for recording and energy management;
- selected applets remain in startup;
- obsolete panel/status helpers and dotfile paths are absent;
- wallpaper set/restore/random behavior with mocked Feh and notifications, serialized after Autorandr;
- every lock path uses packaged `i3lock-fancy`, its fast Scrot capture, Spanish prompt, `--nofork` forwarding, and secure solid-color fallback without a standalone `i3lock-color` collision;
- clipboard empty/populated history behavior and themed Rofi invocation;
- one Pasystray process source and functional caffeine state restoration;
- Nautilus script delegates one selected path and rejects invalid selection;
- Dunst paths are portable, progress bars enabled, history/DND bindings exist, and all urgency timeouts equal eight seconds;
- clipboard helper, `Mod+V`, and main menu all resolve through Rofi;
- Autorandr hotplug service, EDID matching, horizontal fallback, login restore, runtime profile save/load, and local-only ownership remain declared;
- all i3 outputs evaluate without getty autologin and the TTY1 startx/PAM keyring contract remains explicit;
- i3-only post-link activation discovers a live IPC socket and reloads, never restarts, the running window manager;
- shared OSD helpers remain valid for both desktops;
- Lenovo excludes the G213 observer while other hosts retain it.

No assistant-run full Nix build or broad evaluation is required; the user performs final build, boot, and physical validation.
