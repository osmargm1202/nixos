# App, Waybar, and Hyprland Repair Design

Fix broken native/Flatpak launchers, make USB handling safe and visible in Waybar, add a Waybar entry for `nixclean`, and make Hyprland workspace transitions host-configurable from the main menu.

## Quick path

1. Repair app sources of truth in both repositories:
   - NixOS Flatpak declarations mirror the Flatpaks installed on host `orgm`.
   - Dotfile launchers stop pointing at missing binaries or generation-specific `/nix/store` paths.
2. Replace the headset-only reconnect button with a safer USB menu:
   - storage/removable media are protected from USB unbind/bind;
   - folders can be opened or mounted via `udisksctl`/`udiskie` flow.
3. Add a `nixclean` Waybar button that opens a terminal and runs the existing Fish function.
4. Add a Hyprland transition picker in the main menu that saves a host preference and reloads Hyprland.

## Current findings

| Area | Evidence | Decision |
| --- | --- | --- |
| Zen | Host has user Flatpak `app.zen_browser.zen`; no native `zen`/`zen-browser` command. | Keep Zen helper Flatpak-first with native fallback. |
| Chromium webapps | Host has native `chromium`; Flatpak `org.chromium.Chromium` is declared in NixOS but not installed. | Keep webapp launchers on native `chromium`; remove Chromium Flatpak declaration. |
| Flatpak declarations | `flatpak.nix` contains apps not installed today and misses apps that are installed today. | Make `flatpak.nix` mirror current host Flatpak set. |
| Broken launchers | `orgmos.desktop` uses missing `orgmos`; `propuestas.desktop` uses missing `orgm`; `arch.desktop` embeds stale `/nix/store/.../distrobox`; `opencode-desktop-handler.desktop` points to missing `/usr/bin/opencode-desktop`. | Delete `orgmos`/`propuestas`; make `arch.desktop` use PATH `distrobox`; remove or hide missing opencode handler. |
| USB automount | `udisks2`, `gvfs`, and Nautilus exist; `udiskie` is not installed/active. Flash drive appears in Nautilus but does not automount. | Add `udiskie` user service and keep `udisksctl` available. |
| USB reconnect | `unbindheadset.fish` hardcodes `1-11.1` and current Waybar button only opens terminal running that function. | Replace with dynamic USB selector that never unbinds storage devices. |
| Waybar storage visibility | Waybar has no built-in dynamic removable-media module in this config. | Use custom Waybar script/module returning JSON status. |
| Hyprland animations | `look-and-feel.lua` hardcodes `workspaces` animation as `fade`. | Move workspace animation style behind host preference and menu picker. |

## Design decisions

### 1. Apps and package sources of truth

- Update `/home/osmarg/Hobby/nixos/nixos/flatpak.nix` so `packages` matches apps currently installed on host `orgm`:
  - keep `app.zen_browser.zen`, Gradia, Discord, Earth Pro, OBS, PokeMMO, Spotify, LauncherStudio, GdmSettings, Upscaler, Podman Desktop, Obsidian, Blender, GIMP, SimpleScan, Inkscape, LibreOffice;
  - correct Thunderbird from `org.mozilla.Thunderbird` to `net.thunderbird.Thunderbird`;
  - add `org.yuzu_emu.yuzu`;
  - remove missing/unwanted declarations: `org.chromium.Chromium`, Flatpak Steam, GNOME Papers, FileRoller, Apostrophe, Flatpak pavucontrol, Warehouse, StartupConfiguration, Sticky.
- Keep native browser webapps as `chromium --app=...` because native Chromium exists and is the selected direction.
- Delete broken `orgmos.desktop` and `propuestas.desktop` from host launcher directories.
- Replace stale Nix store path in `arch.desktop` with `distrobox enter arch` and `distrobox rm arch`.
- Remove or hide `opencode-desktop-handler.desktop` unless a valid handler binary is found during implementation.
- Keep `hypr-zen-new-window` Flatpak-first and verify it matches Zen Flatpak window class `app.zen_browser.zen`.

### 2. Waybar USB and cleanup controls

- Add NixOS packages/services needed for safe USB UX:
  - `udiskie` enabled as a user automount service;
  - `usbutils` for `lsusb`/diagnostics if missing;
  - keep `udisks2`, `gvfs`, and Nautilus.
- Replace hardcoded `unbindheadset.fish` behavior with a dynamic helper, proposed name: `hypr-usb-menu`.
- `hypr-usb-menu` responsibilities:
  - list USB devices from `/sys/bus/usb/devices`, `lsusb`, and block-device data from `lsblk`;
  - classify storage/removable media as protected;
  - show Rofi rows with clear labels: saved nickname when present, device type, vendor/product, and bus id;
  - allow right-click/secondary flow from Waybar to save or edit a nickname for a selected USB device so future reconnect prompts identify it clearly;
  - store nicknames in a small user config file keyed by stable USB identity (`vendor:product:serial` when available, otherwise bus id fallback);
  - for storage devices: mount/open folder with `udisksctl`/`xdg-open`/Nautilus, not USB unbind;
  - for non-storage devices: offer unbind, wait `HYPR_USB_REBIND_DELAY` seconds (`2` default), then bind;
  - notify success/failure and log command output under `~/.local/state/orgm-hypr/usb-menu.log`.
