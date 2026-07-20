# Nextcloud Client Restoration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the Nextcloud desktop package and every autostart removed by the temporary test commit `c5c71ba`.

**Architecture:** Reverse only the six behavior/test edits from the temporary removal, preserving the previously proven environment-specific launch commands. A positive shell contract proves the package, Hyprland, Caelestia, Niri, and Labwc declarations are present while protecting AGE paths under `~/Nextcloud`.

**Tech Stack:** NixOS modules, Hyprland Lua, Niri KDL, Labwc shell autostart, Bash contract tests.

## Global Constraints

- Restore `nextcloud-client` in `nixos/common.nix`.
- Restore all four desktop autostarts exactly as they existed before commit `c5c71ba`.
- Ensure both Hyprland profiles execute `nextcloud --background` at session startup.
- Do not modify `~/Nextcloud`, account state, credentials, cache, or synchronized data.
- Preserve AGE paths and unrelated dirty working-tree changes.
- Do not replace the restored commands with a new systemd service.

---

### Task 1: Restore package and desktop autostarts

**Files:**

- Modify: `tests/nextcloud-client-disabled.bats.sh`
- Modify: `nixos/common.nix:231-241`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua:8-18`
- Modify: `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua:6-16`
- Modify: `dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl:1-5`
- Modify: `dotfiles/config/profiles/labwc/.config/labwc/autostart:34-43`

**Interfaces:**

- Consumes: existing Nix package list and environment-specific startup arrays/files.
- Produces: installed `nextcloud` command plus automatic startup in Hyprland, Caelestia, Niri, and Labwc.

- [ ] **Step 1: Convert the removal test into a failing restoration contract**

Replace `tests/nextcloud-client-disabled.bats.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  if ! grep -Fq "$pattern" "$file"; then
    fail "missing '$pattern' in $file"
  fi
}

assert_present 'nextcloud-client' "$ROOT/nixos/common.nix"
assert_present 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
assert_present 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua"
assert_present 'spawn-at-startup "nextcloud"' "$ROOT/dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl"
assert_present 'nextcloud --background' "$ROOT/dotfiles/config/profiles/labwc/.config/labwc/autostart"

assert_present 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/shared/.config/fish/age.fish"
assert_present 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/lenovo/.config/fish/age-host.fish"
assert_present 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/orgm/.config/fish/age-host.fish"

printf 'PASS: Nextcloud client package and desktop autostarts restored\n'
```

- [ ] **Step 2: Run restoration contract to verify RED**

Run:

```bash
bash tests/nextcloud-client-disabled.bats.sh
```

Expected: FAIL with `missing 'nextcloud-client' in .../nixos/common.nix`.

- [ ] **Step 3: Restore the Nix package**

In `nixos/common.nix`, add `nextcloud-client` after `fzf` in `environment.systemPackages`:

```nix
    fzf
    nextcloud-client
    gtk3
```

- [ ] **Step 4: Restore both Hyprland startup entries**

In each Lua `exec_once` array, add this line immediately after the `hypr-battery-alerts` command:

```lua
  "nextcloud --background",
```

Files:

- `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua`
- `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua`

- [ ] **Step 5: Restore Niri startup**

In `dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl`, add after the opening comment:

```kdl
spawn-at-startup "nextcloud"
```

- [ ] **Step 6: Restore guarded Labwc startup**

In `dotfiles/config/profiles/labwc/.config/labwc/autostart`, add before the Discord comment:

```bash
pgrep -u "$USER" -x nextcloud >/dev/null 2>&1 || nextcloud --background >/dev/null 2>&1 &
```

- [ ] **Step 7: Run focused tests and syntax checks**

Run:

```bash
bash tests/nextcloud-client-disabled.bats.sh
bash -n tests/nextcloud-client-disabled.bats.sh
bash -n dotfiles/config/profiles/labwc/.config/labwc/autostart
luac -p dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua
luac -p dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua
git diff --check
```

Expected: PASS and all syntax checks clean.

- [ ] **Step 8: Evaluate affected profiles**

Run:

```bash
for profile in orgm-hyprland orgm-hyprlandqs-caelestia labwc; do
  nix eval --raw ".#nixosConfigurations.$profile.config.system.build.toplevel.drvPath" >/dev/null
done
```

Expected: all three configurations evaluate.

- [ ] **Step 9: Commit restoration**

```bash
git add \
  tests/nextcloud-client-disabled.bats.sh \
  nixos/common.nix \
  dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua \
  dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua \
  dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl \
  dotfiles/config/profiles/labwc/.config/labwc/autostart
git commit -m "feat(desktop): restore Nextcloud client autostart"
```

---

### Task 2: Deploy and confirm Nextcloud availability

**Files:**

- No source changes expected.

**Interfaces:**

- Consumes: restored package and startup declarations.
- Produces: active NixOS generation containing `nextcloud-client`.

- [ ] **Step 1: Build active system**

```bash
nh os build
```

Expected: system toplevel builds successfully with `nextcloud-client` in its closure.

- [ ] **Step 2: Activate configuration**

```bash
nh os switch
```

Expected: NixOS and Home Manager activation complete successfully.

- [ ] **Step 3: Confirm installed command and declarative startup**

```bash
command -v nextcloud
grep -F 'nextcloud --background' \
  "$HOME/.config/hypr/lua/autostart.lua"
```

Expected: `nextcloud` resolves from `/run/current-system/sw/bin`; active Hyprland autostart contains the background launch command.

- [ ] **Step 4: Start in current session without duplication**

```bash
pgrep -u "$USER" -x nextcloud >/dev/null 2>&1 || nextcloud --background
```

Expected: one Nextcloud client process runs. Future Hyprland logins start it declaratively.
