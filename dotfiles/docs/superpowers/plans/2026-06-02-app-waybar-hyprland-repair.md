# App Waybar Hyprland Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair broken app launchers/package declarations, add safe USB/cleanup Waybar controls, and make Hyprland workspace transitions host-selectable.

**Architecture:** Keep runtime behavior in small Bash/Fish helpers under dotfiles, with NixOS only owning installed packages/services. USB handling is one focused helper with status/menu/reconnect/nickname subcommands. Hyprland transition selection is a small menu helper plus Lua preset table in `look-and-feel.lua`.

**Tech Stack:** Bash, Fish, Rofi, Waybar custom JSON modules, Hyprland Lua config, NixOS modules, Go/Bats-style shell smoke tests.

---

## Worktrees

- Dotfiles worktree: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair`
- NixOS worktree: `/home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair`

Baseline already run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair && go test ./...
cd /home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair && go test ./...
```

Both exited 0 before implementation.

## File structure

| File | Responsibility |
| --- | --- |
| `/home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair/nixos/flatpak.nix` | Declarative Flatpak package set matching current host install list. |
| `/home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair/nixos/profiles/hyprland.nix` | Hyprland desktop packages/services, including `udiskie` and `usbutils`. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/hosts/{orgm,lenovo}/.local/share/applications/*.desktop` | Host desktop launchers. Remove or fix broken launchers. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.local/bin/hypr-usb-menu` | USB status/menu/reconnect/open/nickname helper. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/fish/functions/unbindheadset.fish` | Compatibility wrapper to invoke USB reconnect flow. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/waybar-hypr/config` | Add USB and nixclean modules. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/waybar-hypr/style.css` | Style new Waybar modules. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.local/bin/hypr-transition-menu` | Rofi picker for workspace animation preset. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/hypr/lua/look-and-feel.lua` | Read host env and apply workspace animation preset. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.local/bin/hypr-main-menu` | Add transition menu entry. |
| `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/tests/helpers/*.bats.sh` | Shell smoke/regression tests. |

---

### Task 1: NixOS package/service repair

**Files:**
- Modify: `/home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair/nixos/flatpak.nix`
- Modify: `/home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair/nixos/profiles/hyprland.nix`

- [ ] **Step 1: Capture expected Flatpak set in a temporary assertion script**

Run:

```bash
cd /home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair
python3 - <<'PY'
from pathlib import Path
import re
text = Path('nixos/flatpak.nix').read_text()
packages = set(re.findall(r'"([A-Za-z0-9_.-]+)"', text)) - {'flathub'}
expected = {
  'app.zen_browser.zen',
  'be.alexandervanhee.gradia',
  'com.discordapp.Discord',
  'com.google.EarthPro',
  'com.obsproject.Studio',
  'com.pokemmo.PokeMMO',
  'com.spotify.Client',
  'fr.arnaudmichel.launcherstudio',
  'io.github.realmazharhussain.GdmSettings',
  'io.gitlab.theevilskeleton.Upscaler',
  'io.podman_desktop.PodmanDesktop',
  'md.obsidian.Obsidian',
  'net.thunderbird.Thunderbird',
  'org.blender.Blender',
  'org.gimp.GIMP',
  'org.gnome.SimpleScan',
  'org.inkscape.Inkscape',
  'org.libreoffice.LibreOffice',
  'org.yuzu_emu.yuzu',
}
assert packages == expected, (sorted(packages - expected), sorted(expected - packages))
PY
```

Expected before edit: assertion fails and reports missing/extra Flatpaks.

- [ ] **Step 2: Update `flatpak.nix` packages**

Replace `packages = [...]` with exactly:

```nix
    packages = [
      "app.zen_browser.zen"
      "be.alexandervanhee.gradia"
      "com.discordapp.Discord"
      "com.google.EarthPro"
      "com.obsproject.Studio"
      "com.pokemmo.PokeMMO"
      "com.spotify.Client"
      "fr.arnaudmichel.launcherstudio"
      "io.github.realmazharhussain.GdmSettings"
      "io.gitlab.theevilskeleton.Upscaler"
      "io.podman_desktop.PodmanDesktop"
      "md.obsidian.Obsidian"
      "net.thunderbird.Thunderbird"
      "org.blender.Blender"
      "org.gimp.GIMP"
      "org.gnome.SimpleScan"
      "org.inkscape.Inkscape"
      "org.libreoffice.LibreOffice"
      "org.yuzu_emu.yuzu"
    ];
```

- [ ] **Step 3: Add `udiskie` and `usbutils` to Hyprland profile**

In `environment.systemPackages` of `nixos/profiles/hyprland.nix`, add:

```nix
    udiskie
    usbutils
```

near the existing GNOME/portal/hardware integration tools.

Add user service below `services.gvfs.enable = true;`:

```nix
  services.udisks2.enable = true;
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
  };
```

If `services.udiskie` is not a valid NixOS option in this channel, instead add package `udiskie` only and document manual `systemd --user` enable in commit body.

- [ ] **Step 4: Verify**

Run expected Flatpak assertion from Step 1. Expected: no output, exit 0.

Run:

```bash
cd /home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair
nix flake check --no-build 2>&1 | tee /tmp/nixos-flake-check.log
```

Expected: exit 0, or if external flake/network constraints block it, capture exact blocker in task report.

- [ ] **Step 5: Commit**

```bash
cd /home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair
git add nixos/flatpak.nix nixos/profiles/hyprland.nix
git commit -m "fix: align flatpaks and usb automount"
```

---

### Task 2: Desktop launcher repair

**Files:**
- Modify/delete: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/hosts/orgm/.local/share/applications/*.desktop`
- Modify/delete: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/hosts/lenovo/.local/share/applications/*.desktop`
- Test: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/tests/helpers/desktop-launchers.bats.sh`

- [ ] **Step 1: Write failing launcher audit test**

Create `tests/helpers/desktop-launchers.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

if rg -n 'Exec=/nix/store/.*/distrobox|Exec=orgmos menu|Exec=orgm prop|Exec=/usr/bin/opencode-desktop' "$ROOT/config/hosts"; then
  fail "found stale desktop launcher Exec"
