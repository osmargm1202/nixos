# Minimal i3 Profile Design

## Goal

Convert the shared i3 profile used by `lenovo-i3`, `orgm-i3`, `ero-i3`, `jarq-i3`, and generic `i3` into a portable X11 desktop built around native i3bar, a NixOS-adapted i3blocks status, and daily shortcut parity with Hyprland.

The profile uses animated Picom compositing but no Polybar, Conky, Waybar, or Hyprland helpers. It keeps existing i3-native equivalents, Rofi, Kitty, Dunst, NetworkManager/Bluetooth/removable-disk tray applets, and persistent Feh image plus XWinWrap/mpv video wallpapers.

## Decisions

- Apply the minimal design to every i3 output, not only Lenovo.
- Keep Polybar and Conky removed. Run `picom-pijulius` through a declarative systemd user service and store-generated native config; do not restore a runtime-owned `~/.config/picom` tree.
- Use i3's native transparent bar with i3blocks for caffeine, keyboard layout, brightness, volume, microphone, disk, network, memory, CPU, temperature, battery, and date/time. Preserve Spanish `%A %d/%m/%Y` and 12-hour `%I:%M %p` formats with separate locales.
- Restore active daily Hyprland shortcut behavior with i3/X11 equivalents, but do not port `hypr-menu`, Waybar/SwayNC/NWG operations, unused helpers, autostart daemons, or theme tooling.
- Keep `nm-applet`, `blueman-applet`, `udiskie`, and one PipeWire/PulseAudio volume applet in session startup. Pasystray uses its packaged XDG autostart and must not also be launched explicitly by i3.
- Use Dunst with popups, history/DND bindings, volume/microphone OSD, and an eight-second timeout for every urgency; no notification remains permanent.
- Do not add SwayNC or an i3 notification-center clone.
- Disable the G213 OpenRGB notification observer on Lenovo because that host has no G213.
- Expose only normal split and grouped/tabbed layouts: `Mod+G` enters grouped tabs and `Mod+Shift+G` returns to normal; do not reserve `Mod+S` for scratchpad or stacking.
- Install LXAppearance plus the runtime-selected Colloid/Catppuccin GTK assets in i3 so GTK appearance can be changed interactively and Nautilus does not fall back to default icons. Nautilus main windows use normal i3 tiling and must not be forced floating.
- Bind Lenovo XF86 audio, microphone, brightness, WLAN, and RFKill symbols; all helper commands must remain independently runnable.
- Require a normal username/password login on TTY1, then start i3 automatically through `startx`; PAM login owns GNOME Keyring startup/unlock and no getty autologin is permitted.
- After Home Manager links a new generation during a live i3 switch, reload the running i3 instance through its IPC socket so keyboard grabs remain active; never restart i3 or reload Hyprland from activation.
- Use Rofi for clipboard selection from both `Mod+V` and the main menu; keep its dedicated menu compact at eight rows with 5px row padding and 24px icons.
- Enable Autorandr for DRM hotplug and suspend/resume detection. Saved profiles remain runtime-owned under `~/.config/autorandr`; unmatched monitor sets fall back to a horizontal layout.
- Use a neutral, borderless `i3-menu.rasi` with the same palette, dimensions, typography, padding and icon sizing as the active Hyprland Rofi menus; never deploy a `hypr-menu` artifact in i3.
- `Mod+W` follows Hyprland behavior: launch Zen when absent, otherwise create a blank tab and focus its i3 window.
- Use packaged `meskarune/i3lock-fancy` to capture and blur the live desktop with its lock icon and Spanish prompt; expose caffeine through the bar plus `Mod+Shift+C`.
- `Alt+Tab` remains themed Rofi window selector, and `Mod+Tab` uses `workspace back_and_forth`.
- Install `ffcast` for X11 region recording. Enable UPower with its stock package for power telemetry and keep power-profiles-daemon for profile management.

## Session and Bar

Getty presents a normal login prompt on TTY1. After successful password authentication, the Fish login shell runs `startx /etc/X11/xinit/xinitrc`; PAM uses the same password to unlock GNOME Keyring before X starts. Exiting i3 ends that login session and returns to getty. The i3 configuration adds one native bar:

```text
bar {
  i3bar_command i3bar --transparency
  font pango:Noto Sans, JetBrainsMono Nerd Font 18
  height 28
  status_command /run/current-system/sw/bin/i3blocks -c "$HOME/.config/i3blocks/config"
  tray_output primary
}
```

The 28px bar uses Noto Sans 18 with JetBrainsMono Nerd Font fallback. `i3bar --transparency`, a 56% opaque bar background, alternating 70% opaque Nord i3blocks backgrounds, and RGBA workspace colors expose Picom blur without fading text. Font Awesome and Nerd Font provide block icons. Pasystray remains the single tray volume applet.

The block order and separatorless icon style adapt [krasiyan's i3blocks configuration](https://github.com/krasiyan/dotfiles/blob/009b6ce04029ba4ee1878ad30a5cbfee95f0f630/.i3/i3blocks.conf#L23-L139), while `i3blocks-status` replaces its Ubuntu- and hardware-specific scripts. Do not port `aptitude`, passwordless `ufw`, fixed `wlp4s0`, `Tctl`, or `/usr/share/i3blocks` assumptions. Every command routes through one deployed helper, discovers interfaces/batteries/thermal zones at runtime, uses `brightnessctl` for display brightness, and keeps clickable caffeine, brightness, audio, network, and calendar actions.

## Picom Visual Effects

NixOS owns a native libconfig file in the store and installs `picom-pijulius`. Direct libconfig is required because this nixpkgs pin serializes Nix lists with square brackets, while Picom requires parentheses for rule and animation group lists. i3 explicitly starts the custom user service so manual `startx` sessions do not depend on graphical target propagation. GLX, VSync, dual-Kawase blur, 12px rounded corners, soft shadows, rule-based opacity of 0.92 for active windows and 0.84 for inactive windows, 0.88 menu opacity, fades, appear/disappear animations, and experimental geometry transitions are enabled. Fullscreen, desktop, and lock windows remain opaque, square, unblurred, and shadowless; lock transitions are effectively instant. Dock windows keep square edges and no shadow while allowing blur through i3bar's RGBA surface.

## Helper Scope

- Keep the existing i3-native helpers for themed Rofi, persistent clipboard history, files, SSH, menus, power profiles, monitor profiles, keyboard layout, hotkeys, caffeine, lock routing, and config editing.

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

Create `i3-wallpaper` with shared and per-monitor operations:

- `--set FILE`: validate one local image or video, apply it to every active output, persist it as the shared fallback, and clear per-output overrides;
- `--set-active FILE`: apply the image or video only to the output under the pointer, falling back to the focused-window center, primary output, then first active output;
- `--set-output OUTPUT FILE`: apply an explicit image/video output override;
- `--restore`: rebuild the complete active-output image list in XRandR monitor order and persist any legacy/fallback migration;
- `--random`: choose one random image for every output;
- `--random-active`: choose a random image only for the pointer/focused output.

Shared fallback state retains its compatibility mirror at `${XDG_STATE_HOME:-$HOME/.local/state}/i3/wallpaper`; authoritative connector/default image or video state is published as an atomic generation through `${XDG_STATE_HOME:-$HOME/.local/state}/i3/wallpapers`, with connector files at `wallpapers/OUTPUT` and `.default` for shared fallback. A per-user `flock` serializes Autorandr, Nautilus, and keyboard invocations. Disconnected outputs retain their assignments and recover them when that connector returns. Existing single-file state migrates automatically. Feh receives one ordered image per active Xinerama output and is invoked without `--no-fehbg`, so `~/.fehbg` remains a compatible secondary record. Video outputs receive a Nord placeholder underneath one isolated `setsid` XWinWrap/mpv process group per monitor. PID plus `/proc` starttime tracking prevents reused-PID kills; replacing media or restoring after Autorandr stops only validated managed groups and restarts videos at current XRandR geometry. `i3-monitor-profile --apply` restores wallpapers only after Autorandr finishes, preventing XRandR from clearing a concurrently applied background.

Add executable Nautilus script:

```text
~/.local/share/nautilus/scripts/Set as Wallpaper
```

It accepts exactly one local image or video selection from `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` and delegates to `i3-wallpaper --set-active`. Pointer position selects the target monitor; focused-window geometry is the fallback. Validation, full-layout Feh application, and persistence remain centralized in the helper. Home Manager activation removes any stale copy for every profile, then installs it as a real executable file after `linkGeneration` only for i3. Nautilus 50 therefore reliably exposes **Scripts → Set as Wallpaper** in i3 without leaking a broken action into other profiles.

## Lock Screen

`i3-lock` delegates every manual, idle, power-menu, and suspend-aware lock path to stock Nixpkgs `i3lock-fancy`. The package captures the X11 root window with Scrot `-z -o`, blurs it through ImageMagick, adds its adaptive lock icon and Spanish prompt, then invokes its wrapped `i3lock-color`. The overwrite flag is mandatory because upstream creates the PNG with `mktemp` before invoking Scrot; without it, Scrot writes a suffixed file and fancy preprocessing falls through to the gray safety lock. Its Nix closure supplies Bash, coreutils, fontconfig, Gawk, getopt, ImageMagick, Scrot, and `i3lock-color`; do not install standalone `i3lock-color`, because both packages expose `bin/i3lock`. A uniquely named `i3lock-color-fallback` wrapper provides a solid Nord lock if screenshot or ImageMagick preprocessing fails, including on the foregrounded `xss-lock --nofork` path.

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

Home Manager deploys only retained i3, Rofi, Dunst, and helper paths. Keep old i3 Picom, Polybar, and Conky dotfile directories absent: Picom config is generated in the Nix store and passed to its user service, while Polybar and Conky remain removed.

Unrelated Hyprland helpers remain intact for Hyprland profiles. Omission from i3 does not mean deletion from Hyprland.

## Testing

Static/TDD contracts must verify:

- no Polybar, Conky, Waybar, or `hypr-*` references in the i3 profile and no runtime Picom dotfile tree;
- `picom-pijulius` provides GLX/VSync, blur, rounded corners, shadows, strong transparency, fades, appear/disappear and geometry animations with safe fullscreen/lock exceptions;
- native transparent i3bar invokes portable separatorless i3blocks with complete system/audio/input/date blocks, translucent Nord backgrounds, larger Noto typography, and the requested mixed-locale formats;
- Rofi is plugin-wrapped, borderless, uses the neutral Hyprland-parity theme everywhere, Mod+C invokes a working `i3-calc`, and Win+Alt+Space has a physical-keycode binding plus fallback;
- `Alt+Tab` remains themed Rofi, while `Mod+Tab` is workspace back-and-forth.
- active daily Zen/Chromium/Obsidian/Pi, notification, media, window, workspace, device, help, and power bindings have PATH-safe i3 equivalents through the deployed `i3-run`;
- normal/grouped layout bindings are explicit and scratchpad/stacking bindings are absent;
- LXAppearance and Nautilus's selected icon theme are installed, its main window is tiled, and its real-file wallpaper action resolves the helper outside Nautilus's restricted PATH;
- XF86 audio/mic/brightness/WLAN bindings and the tray volume applet remain declared;
- `ffcast`, the UPower service/package, and power-profiles-daemon remain available for recording and energy management;
- selected applets remain in startup;
- obsolete panel/status helpers and dotfile paths are absent;
- shared and per-output image/video wallpaper set/restore/random behavior, pointer/focus output targeting, XRandR/Feh ordering, XWinWrap/mpv lifecycle, legacy migration, and serialization after Autorandr;
- every lock path uses packaged `i3lock-fancy`, overwrite-safe Scrot capture, Spanish prompt, `--nofork` forwarding, and secure solid-color fallback without a standalone `i3lock-color` collision;
- clipboard empty/populated history behavior and themed Rofi invocation;
- one Pasystray process source and functional caffeine state restoration;
- Nautilus script delegates one selected path to active-output targeting and rejects invalid selection;
- Dunst paths are portable, progress bars enabled, history/DND bindings exist, and all urgency timeouts equal eight seconds;
- clipboard helper, `Mod+V`, and main menu all resolve through Rofi;
- Autorandr hotplug service, EDID matching, horizontal fallback, login restore, runtime profile save/load, and local-only ownership remain declared;
- all i3 outputs evaluate without getty autologin and the TTY1 startx/PAM keyring contract remains explicit;
- i3-only post-link activation discovers a live IPC socket and reloads, never restarts, the running window manager;
- shared OSD helpers remain valid for both desktops;
- Lenovo excludes the G213 observer while other hosts retain it.

No assistant-run full Nix build or broad evaluation is required; the user performs final build, boot, and physical validation.
