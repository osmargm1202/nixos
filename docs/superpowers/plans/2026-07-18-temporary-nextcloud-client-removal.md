# Temporary Nextcloud Client Removal Implementation Plan

<!-- markdownlint-disable MD013 -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Nextcloud desktop package and four declarative autostarts while preserving all user data and configuration.

**Architecture:** Delete package/startup entries directly and use Git history for future restoration. A focused contract test proves removal while protecting AGE key references under `~/Nextcloud`.

**Tech Stack:** NixOS modules, Hyprland Lua, Niri KDL, Labwc shell autostart, Bash tests, Git.

## Global Constraints

- Remove `nextcloud-client` from `nixos/common.nix`.
- Remove autostarts from classic Hyprland, Caelestia, Niri, and Labwc.
- Do not delete or modify `~/Nextcloud`, Nextcloud account state, credentials, cache, or configuration.
- Preserve AGE key paths and unrelated Nextcloud directory references.
- Preserve unrelated dirty Caelestia, Herdr, Kitty, and Yazi working-tree changes.
- Commit and push only intended source/test/docs files.

---

### Task 1: Remove package and autostarts

**Files:**

- Create: `tests/nextcloud-client-disabled.bats.sh`
- Modify: `nixos/common.nix:231-241`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua:8-18`
- Modify: `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua:6-16`
- Modify: `dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl:1-4`
- Modify: `dotfiles/config/profiles/labwc/.config/labwc/autostart:32-43`

**Interfaces:**

- Consumes: current package/autostart declarations.
- Produces: desktop configurations with no installed or auto-launched Nextcloud client.

- [ ] **Step 1: Write the failing removal contract**

Create `tests/nextcloud-client-disabled.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Fq "$pattern" "$file"; then
    fail "unexpected '$pattern' in $file"
  fi
}

assert_absent 'nextcloud-client' "$ROOT/nixos/common.nix"
assert_absent 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
assert_absent 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua"
assert_absent 'spawn-at-startup "nextcloud"' "$ROOT/dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl"
assert_absent 'nextcloud --background' "$ROOT/dotfiles/config/profiles/labwc/.config/labwc/autostart"

grep -Fq 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/shared/.config/fish/age.fish" || fail "shared AGE Nextcloud path must remain"
grep -Fq 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/lenovo/.config/fish/age-host.fish" || fail "Lenovo AGE Nextcloud path must remain"
grep -Fq 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/orgm/.config/fish/age-host.fish" || fail "orgm AGE Nextcloud path must remain"

printf 'PASS: Nextcloud client package and autostarts disabled\n'
```

- [ ] **Step 2: Verify RED**

Run:

```bash
chmod +x tests/nextcloud-client-disabled.bats.sh
bash tests/nextcloud-client-disabled.bats.sh
```

Expected: FAIL on `nextcloud-client` in `nixos/common.nix`.

- [ ] **Step 3: Remove the five declarations**

Delete only:

```nix
    nextcloud-client
```

```lua
  "nextcloud --background",
```

from both Lua autostarts, this Niri line:

```kdl
spawn-at-startup "nextcloud"
```

and this Labwc line:

```bash
pgrep -u "$USER" -x nextcloud >/dev/null 2>&1 || nextcloud --background >/dev/null 2>&1 &
```

- [ ] **Step 4: Verify implementation**

Run:

```bash
bash tests/nextcloud-client-disabled.bats.sh
bash -n tests/nextcloud-client-disabled.bats.sh
bash -n dotfiles/config/profiles/labwc/.config/labwc/autostart
git diff --check
for profile in terminal hyprland lenovo-hyprlandqs-caelestia labwc; do
  nix eval --raw ".#nixosConfigurations.${profile}.config.system.build.toplevel.drvPath" >/dev/null
done
```

Expected: focused test prints PASS; syntax, whitespace, and all four evaluations exit 0.

- [ ] **Step 5: Commit and push**

```bash
git add \
  tests/nextcloud-client-disabled.bats.sh \
  nixos/common.nix \
  dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua \
  dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua \
  dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl \
  dotfiles/config/profiles/labwc/.config/labwc/autostart
git commit -m "chore(desktop): disable Nextcloud client"
git push origin master
```