fi

for host in orgm lenovo; do
  appdir="$ROOT/config/hosts/$host/.local/share/applications"
  [ -d "$appdir" ] || continue
  [ ! -e "$appdir/orgmos.desktop" ] || fail "$host orgmos.desktop should be removed"
  [ ! -e "$appdir/propuestas.desktop" ] || fail "$host propuestas.desktop should be removed"
  [ ! -e "$appdir/opencode-desktop-handler.desktop" ] || fail "$host opencode handler should be removed until binary exists"
  if [ -e "$appdir/arch.desktop" ]; then
    grep -Fq 'Exec=distrobox enter arch' "$appdir/arch.desktop" || fail "$host arch desktop should use PATH distrobox enter"
    grep -Fq 'TryExec=distrobox' "$appdir/arch.desktop" || fail "$host arch desktop should use PATH TryExec"
    grep -Fq 'Exec=distrobox rm arch' "$appdir/arch.desktop" || fail "$host arch desktop remove action should use PATH distrobox"
  fi
done

echo "desktop launcher audit passed"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
bash tests/helpers/desktop-launchers.bats.sh
```

Expected: FAIL with stale desktop launcher Exec or existing removed files.

- [ ] **Step 3: Fix launchers**

For both `config/hosts/orgm/.local/share/applications` and `config/hosts/lenovo/.local/share/applications`:

- delete `orgmos.desktop`;
- delete `propuestas.desktop`;
- delete `opencode-desktop-handler.desktop`;
- update `arch.desktop`:
  - `Exec=distrobox enter arch`
  - `TryExec=distrobox`
  - remove action `Exec=distrobox rm arch`.

Also update `mimeinfo.cache` if it references `opencode-desktop-handler.desktop`: remove `x-scheme-handler/opencode=opencode-desktop-handler.desktop;`.

- [ ] **Step 4: Verify and commit**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
bash tests/helpers/desktop-launchers.bats.sh
git add config/hosts tests/helpers/desktop-launchers.bats.sh
git commit -m "fix: remove broken desktop launchers"
```

---

### Task 3: USB helper with protected storage and nicknames

**Files:**
- Create: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.local/bin/hypr-usb-menu`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/fish/functions/unbindheadset.fish`
- Test: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/tests/helpers/hypr-usb-menu.bats.sh`

- [ ] **Step 1: Write failing USB helper test**

Create `tests/helpers/hypr-usb-menu.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-usb-menu"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state" "$TMP/config"
CALLS="$TMP/calls.log"
: >"$CALLS"

fail() { echo "FAIL: $*" >&2; [ -f "$CALLS" ] && cat "$CALLS" >&2; exit 1; }

