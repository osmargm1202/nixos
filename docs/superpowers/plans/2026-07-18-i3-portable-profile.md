# Portable i3 Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing i3 profile into a complete, auto-starting X11 desktop that works on orgm, lenovo, ero, and jarq and provides daily-function parity with the Hyprland profile.

**Architecture:** Keep one `i3.nix` profile and its existing host outputs. NixOS owns Xorg, getty autologin, startx, services, packages, and MIME/portal integration; profile dotfiles own i3, Rofi, Picom, Polybar, and compositor-specific helpers. Hardware-dependent Polybar data comes from tested shell helpers that safely emit nothing when hardware is unavailable.

**Tech Stack:** NixOS modules, Xorg, i3, Bash, Rofi, Polybar, Picom, Fish login initialization, shell fixture tests.

## Global Constraints

- Improve `nixos/profiles/i3.nix`; do not create `i3-full` or `i3-any`.
- Preserve `orgm-i3`, `lenovo-i3`, `ero-i3`, `jarq-i3`, and generic `i3` outputs.
- Autologin through getty on `/dev/tty1`; no graphical display manager.
- Start X with the NixOS-generated `/etc/X11/xinit/xinitrc`.
- Use `userName`; orgm/lenovo/ero use `osmarg`, jarq uses `jarq`.
- Include Xorg Server and required X11 utilities explicitly.
- Use static wallpapers through Feh; never require `~/Videos/wallpapers/1.mp4`.
- i3 configuration must not invoke `hypr-*`, `hyprctl`, Waybar, or Wayland-only utilities.
- Native X11 programs may replace Hyprland helpers where they provide equivalent daily behavior.
- Preserve unrelated dirty Herdr state files.

---

## File Structure

- Modify `nixos/profiles/i3.nix`: Xorg/startx/autologin, desktop services, packages, portals, MIME defaults.
- Modify `nixos/common-dotfiles.nix`: deploy i3 profile helper paths.
- Modify `dotfiles/config/profiles/i3/.config/i3/config`: startup and bindings.
- Modify `dotfiles/config/profiles/i3/.config/rofi/config.rasi`: Kitty terminal and required modes.
- Modify `dotfiles/config/profiles/i3/.config/polybar/config.ini`: portable script modules.
- Create `dotfiles/config/profiles/i3/.local/bin/i3-*`: focused i3/X11 helpers.
- Create `tests/i3-profile.bats.sh`: flake/profile structure and Nix evaluation checks.
- Create `dotfiles/tests/helpers/i3-shell-helpers.bats.sh`: helper behavior and portability fixtures.

### Helper interfaces

| Command | Interface |
| --- | --- |
| `i3-rofi` | `i3-rofi PROMPT [LINES]`; reads choices on stdin and prints selection |
| `i3-open-file` | `i3-open-file open | dir | terminal`; selects a recent home file and opens target |
| `i3-ssh-host` | no arguments; selects host and runs `kitty -e ssh HOST` |
| `i3-main-menu` | no arguments; launches one daily i3/native action |
| `i3-powermenu` | no arguments; lock/suspend/hibernate/logout/reboot/poweroff |
| `i3-performance-menu` | no arguments; select power profile through `powerprofilesctl` |
| `i3-keyboard-menu` | no arguments; select/toggle US and Latam layouts with `setxkbmap` |
| `i3-wallpaper-random` | `[--restore]`; set random image or restore cached image using Feh |
| `i3-hotkeys` | `[--list]`; print or show current i3 bindings |
| `i3-config-editor` | no arguments; select tracked i3/Rofi/Polybar/Picom file |
| `i3-polybar-launch` | no arguments; terminate old Polybar and launch `modern` once |
| `i3-status-battery` | no arguments; print battery status or empty output |
| `i3-status-cpu-temp` | no arguments; print CPU temperature or empty output |
| `i3-status-gpu-temp` | no arguments; print GPU temperature or empty output |

---

### Task 1: Add profile evaluation tests and complete NixOS i3 module

**Files:**

- Create: `tests/i3-profile.bats.sh`
- Modify: `nixos/profiles/i3.nix`

**Interfaces:**

