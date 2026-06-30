# Rofi menu unification and headset reconnect design

## Goal

Replace all Hyprland Fuzzel-backed launchers, menus, and helpers with Rofi-backed scripts that share one sizing/theme layer. Add a Waybar button that opens a Rofi chooser for Bluetooth devices, then disconnects the chosen device, waits two seconds, and reconnects it using the existing `unbindheadset` Fish command flow where appropriate.

## Context

Current menu scripts mix patterns:

- `hypr-main-menu` reads `~/.config/rofi/hypr-menu.env` and applies host sizing.
- Several submenus call `rofi` directly without sizing `-theme-str`, so they render smaller or inconsistent.
- Several helpers still call `fuzzel`: file search, directory search, terminal-in-directory, window switcher, calc, SSH, tmux, and keyhelper labels.
- Host `orgm` has `config/hosts/orgm/.config/rofi/hypr-menu.env` with `HYPR_ROFI_SCALE=1.25` and `HYPR_ROFI_LINES=13`.

## Decisions

- Use Rofi for all menus and helpers; Fuzzel should no longer be used by Hyprland menu/keybinding scripts.
- Create one shared shell library, `~/.local/bin/hypr-rofi-lib`, as the only place that reads `HYPR_ROFI_ENV` and computes default sizes.
- Keep host-specific sizing in `~/.config/rofi/hypr-menu.env`.
- Keep scripts small: each script owns its data/action logic, but all Rofi invocation goes through the shared helper.
- Add a Waybar Bluetooth reconnect button that uses Rofi to select from Bluetooth devices and runs the disconnect/wait/reconnect behavior.

## Architecture

### Shared Rofi library

New script: `config/shared/.local/bin/hypr-rofi-lib`.

Responsibilities:

- Source `HYPR_ROFI_ENV`, defaulting to `~/.config/rofi/hypr-menu.env`.
- Set common defaults:
  - `HYPR_ROFI_THEME`
  - `HYPR_ROFI_SCALE`
  - `HYPR_ROFI_WIDTH`
  - `HYPR_ROFI_LINES`
  - `HYPR_ROFI_FONT_SIZE`
  - `HYPR_ROFI_ICON_SIZE`
  - `HYPR_ROFI_ELEMENT_PADDING`
- Expose helper functions:
  - `hypr_rofi_dmenu PROMPT [LINES]`
  - `hypr_rofi_drun`
  - `hypr_rofi_theme_str [LINES] [WIDTH]`
- Allow per-script overrides by environment variable without duplicating math.

### Menu migration

Update these Rofi scripts to source `hypr-rofi-lib` and call `hypr_rofi_dmenu`:

- `hypr-main-menu`
- `hypr-tools-menu`
- `hypr-performance-menu`
- `hypr-power-menu`
- `hypr-system-menu`
- `hypr-wifi-menu`
- `hypr-bluetooth-menu`
- `hypr-keyboard-menu`
- `hypr-theme-chooser`
- `hypr-keybindings-help`

`hypr-main-menu` Apps action uses `hypr_rofi_drun` so it uses same host sizing.

### Fuzzel removal from helpers

Replace Fuzzel helper scripts or add Rofi equivalents and update keybindings/docs:

- `hypr-fuzzel` -> Rofi app launcher or remove from active refs.
- `fuzzel-hypr-window` -> Rofi window switcher.
- `fuzzel-open-file` -> Rofi file opener.
- `fuzzel-open-file-dir` -> Rofi directory opener.
- `fuzzel-open-file-terminal` -> Rofi terminal-in-directory opener.
- `fuzzel-ssh-host` -> Rofi SSH host chooser.
- `fuzzel-tmux-arch` -> Rofi tmux chooser.
- `fuzzel-calc` -> Rofi calculator prompt.

Preferred naming: use `hypr-rofi-*` for new helpers, then update keybindings and menus to call new names. Old `fuzzel-*` scripts can remain only as compatibility shims or be removed from dotfiles if no refs remain.

### Keybindings and visible help

Update:

- `config/shared/.config/hypr/lua/programs.lua`
- `config/shared/.config/hypr/lua/keybindings.lua`
- `hypr-keybindings-help`
- `hypr-keyhelper`

Expected result:

- `Win+Space` opens Rofi app launcher/main launcher with host sizing.
- `Win+Alt+Space` opens Rofi control center with same sizing.
- Search/window/calc/SSH/tmux helpers all use Rofi and match host scale.
- Help text no longer says Fuzzel.

### Bluetooth reconnect button

New script: `config/shared/.local/bin/hypr-bluetooth-reconnect`.

Behavior:

1. List paired/trusted/known Bluetooth devices via `bluetoothctl devices` and enrich status when possible.
2. Show devices in Rofi using `hypr-rofi-lib`.
3. On selection:
   - If existing Fish command `unbindheadset` is available and can accept a MAC/address argument, call it through Fish.
   - Otherwise use fallback sequence:
     - `bluetoothctl disconnect <MAC>`
     - `sleep 2`
     - `bluetoothctl connect <MAC>`
4. Show notification with success/failure.
5. If Bluetooth pairing asks for PIN/passkey/confirmation, let system Bluetooth agent handle it; the script should not fake credentials.

Waybar integration:

- Add `custom/headset_reconnect` near Bluetooth/theme/wallpaper controls.
- Text/icon: headset or Bluetooth reconnect icon.
- `on-click`: `hypr-bluetooth-reconnect`.
- Style with same group as other right-side controls.

## Error handling

- Missing `rofi`: notify and exit nonzero.
- Empty Bluetooth device list: notify "No Bluetooth devices found".
- User cancels Rofi: exit quietly.
- Failed disconnect/connect: notify with command status.
- Missing `unbindheadset`: use `bluetoothctl` fallback.
- Missing `bluetoothctl`: notify and exit.

## Testing

Static checks:

- `bash -n` on all touched scripts.
- `rg -n "fuzzel" config/shared/.local/bin config/shared/.config/hypr config/shared/.config/waybar-hypr` should show no active Hyprland menu/helper refs, except removed legacy files if intentionally kept as shims.
- Verify every menu script sources `hypr-rofi-lib` or calls a helper from it.

Host checks through `distrobox-host-exec`:

- `orgm-dot sync`.
- Run representative menus with `bash -x` and confirm `HYPR_ROFI_SCALE=1.25`, width/font/icon/padding values apply.
- `orgm-dot diff` clean.

Manual checks:

- `Win+Space`, `Win+Alt+Space`, submenus, keybindings help, file/window/calc/SSH/tmux helpers all have consistent size.
- Waybar headset button opens device chooser.
- Selected headset disconnects, waits two seconds, reconnects.

## Out of scope

- Rewriting Bluetooth pairing UI.
- Replacing full Bluetooth GUI (`blueman-manager`) functionality.
- Changing unrelated Hyprland autostart local edit.
- Removing Fuzzel package from NixOS unless later requested after all refs are gone.