cat >"$TMP/bin/lsblk" <<'SH'
#!/usr/bin/env bash
cat <<'JSON'
{"blockdevices":[{"name":"sda","path":"/dev/sda","rm":true,"tran":"usb","hotplug":true,"fstype":"vfat","label":"FLASH","mountpoints":["/run/media/osmarg/FLASH"],"model":"Cruzer"}]}
JSON
SH
chmod +x "$TMP/bin/lsblk"

cat >"$TMP/bin/lsusb" <<'SH'
#!/usr/bin/env bash
cat <<'TXT'
Bus 001 Device 004: ID 1234:abcd USB Headset
Bus 001 Device 005: ID 0781:5567 SanDisk Cruzer Blade
TXT
SH
chmod +x "$TMP/bin/lsusb"

cat >"$TMP/bin/rofi" <<'SH'
#!/usr/bin/env bash
if [ "${ROFI_MODE:-}" = "nickname-device" ]; then
  printf '%s\n' 'USB Headset  1-4  1234:abcd'
elif [ "${ROFI_MODE:-}" = "nickname-value" ]; then
  printf '%s\n' 'Audifonos USB'
elif [ "${ROFI_MODE:-}" = "reconnect" ]; then
  printf '%s\n' 'Audifonos USB  1-4  1234:abcd'
else
  printf '%s\n' 'FLASH  /dev/sda  storage'
fi
SH
chmod +x "$TMP/bin/rofi"

for cmd in notify-send xdg-open nautilus udisksctl; do
  cat >"$TMP/bin/$cmd" <<'SH'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >>"$CALLS"
SH
  chmod +x "$TMP/bin/$cmd"
done

export PATH="$TMP/bin:$PATH" CALLS XDG_STATE_HOME="$TMP/state" XDG_CONFIG_HOME="$TMP/config"
export HYPR_USB_SYS_ROOT="$TMP/sys/bus/usb/devices"
mkdir -p "$HYPR_USB_SYS_ROOT/1-4" "$HYPR_USB_SYS_ROOT/1-5"
printf '1234' >"$HYPR_USB_SYS_ROOT/1-4/idVendor"
printf 'abcd' >"$HYPR_USB_SYS_ROOT/1-4/idProduct"
printf 'HeadsetCo' >"$HYPR_USB_SYS_ROOT/1-4/manufacturer"
printf 'USB Headset' >"$HYPR_USB_SYS_ROOT/1-4/product"
printf '0781' >"$HYPR_USB_SYS_ROOT/1-5/idVendor"
printf '5567' >"$HYPR_USB_SYS_ROOT/1-5/idProduct"
printf 'SanDisk' >"$HYPR_USB_SYS_ROOT/1-5/manufacturer"
printf 'Cruzer Blade' >"$HYPR_USB_SYS_ROOT/1-5/product"

ROFI_MODE=nickname-device "$SCRIPT" nickname
[ -f "$TMP/config/orgm-hypr/usb-names.tsv" ] || fail "nickname file missing"
grep -Fq $'1234:abcd\tAudifonos USB' "$TMP/config/orgm-hypr/usb-names.tsv" || fail "nickname not saved"

ROFI_MODE=reconnect "$SCRIPT" reconnect --print | grep -Fq 'unbind 1-4' || fail "reconnect print should target headset bus id"
ROFI_MODE=reconnect "$SCRIPT" reconnect --print | grep -Fq 'bind 1-4' || fail "reconnect print should bind headset bus id"

ROFI_MODE=storage "$SCRIPT" open
if grep -q 'unbind' "$CALLS"; then fail "storage flow must not unbind"; fi

"$SCRIPT" status | jq -e '.text and .tooltip and (.class | index("usb"))' >/dev/null || fail "status JSON invalid"