- Consumes: existing `userName` special argument from `mkHost`/`mkProfile`.
- Produces: evaluated autologin/startx/Xorg desktop profile for every `*-i3` output.

- [ ] **Step 1: Write failing profile tests**

Create `tests/i3-profile.bats.sh` with strict shell mode. Assert all four host blocks exist and reference `./nixos/profiles/i3.nix`. Then evaluate:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

for host in orgm lenovo ero jarq; do
  grep -Eq "^[[:space:]]*${host}-i3[[:space:]]*=[[:space:]]*mkHost" flake.nix \
    || fail "missing ${host}-i3"
  grep -A4 -E "^[[:space:]]*${host}-i3[[:space:]]*=" flake.nix \
    | grep -q 'profile = ./nixos/profiles/i3.nix' \
    || fail "${host}-i3 does not use i3.nix"
done

[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.enable 2>/dev/null)" == true ]] || fail 'Xserver disabled'
[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.displayManager.startx.enable 2>/dev/null)" == true ]] || fail 'startx disabled'
[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.displayManager.startx.generateScript 2>/dev/null)" == true ]] || fail 'xinitrc generation disabled'
[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.getty.autologinUser --raw 2>/dev/null)" == osmarg ]] || fail 'orgm autologin user'
[[ "$(nix eval .#nixosConfigurations.jarq-i3.config.services.getty.autologinUser --raw 2>/dev/null)" == jarq ]] || fail 'jarq autologin user'
echo 'PASS: i3 profile tests'
```

- [ ] **Step 2: Verify RED state**

Run: `bash tests/i3-profile.bats.sh`

Expected: failure at `startx disabled`, `xinitrc generation disabled`, or missing autologin user.

- [ ] **Step 3: Complete `nixos/profiles/i3.nix`**

Change arguments to `{ pkgs, lib, userName ? "osmarg", ... }`. Import `./printer.nix`. Preserve i3 enablement and add:

```nix
services.xserver.displayManager.startx = {
  enable = true;
  generateScript = true;
};
services.displayManager.defaultSession = "none+i3";
services.getty.autologinUser = userName;

programs.fish.loginShellInit = lib.mkAfter ''
  if test (tty) = /dev/tty1; and not set -q DISPLAY
    exec startx /etc/X11/xinit/xinitrc
  end
'';

services.libinput.enable = true;
services.dbus.enable = true;
services.gvfs.enable = true;
services.udisks2.enable = true;
services.upower.enable = true;
services.power-profiles-daemon.enable = true;
services.gnome.gnome-keyring.enable = true;
security.polkit.enable = true;
security.pam.services.login.enableGnomeKeyring = true;
programs.dconf.enable = true;
```

Set GTK portal defaults, Kitty terminal defaults, X11 session variables, and MIME defaults for Nautilus, GNOME Text Editor, Evince, Loupe, File Roller, and Chromium.

Declare these packages in addition to the existing stack:

```nix
xorg.xorgserver xorg.xinit xorg.xauth xorg.xrdb xorg.xrandr xorg.xinput
xorg.xset xorg.xsetroot xorg.setxkbmap xorg.xkill
feh rofi-calc clipmenu arandr udiskie usbutils desktop-file-utils
kitty nautilus gnome-text-editor evince loupe file-roller chromium
```

Keep `i3`, `i3lock-color`, `polybar`, `picom`, `rofi`, `dunst`, `networkmanagerapplet`, `blueman`, `pavucontrol`, `polkit_gnome`, `gnome-keyring`, `dex`, `xss-lock`, `flameshot`, `brightnessctl`, `pamixer`, `playerctl`, `xclip`, and portal packages. Remove `xwinwrap`; animated wallpaper startup no longer needs it.

- [ ] **Step 4: Verify GREEN state and diagnostics**

Run:

```bash
bash tests/i3-profile.bats.sh
nix eval .#nixosConfigurations.orgm-i3.config.services.displayManager.sessionData.sessionNames --json
```

Expected: test prints `PASS`; session names include `none+i3`.

- [ ] **Step 5: Commit profile foundation**

```bash
git add tests/i3-profile.bats.sh nixos/profiles/i3.nix
git commit -m "feat: complete portable i3 profile"
```

---

### Task 2: Correct i3 startup and daily bindings

**Files:**

- Modify: `dotfiles/config/profiles/i3/.config/i3/config`
- Modify: `dotfiles/config/profiles/i3/.config/rofi/config.rasi`
- Test: `dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