- Keep `unbindheadset.fish` only as compatibility wrapper that calls the new helper or remove it if no active callers remain.
- Add Waybar custom modules:
  - `custom/usb_devices`: JSON status script; shows icon only when USB/removable devices are present; left-click opens `hypr-usb-menu`; right-click opens nickname/edit + non-storage reconnect flow.
  - `custom/nixclean`: static broom/recycle icon; click opens `kitty --class nixclean -e fish -lc 'nixclean; read -P "enter..."'`.
- Preserve current Fish `nixclean` user change and avoid overwriting it while editing.

### 3. Hyprland workspace transition picker

- Add a host-specific preference for workspace animation style. Preferred storage: host config file that can be synced by `orgm-dot`, with generated local runtime value allowed if needed.
- Add a shared script, proposed name: `hypr-transition-menu`:
  - lists available presets in Rofi;
  - writes selected preset to host preference;
  - runs `hyprctl reload`;
  - notifies selected style.
- Add entry to `hypr-main-menu`: `󰹹 Transitions` or similar.
- Update `look-and-feel.lua` so `workspaces` animation style is selected from the preference rather than hardcoded.
- Initial presets:

| Preset | Hyprland workspace style | Source / note |
| --- | --- | --- |
| `fade` | `fade` | current repo behavior |
| `slide` | `slide` | Hyprland built-in |
| `slidevert` | `slidevert` | Hyprland built-in and HyDE/LimeFrenzy-inspired |
| `slidefade` | `slidefade 20%` | Hyprland wiki pattern |
| `slidefadevert` | `slidefadevert 20%` | Hyprland wiki pattern |
| `hyde` | speed `5`, bezier `wind`, no explicit style or slide | HyDE `theme.conf` |
| `limefrenzy` | speed `5`, bezier `overshot`, style `slidevert` | HyDE/LimeFrenzy PR pattern |
| `off` | disabled workspace animation | accessibility/performance fallback |

## Error handling

- Missing `flatpak`: NixOS declarations still evaluate; runtime helpers skip Flatpak checks and notify.
- Missing `udiskie`: storage menu can still use `udisksctl mount`; status warns via tooltip.
- Missing `lsusb`: USB menu falls back to `/sys` + `lsblk` and warns in log.
- Storage device selected for reconnect: menu refuses unbind/bind and offers open/mount instead.
- Nickname file missing or malformed: ignore bad rows, keep menu usable, and rewrite only after a new nickname is saved.
- Hyprland preset invalid/missing: fall back to current `fade` preset.
- Rofi cancel: exit quietly with status 0.

## Verification plan

- Dotfiles static checks:
  - `bash -n` for changed helpers.
  - `fish -n` for changed Fish wrapper/function files.
  - parse all `.desktop` `Exec=` commands and verify native commands/Flatpak IDs exist on host.
  - validate Waybar config JSON shape.
- NixOS checks:
  - `nix flake check` or targeted `nixos-rebuild dry-build` for host if feasible.
  - confirm `flatpak.nix` package set equals host `flatpak list --app --columns=application` after planned removals/additions.
- Runtime checks through host:
  - `distrobox-host-exec orgm-dot diff` before sync.
  - `distrobox-host-exec orgm-dot sync` after approval.
  - Waybar reload via `waybar-watch ~/.config/waybar-hypr`.
  - Click USB button with a flash drive connected: storage must mount/open, not unbind.
  - Right-click USB button: user can save/edit a nickname, then selected non-storage USB reconnect shows that nickname on later prompts.
  - Click non-storage USB reconnect: selected device unbinds, waits, rebinds.
  - Click nixclean button: terminal opens and runs Fish `nixclean`.
  - Select each Hyprland transition preset and confirm `hyprctl reload` succeeds.

## Out of scope

- Replacing native Chromium webapps with Flatpak Chromium.
- Rebuilding deleted `orgm`/`orgmos` tools.
- Changing Sway/Labwc/Niri behavior unless active references are broken by the same app move.
- Running destructive cleanup from Waybar without opening a visible terminal.

## Review checklist

- [ ] Flatpak set reflects what should be managed declaratively on NixOS.
- [ ] No launcher points to missing command, missing Flatpak, or generation-specific `/nix/store` path.
- [ ] USB storage cannot be disconnected with USB unbind/bind flow.
- [ ] USB nicknames persist and appear in future Waybar/Rofi reconnect labels.
- [ ] Waybar buttons are discoverable and safe.
- [ ] Hyprland transition preference is host-specific and menu-selectable.