echo "hypr usb menu smoke test passed"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
bash tests/helpers/hypr-usb-menu.bats.sh
```

Expected: fails because `hypr-usb-menu` does not exist.

- [ ] **Step 3: Implement `hypr-usb-menu`**

Implement Bash subcommands:

```text
hypr-usb-menu status
hypr-usb-menu open
hypr-usb-menu reconnect [--print]
hypr-usb-menu nickname
```

Core requirements:

- `status` prints Waybar JSON via `jq -cn` with `text`, `tooltip`, `class`.
- Device rows include nickname from `$XDG_CONFIG_HOME/orgm-hypr/usb-names.tsv` when key exists.
- Nickname key is `idVendor:idProduct` if available; this is acceptable for first implementation.
- `nickname` asks Rofi for device, then asks Rofi for name using `-dmenu -p 'Nombre USB'`, then writes `key<TAB>name`.
- `open` only opens/mounts storage devices from `lsblk`; never writes to USB bind/unbind.
- `reconnect` filters to non-storage USB devices and writes selected bus id to `/sys/bus/usb/drivers/usb/unbind`, sleeps `${HYPR_USB_REBIND_DELAY:-2}`, then writes bus id to bind.
- `--print` prints `unbind BUSID` and `bind BUSID` without sudo/sysfs writes for tests.
- Use `$HYPR_USB_SYS_ROOT` override for tests, default `/sys/bus/usb/devices`.
- Use `hypr-rofi-lib` if available; otherwise call plain `rofi -dmenu`.

- [ ] **Step 4: Update `unbindheadset.fish` wrapper**

Replace hardcoded `1-11.1` with:

```fish
function unbindheadset
    if type -q hypr-usb-menu
        hypr-usb-menu reconnect $argv
        return $status
    end

    echo "hypr-usb-menu no está instalado" >&2
    return 1
end
```

- [ ] **Step 5: Verify and commit**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
chmod +x config/shared/.local/bin/hypr-usb-menu tests/helpers/hypr-usb-menu.bats.sh
bash tests/helpers/hypr-usb-menu.bats.sh
fish -n config/shared/.config/fish/functions/unbindheadset.fish
bash -n config/shared/.local/bin/hypr-usb-menu
git add config/shared/.local/bin/hypr-usb-menu config/shared/.config/fish/functions/unbindheadset.fish tests/helpers/hypr-usb-menu.bats.sh
git commit -m "feat: add safe usb menu"
```

---

### Task 4: Waybar USB and nixclean modules

**Files:**
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/waybar-hypr/config`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/waybar-hypr/style.css`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/waybar/config`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/waybar/style.css`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/dotfiles.json`
- Test: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/tests/helpers/waybar-usb-nixclean.bats.sh`

- [ ] **Step 1: Write failing Waybar module test**

Create `tests/helpers/waybar-usb-nixclean.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { grep -Fq "$2" "$1" || fail "expected $2 in $1"; }

for cfg in "$ROOT/config/shared/.config/waybar/config" "$ROOT/config/shared/.config/waybar-hypr/config"; do
  assert_contains "$cfg" '"custom/usb_devices"'
  assert_contains "$cfg" '"exec": "hypr-usb-menu status"'
  assert_contains "$cfg" '"on-click": "hypr-usb-menu open"'
  assert_contains "$cfg" '"on-click-right": "hypr-usb-menu nickname"'
  assert_contains "$cfg" '"custom/nixclean"'
  assert_contains "$cfg" '"on-click": "kitty --class nixclean -e fish -lc'
done

for css in "$ROOT/config/shared/.config/waybar/style.css" "$ROOT/config/shared/.config/waybar-hypr/style.css"; do
  assert_contains "$css" '#custom-usb_devices'
  assert_contains "$css" '#custom-nixclean'
done

assert_contains "$ROOT/config/dotfiles.json" '".local/bin/hypr-usb-menu"'

echo "waybar usb nixclean test passed"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
bash tests/helpers/waybar-usb-nixclean.bats.sh
```

Expected: FAIL because modules are missing.

- [ ] **Step 3: Add modules to both Waybar configs**

In top bar `modules-right`, insert before `custom/headset_reconnect` or near tray:

```json
"custom/usb_devices",
"custom/nixclean",
```

Add module objects:

```json
"custom/usb_devices": {
  "exec": "hypr-usb-menu status",
  "return-type": "json",
  "interval": 5,
  "format": "{}",
  "tooltip": true,
  "on-click": "hypr-usb-menu open",
  "on-click-right": "hypr-usb-menu nickname"
},
"custom/nixclean": {
  "format": "󰃢",
  "tooltip": true,
  "tooltip-format": "Limpiar Nix, journal, papelera, Flatpak unused",
  "on-click": "kitty --class nixclean -e fish -lc 'nixclean; read -P \"enter...\"'"
}
```

- [ ] **Step 4: Add CSS to both Waybar styles**

Add:

```css
#custom-usb_devices { color: @sky; font-size: 20px; }
#custom-nixclean { color: @green; font-size: 20px; }
```