**Interfaces:**

- Consumes: helper command names listed in File Structure.
- Produces: bindings and startup contract used by later helper tasks.

- [ ] **Step 1: Add failing structural checks**

Start `dotfiles/tests/helpers/i3-shell-helpers.bats.sh` with assertions that configuration:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
I3="$ROOT/config/profiles/i3/.config/i3/config"
ROFI="$ROOT/config/profiles/i3/.config/rofi/config.rasi"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

grep -q 'exec --no-startup-id i3-polybar-launch' "$I3" || fail 'polybar launcher missing'
grep -q 'exec --no-startup-id i3-wallpaper-random --restore' "$I3" || fail 'wallpaper restore missing'
grep -q 'exec --no-startup-id clipmenud' "$I3" || fail 'clipmenud missing'
grep -q 'exec --no-startup-id xss-lock' "$I3" || fail 'xss-lock missing'
! grep -Eq 'hypr-|xwinwrap|Videos/wallpapers/1\.mp4' "$I3" || fail 'nonportable command remains'
grep -q 'terminal: "kitty"' "$ROFI" || fail 'Rofi terminal is not Kitty'
```

- [ ] **Step 2: Verify RED state**

Run: `bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

Expected: failure at `polybar launcher missing`.

- [ ] **Step 3: Update startup and bindings**

In i3 config:

```i3
exec --no-startup-id dex --autostart --environment i3
exec --no-startup-id /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1
exec --no-startup-id gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
exec --no-startup-id nm-applet
exec --no-startup-id blueman-applet
exec --no-startup-id udiskie --tray
exec --no-startup-id dunst
exec --no-startup-id picom --config ~/.config/picom/picom.conf -b
exec --no-startup-id clipmenud
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock-color --color=1a1b26 --ignore-empty-password
exec --no-startup-id i3-wallpaper-random --restore
exec --no-startup-id i3-polybar-launch
```

Remove xwinwrap/MPV wallpaper startup. Use:

```i3
set $launcher rofi -show drun -show-icons
bindsym $mod+space exec --no-startup-id $launcher
bindsym $mod+Escape exec --no-startup-id rofi -show window
bindsym $mod+c exec --no-startup-id rofi -show calc -modi calc
bindsym $mod+v exec --no-startup-id i3-clipboard
bindsym $mod+m exec --no-startup-id i3-open-file open
bindsym $mod+Ctrl+m exec --no-startup-id i3-open-file dir
bindsym $mod+Shift+m exec --no-startup-id i3-open-file terminal
bindsym $mod+d exec --no-startup-id i3-ssh-host
bindsym $mod+slash exec --no-startup-id i3-hotkeys
bindsym $mod+Alt+space exec --no-startup-id i3-main-menu
bindsym $mod+p exec --no-startup-id arandr
bindsym $mod+Shift+q exec --no-startup-id xkill
```

Use `pamixer` for volume/microphone bindings and preserve player, brightness, window, workspace, and resize bindings.

In Rofi config, set `terminal: "kitty"` and modes `"drun,run,window,ssh,calc"`.

- [ ] **Step 4: Verify structural GREEN state**