- [ ] **Step 5: Add helper to dotfiles manifest**

Add `".local/bin/hypr-usb-menu"` to `config/dotfiles.json` shared paths near other Hyprland helpers.

- [ ] **Step 6: Verify and commit**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
bash tests/helpers/waybar-usb-nixclean.bats.sh
python3 -m json.tool config/shared/.config/waybar-hypr/config >/dev/null
python3 -m json.tool config/shared/.config/waybar/config >/dev/null
git add config/shared/.config/waybar config/shared/.config/waybar-hypr config/dotfiles.json tests/helpers/waybar-usb-nixclean.bats.sh
git commit -m "feat: add waybar usb and nixclean buttons"
```

---

### Task 5: Hyprland transition menu and presets

**Files:**
- Create: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.local/bin/hypr-transition-menu`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.local/bin/hypr-main-menu`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/shared/.config/hypr/lua/look-and-feel.lua`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/hosts/orgm/.config/rofi/hypr-menu.env`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/hosts/lenovo/.config/rofi/hypr-menu.env`
- Modify: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/config/dotfiles.json`
- Test: `/home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair/tests/helpers/hypr-transition-menu.bats.sh`

- [ ] **Step 1: Write failing transition test**

Create `tests/helpers/hypr-transition-menu.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-transition-menu"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/config/rofi"
CALLS="$TMP/calls.log"
: >"$CALLS"
fail() { echo "FAIL: $*" >&2; cat "$CALLS" >&2; exit 1; }

cat >"$TMP/bin/rofi" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'limefrenzy - HyDE vertical slide'
SH
chmod +x "$TMP/bin/rofi"
for cmd in hyprctl notify-send; do
  cat >"$TMP/bin/$cmd" <<'SH'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >>"$CALLS"
SH
  chmod +x "$TMP/bin/$cmd"
done

export PATH="$TMP/bin:$PATH" XDG_CONFIG_HOME="$TMP/config" CALLS
printf 'HYPR_ROFI_SCALE=1.25\n' >"$TMP/config/rofi/hypr-menu.env"
"$SCRIPT"
grep -Fq 'HYPR_WORKSPACE_ANIMATION=limefrenzy' "$TMP/config/rofi/hypr-menu.env" || fail "preset not saved"
grep -Fq 'hyprctl reload' "$CALLS" || fail "hyprctl reload not called"

bash -n "$SCRIPT"
grep -Fq 'Transitions' "$ROOT/config/shared/.local/bin/hypr-main-menu" || fail "main menu missing transitions"
grep -Fq 'HYPR_WORKSPACE_ANIMATION' "$ROOT/config/shared/.config/hypr/lua/look-and-feel.lua" || fail "lua missing env read"
grep -Fq 'limefrenzy' "$ROOT/config/shared/.config/hypr/lua/look-and-feel.lua" || fail "lua missing limefrenzy preset"
grep -Fq '".local/bin/hypr-transition-menu"' "$ROOT/config/dotfiles.json" || fail "manifest missing transition helper"

echo "hypr transition menu test passed"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
bash tests/helpers/hypr-transition-menu.bats.sh
```

Expected: FAIL because script/menu/preset missing.

- [ ] **Step 3: Implement `hypr-transition-menu`**

Script behavior:

- source `hypr-rofi-lib` if present;
- list presets:
  - `fade - Current soft fade`
  - `slide - Horizontal slide`
  - `slidevert - Vertical slide`
  - `slidefade - Slide fade 20%`
  - `slidefadevert - Vertical slide fade 20%`
  - `hyde - HyDE wind`
  - `limefrenzy - HyDE vertical slide`
  - `off - Disable workspace animation`
- write `HYPR_WORKSPACE_ANIMATION=<preset>` to `${XDG_CONFIG_HOME:-$HOME/.config}/rofi/hypr-menu.env`, replacing existing line or appending;
- call `hyprctl reload`;
- notify selected preset.

- [ ] **Step 4: Update Lua presets**

In `look-and-feel.lua`, add:

```lua
local function workspace_animation_preset()
  local value = os.getenv("HYPR_WORKSPACE_ANIMATION") or "fade"
  local presets = {
    fade = { enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" },
    slide = { enabled = true, speed = 5, bezier = "wind", style = "slide" },
    slidevert = { enabled = true, speed = 5, bezier = "wind", style = "slidevert" },
    slidefade = { enabled = true, speed = 5, bezier = "wind", style = "slidefade 20%" },
    slidefadevert = { enabled = true, speed = 5, bezier = "wind", style = "slidefadevert 20%" },
    hyde = { enabled = true, speed = 5, bezier = "wind" },
    limefrenzy = { enabled = true, speed = 5, bezier = "overshot", style = "slidevert" },
    off = { enabled = false, speed = 1, bezier = "default" },
  }
  return presets[value] or presets.fade
end
```

Also define curves used by presets:

```lua
hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.18, 0.95 }, { 0.22, 1.03 } } })
```

Replace hardcoded workspace animation with preset table.

- [ ] **Step 5: Add menu entry and host defaults**

In `hypr-main-menu`, add row `󰹹 Transitions` and case action:

```bash
*'Transitions') exec "$bin_dir/hypr-transition-menu" ;;
```

In host Rofi env files for orgm and lenovo, add default:

```bash
HYPR_WORKSPACE_ANIMATION=fade
```

Add `".local/bin/hypr-transition-menu"` to manifest shared paths.

- [ ] **Step 6: Verify and commit**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
chmod +x config/shared/.local/bin/hypr-transition-menu tests/helpers/hypr-transition-menu.bats.sh
bash tests/helpers/hypr-transition-menu.bats.sh
bash -n config/shared/.local/bin/hypr-transition-menu
git add config/shared/.local/bin/hypr-transition-menu config/shared/.local/bin/hypr-main-menu config/shared/.config/hypr/lua/look-and-feel.lua config/hosts/orgm/.config/rofi/hypr-menu.env config/hosts/lenovo/.config/rofi/hypr-menu.env config/dotfiles.json tests/helpers/hypr-transition-menu.bats.sh
git commit -m "feat: add hyprland transition picker"
```

---

### Task 6: Final verification and sync preview

**Files:**
- No new files unless fixing verification failures.

- [ ] **Step 1: Run dotfiles verification**

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/app-waybar-hypr-repair
go test ./...
for t in tests/helpers/*.bats.sh; do bash "$t"; done
python3 -m json.tool config/shared/.config/waybar-hypr/config >/dev/null
python3 -m json.tool config/shared/.config/waybar/config >/dev/null
```

Expected: all commands exit 0.

- [ ] **Step 2: Run NixOS verification**

```bash
cd /home/osmarg/Hobby/nixos/.worktrees/app-waybar-hypr-repair
go test ./...
nix flake check --no-build
```

Expected: all commands exit 0 or documented external constraint.

- [ ] **Step 3: Host app audit**

Run from dotfiles worktree:

```bash
python3 - <<'PY'
from pathlib import Path
import shlex, subprocess
base=Path.cwd()
issues=[]
flatpaks=set(subprocess.run(['distrobox-host-exec','sh','-lc','flatpak list --app --columns=application 2>/dev/null || true'],text=True,stdout=subprocess.PIPE).stdout.split())
def host_has(cmd):
    return subprocess.run(['distrobox-host-exec','sh','-lc',f'command -v {shlex.quote(cmd)} >/dev/null 2>&1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
for root in [base/'config/hosts/orgm/.local/share/applications', base/'config/hosts/lenovo/.local/share/applications', base/'config/shared/.local/share/applications']:
    if not root.exists(): continue
    for f in root.glob('*.desktop'):
        for line in f.read_text(errors='ignore').splitlines():
            if not line.startswith('Exec='): continue
            parts=shlex.split(line[5:])
            if not parts: continue
            if parts[0]=='flatpak' and len(parts)>2 and parts[1]=='run' and parts[2] not in flatpaks:
                issues.append((str(f), 'missing flatpak', parts[2]))
            elif parts[0] not in {'sh','bash','fish','env','distrobox-enter'} and not parts[0].startswith('/home/') and not host_has(parts[0]):
                issues.append((str(f), 'missing command', parts[0]))
print('\n'.join(map(str, issues)))
raise SystemExit(1 if issues else 0)
PY
```

Expected: no output, exit 0.

- [ ] **Step 4: orgm-dot preview**

Run from dotfiles worktree:

```bash
distrobox-host-exec orgm-dot diff
```

Expected: diff shows intended changes only. Do not run `orgm-dot sync` until user approves final preview.

- [ ] **Step 5: Commit fixes if verification required edits**

If any verification fix was needed:

```bash
git add <changed-files>
git commit -m "fix: complete app waybar hyprland verification"
```