Run: `bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

Expected: startup/config checks pass until the first missing helper check added by Task 3.

- [ ] **Step 5: Commit configuration contract**

```bash
git add dotfiles/config/profiles/i3/.config/i3/config dotfiles/config/profiles/i3/.config/rofi/config.rasi dotfiles/tests/helpers/i3-shell-helpers.bats.sh
git commit -m "feat: wire portable i3 session"
```

---

### Task 3: Add daily i3 helper suite

**Files:**

- Create: `dotfiles/config/profiles/i3/.local/bin/i3-rofi`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-open-file`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-clipboard`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-ssh-host`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-main-menu`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-powermenu`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-performance-menu`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-keyboard-menu`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-wallpaper-random`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-hotkeys`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-config-editor`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-polybar-launch`
- Modify: `nixos/common-dotfiles.nix`
- Test: `dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

**Interfaces:**

- Consumes: Rofi, Kitty, Feh, clipmenu, powerprofilesctl, setxkbmap, systemctl, i3-msg.
- Produces: executable profile helpers called by i3 and Polybar.

- [ ] **Step 1: Extend failing test with helper contract**

Append checks for every helper path, executable bit, shell syntax, and absence of `hypr-`/`hyprctl`:

```bash
BIN="$ROOT/config/profiles/i3/.local/bin"
helpers=(i3-rofi i3-open-file i3-clipboard i3-ssh-host i3-main-menu i3-powermenu i3-performance-menu i3-keyboard-menu i3-wallpaper-random i3-hotkeys i3-config-editor i3-polybar-launch)
for helper in "${helpers[@]}"; do
  [[ -x "$BIN/$helper" ]] || fail "$helper missing or not executable"
  bash -n "$BIN/$helper" || fail "$helper syntax"
  ! grep -Eq 'hypr-|hyprctl' "$BIN/$helper" || fail "$helper depends on Hyprland"
done
```

- [ ] **Step 2: Verify RED state**

Run: `bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

Expected: `i3-rofi missing or not executable`.

- [ ] **Step 3: Implement focused helpers**

Use strict mode in every script. `i3-rofi` is the shared primitive:

```bash
#!/usr/bin/env bash
set -euo pipefail
prompt="${1:-i3}"
lines="${2:-14}"
exec rofi -dmenu -i -p "$prompt" -lines "$lines" -show-icons
```

`i3-open-file` accepts exactly `open`, `dir`, or `terminal`; gathers recent non-hidden files under `$HOME`, excludes `.git`, `node_modules`, `target`, `.cache`, and `.local/share/Trash`, then runs respectively `xdg-open FILE`, `nautilus DIR`, or `kitty --directory DIR`. Cancellation exits zero.

`i3-clipboard` runs `clipmenu -i -p Clipboard`. `i3-ssh-host` combines aliases from `~/.ssh/config` and unhashed entries from `known_hosts`, selects with `i3-rofi`, then executes `kitty -e ssh HOST`.

`i3-main-menu` maps these exact labels:

```text
Apps
Windows
Files
Clipboard
Displays
Wi-Fi
Bluetooth
Audio
Keyboard
Performance
Edit config
Power
```

Actions are Rofi drun/window, `i3-open-file open`, `i3-clipboard`, `arandr`, `nm-connection-editor`, `blueman-manager`, `pavucontrol`, `i3-keyboard-menu`, `i3-performance-menu`, `i3-config-editor`, and `i3-powermenu`.

`i3-powermenu` maps Lock/Suspend/Hibernate/Logout/Reboot/Power off to `i3lock-color`, `systemctl suspend`, `systemctl hibernate`, `i3-msg exit`, `systemctl reboot`, and `systemctl poweroff`.

`i3-performance-menu` lists profiles from `powerprofilesctl list`, normalizes `power-saver`, `balanced`, and `performance`, then calls `powerprofilesctl set PROFILE`; if unavailable, notify and exit zero.

`i3-keyboard-menu` maps US, Latam, and Toggle to `setxkbmap -layout us -variant altgr-intl`, `setxkbmap -layout latam`, and `setxkbmap -layout 'us,latam' -variant 'altgr-intl,' -option 'grp:ctrl_space_toggle'`.

`i3-wallpaper-random` searches `${I3_WALLPAPER_DIR:-$HOME/.config/wallpapers}` for jpg/jpeg/png/webp files. Cache selected path at `${XDG_STATE_HOME:-$HOME/.local/state}/i3/wallpaper`. `--restore` reuses valid cache, otherwise chooses with `shuf -n1`. Apply using `feh --no-fehbg --bg-fill FILE`. Missing images sends `notify-send` and exits zero.

`i3-hotkeys --list` prints categories from the actual i3 bindings; interactive mode pipes them to `i3-rofi Atajos 20`. `i3-config-editor` selects files only below `$HOME/Hobby/nixos/dotfiles/config/profiles/i3/.config`, validates selection contains no `..`, then opens in `kitty -e nvim FILE` or `xdg-open` after a second Rofi choice.

`i3-polybar-launch` executes `polybar-msg cmd quit`, waits for old processes with a bounded loop, then `exec polybar --config="$HOME/.config/polybar/config.ini" modern`.

Make every helper executable.

- [ ] **Step 4: Register helpers in `profileSpecificPaths.i3`**

Add every `.local/bin/i3-*` path immediately after existing i3 config paths. Do not add them to shared or Hyprland lists.

- [ ] **Step 5: Verify helper contract**

Run:

```bash
bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh
rg -n 'hypr-|hyprctl' dotfiles/config/profiles/i3 || true
```

Expected: helper checks pass; ripgrep prints no matches.

- [ ] **Step 6: Commit daily helpers**

```bash
git add nixos/common-dotfiles.nix dotfiles/config/profiles/i3/.local/bin dotfiles/tests/helpers/i3-shell-helpers.bats.sh
git commit -m "feat: add daily i3 helpers"
```

---

### Task 4: Make Polybar hardware modules portable

**Files:**

- Create: `dotfiles/config/profiles/i3/.local/bin/i3-status-battery`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-status-cpu-temp`
- Create: `dotfiles/config/profiles/i3/.local/bin/i3-status-gpu-temp`
- Modify: `dotfiles/config/profiles/i3/.config/polybar/config.ini`
- Modify: `nixos/common-dotfiles.nix`
- Test: `dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

**Interfaces:**

- Consumes: sysfs roots and optional `nvidia-smi`.
- Produces: one-line Polybar text or empty successful output.

- [ ] **Step 1: Add failing fixture tests**

Create temporary fake roots and test:

```bash
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/power/BAT1" "$TMP/hwmon/hwmon0"
printf 'Battery\n' > "$TMP/power/BAT1/type"
printf '73\n' > "$TMP/power/BAT1/capacity"
printf 'Discharging\n' > "$TMP/power/BAT1/status"
printf 'coretemp\n' > "$TMP/hwmon/hwmon0/name"
printf '56000\n' > "$TMP/hwmon/hwmon0/temp1_input"

battery="$(I3_POWER_SUPPLY_ROOT="$TMP/power" "$BIN/i3-status-battery")"
[[ "$battery" == *73%* ]] || fail 'BAT1 was not auto-detected'
cpu="$(I3_HWMON_ROOT="$TMP/hwmon" "$BIN/i3-status-cpu-temp")"
[[ "$cpu" == *56* ]] || fail 'CPU temperature not detected'
mkdir -p "$TMP/empty"
[[ -z "$(I3_POWER_SUPPLY_ROOT="$TMP/empty" "$BIN/i3-status-battery")" ]] || fail 'desktop battery output must be empty'
```

- [ ] **Step 2: Verify RED state**

Run: `bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

Expected: missing `i3-status-battery`.

- [ ] **Step 3: Implement hardware helpers**

`i3-status-battery` scans `${I3_POWER_SUPPLY_ROOT:-/sys/class/power_supply}/*`, chooses first entry whose `type` is `Battery`, reads numeric `capacity` and status, and prints `BAT N%` with charging/discharging icon. No battery prints nothing and exits zero.

`i3-status-cpu-temp` scans `${I3_HWMON_ROOT:-/sys/class/hwmon}/hwmon*/name`; prefer names matching `coretemp|k10temp|zenpower|cpu_thermal`, otherwise use first valid `temp*_input`. Accept only 0–150000 millidegrees and print `CPU N°C`; no valid sensor prints nothing.

`i3-status-gpu-temp` first tries `nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits`; otherwise scans hwmon names matching `amdgpu|i915|xe`, validates temperature as above, and prints `GPU N°C`; no GPU sensor prints nothing.

- [ ] **Step 4: Replace fixed Polybar modules**

Convert battery, CPU temperature, and GPU temperature modules to `custom/script` entries calling the helpers. Remove `battery = BAT0`, `adapter = AC`, `thermal-zone = 0`, and inline NVIDIA-only command. Keep module names so `modules-right` needs no structural change.

Change button commands to existing helpers:

```ini
click-left = i3-wallpaper-random
click-left = i3-hotkeys
click-left = i3-powermenu
```

- [ ] **Step 5: Register status helpers and run tests**

Add three paths to `profileSpecificPaths.i3`, make scripts executable, then run:

```bash
bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh
rg -n 'BAT0|thermal-zone|nvidia-smi.*echo "N/A"|i3-wallpaper-random|i3-hotkeys|i3-powermenu' dotfiles/config/profiles/i3/.config/polybar/config.ini
```

Expected: tests pass; only valid helper button references appear, not fixed hardware assumptions.

- [ ] **Step 6: Commit portable Polybar**

```bash
git add nixos/common-dotfiles.nix dotfiles/config/profiles/i3/.config/polybar/config.ini dotfiles/config/profiles/i3/.local/bin/i3-status-* dotfiles/tests/helpers/i3-shell-helpers.bats.sh
git commit -m "fix: make i3 polybar hardware portable"
```

---

### Task 5: Verify helper behavior with command stubs

**Files:**

- Modify: `dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

**Interfaces:**

- Consumes: all helper commands from Tasks 3–4.
- Produces: regression coverage for cancellation and action dispatch.

- [ ] **Step 1: Add stub-based behavior tests**

Build a temporary `PATH` with stubs for `rofi`, `feh`, `systemctl`, `i3-msg`, `kitty`, `powerprofilesctl`, `setxkbmap`, `polybar`, and `polybar-msg`. Each stub appends arguments to `$CALLS`. Add cases proving:

```text
Rofi cancellation causes no action.
Power menu Suspend runs exactly: systemctl suspend.
Power menu Logout runs exactly: i3-msg exit.
Keyboard Latam runs: setxkbmap -layout latam.
Wallpaper restore applies cached valid file through feh --no-fehbg --bg-fill.
Performance selection runs: powerprofilesctl set balanced.
Polybar launcher invokes polybar-msg cmd quit before polybar ... modern.
```

- [ ] **Step 2: Run behavior tests**

Run: `bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh`

Expected: all structural, fixture, and dispatch tests print `PASS: i3 shell helper tests`.

- [ ] **Step 3: Commit regression coverage**

```bash
git add dotfiles/tests/helpers/i3-shell-helpers.bats.sh
git commit -m "test: cover i3 helper actions"
```

---

### Task 6: Full validation on every host output

**Files:**

- Modify only if verification exposes a defect in files from Tasks 1–5.

**Interfaces:**

- Consumes: completed profile and helper suite.
- Produces: build evidence for all supported hosts.

- [ ] **Step 1: Run shell and repository tests**

```bash
bash tests/flake-outputs.bats.sh
bash tests/i3-profile.bats.sh
bash dotfiles/tests/helpers/i3-shell-helpers.bats.sh
go test ./...
```

Expected: every command exits zero.

- [ ] **Step 2: Run Nix diagnostics and formatter checks**

```bash
nix fmt -- --check nixos/profiles/i3.nix nixos/common-dotfiles.nix flake.nix
nix eval .#nixosConfigurations.orgm-i3.config.system.build.toplevel.drvPath --raw
nix eval .#nixosConfigurations.lenovo-i3.config.system.build.toplevel.drvPath --raw
nix eval .#nixosConfigurations.ero-i3.config.system.build.toplevel.drvPath --raw
nix eval .#nixosConfigurations.jarq-i3.config.system.build.toplevel.drvPath --raw
```

Expected: formatting succeeds and each eval prints a derivation path.

- [ ] **Step 3: Build all host profiles**

```bash
nix build .#nixosConfigurations.orgm-i3.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.lenovo-i3.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.ero-i3.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.jarq-i3.config.system.build.toplevel --no-link
```

Expected: all four builds exit zero.

- [ ] **Step 4: Verify closure commands and forbidden references**

```bash
rg -n 'hypr-|hyprctl|wezterm|xwinwrap|Videos/wallpapers/1\.mp4|battery = BAT0|thermal-zone = 0' dotfiles/config/profiles/i3 nixos/profiles/i3.nix
```

Expected: no matches.

- [ ] **Step 5: Inspect final diff and confirm implementation tree is clean**

```bash
git diff --check
git status --short
git log --oneline -8
```

Expected: only pre-existing Herdr state files remain dirty; implementation files are committed.
