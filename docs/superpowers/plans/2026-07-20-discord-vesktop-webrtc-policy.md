# Discord and Vesktop WebRTC Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Force `default_public_and_private_interfaces` for every managed Discord and Vesktop launch in desktop profiles that install Vesktop.

**Architecture:** Two focused Nix packages wrap the existing clients: Vesktop wraps `pkgs.vesktop`, while Discord forwards to the existing Flatpak package. A reusable profile module installs both wrappers and shadows Flatpak's desktop entry; Hyprland imports that module and its existing autostart helper retains compatible native/Flatpak fallbacks.

**Tech Stack:** NixOS modules, Nixpkgs wrappers, Home Manager desktop entries, Bash, Flatpak, shell contract tests.

## Global Constraints

- Use exactly `--force-webrtc-ip-handling-policy=default_public_and_private_interfaces`.
- Apply the policy to managed terminal, desktop-launcher, and Hyprland-autostart routes.
- Keep `com.discordapp.Discord` as a Flatpak package.
- Do not patch Vesktop source.
- Do not install graphical clients in terminal-only or server profiles.
- Preserve unrelated dirty working-tree files.

---

### Task 1: Add wrapped Discord and Vesktop packages

**Files:**

- Create: `nixos/packages/discord-webrtc.nix`
- Create: `nixos/packages/vesktop-webrtc.nix`
- Create: `tests/discord-vesktop-webrtc-policy.bats.sh`

**Interfaces:**

- Consumes: `pkgs.flatpak`, `pkgs.vesktop`, and optional `FLATPAK_BIN` for isolated tests.
- Produces: package binaries `bin/discord` and `bin/vesktop`; both enforce the same policy flag.

- [ ] **Step 1: Write the failing package contract**

Create executable `tests/discord-vesktop-webrtc-policy.bats.sh` with helpers that build both package files through the locked flake, execute Discord against a fake Flatpak binary, and inspect Vesktop's generated wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY='--force-webrtc-ip-handling-policy=default_public_and_private_interfaces'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

build_package() {
  local package_file="$1"
  (
    cd "$ROOT"
    nix build --no-link --print-out-paths --impure --expr "
      let
        flake = builtins.getFlake (toString ./.);
        pkgs = flake.nixosConfigurations.orgm-hyprland.pkgs;
      in pkgs.callPackage ./$package_file {}
    "
  )
}

discord_out="$(build_package nixos/packages/discord-webrtc.nix)"
vesktop_out="$(build_package nixos/packages/vesktop-webrtc.nix)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/flatpak" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >>"$CAPTURE"
if [[ "${1:-}" == info ]]; then
  [[ "${FLATPAK_INFO_FAIL:-0}" == 1 ]] && exit 1
  exit 0
fi
EOF
chmod +x "$tmp/flatpak"

CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" \
  "$discord_out/bin/discord" --start-minimized
[[ "$(grep -Fxc -- "$POLICY" "$tmp/calls")" == 1 ]] \
  || fail 'Discord wrapper must add policy exactly once'
grep -Fxq -- '--start-minimized' "$tmp/calls" \
  || fail 'Discord wrapper dropped caller argument'

: >"$tmp/calls"
CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" \
  "$discord_out/bin/discord" "$POLICY" --start-minimized
[[ "$(grep -Fxc -- "$POLICY" "$tmp/calls")" == 1 ]] \
  || fail 'Discord wrapper duplicated supplied policy'

if CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" FLATPAK_INFO_FAIL=1 \
  "$discord_out/bin/discord" 2>"$tmp/error"; then
  fail 'Discord wrapper accepted a missing Flatpak app'
fi
grep -Fq 'Discord Flatpak com.discordapp.Discord is not installed' "$tmp/error" \
  || fail 'Discord wrapper missing installation error'

grep -RFq -- "$POLICY" "$vesktop_out/bin" \
  || fail 'Vesktop wrapper missing policy'

printf 'PASS: Discord and Vesktop wrappers enforce WebRTC policy\n'
```

- [ ] **Step 2: Run the contract to verify RED**

Run:

```bash
chmod +x tests/discord-vesktop-webrtc-policy.bats.sh
bash tests/discord-vesktop-webrtc-policy.bats.sh
```

Expected: FAIL because `nixos/packages/discord-webrtc.nix` does not exist.

- [ ] **Step 3: Implement the Discord Flatpak wrapper**

Create `nixos/packages/discord-webrtc.nix`:

```nix
{
  lib,
  writeShellApplication,
  flatpak,
}:

let
  appId = "com.discordapp.Discord";
  policy = "--force-webrtc-ip-handling-policy=default_public_and_private_interfaces";
in
writeShellApplication {
  name = "discord";
  text = ''
    flatpak_bin="''${FLATPAK_BIN:-${lib.getExe flatpak}}"

    if ! "$flatpak_bin" info ${appId} >/dev/null 2>&1; then
      printf 'Discord Flatpak %s is not installed\n' ${appId} >&2
      exit 1
    fi

    has_policy=false
    for arg in "$@"; do
      case "$arg" in
        --force-webrtc-ip-handling-policy=*) has_policy=true ;;
      esac
    done

    if [[ "$has_policy" == true ]]; then
      exec "$flatpak_bin" run ${appId} "$@"
    fi
    exec "$flatpak_bin" run ${appId} ${policy} "$@"
  '';
  meta.mainProgram = "discord";
}
```

- [ ] **Step 4: Implement the Vesktop package wrapper**

Create `nixos/packages/vesktop-webrtc.nix`:

```nix
{
  symlinkJoin,
  vesktop,
  makeWrapper,
}:

symlinkJoin {
  name = "vesktop-webrtc-${vesktop.version}";
  paths = [ vesktop ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/vesktop" \
      --add-flags "--force-webrtc-ip-handling-policy=default_public_and_private_interfaces"
  '';
  meta.mainProgram = "vesktop";
}
```

- [ ] **Step 5: Run package contract and syntax checks**

Run:

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
bash -n tests/discord-vesktop-webrtc-policy.bats.sh
nixfmt --check nixos/packages/discord-webrtc.nix nixos/packages/vesktop-webrtc.nix
```

Expected: PASS, shell syntax clean, Nix formatting clean.

- [ ] **Step 6: Commit wrapped packages**

```bash
git add \
  nixos/packages/discord-webrtc.nix \
  nixos/packages/vesktop-webrtc.nix \
  tests/discord-vesktop-webrtc-policy.bats.sh
git commit -m "feat(desktop): wrap Discord and Vesktop WebRTC policy"
```

---

### Task 2: Install wrappers through a reusable desktop profile

**Files:**

- Create: `nixos/profiles/vesktop.nix`
- Modify: `nixos/profiles/common_hyprland.nix:18-22,318-320`
- Test: `tests/discord-vesktop-webrtc-policy.bats.sh`

**Interfaces:**

- Consumes: wrapper packages from Task 1 and Home Manager's `xdg.desktopEntries` option.
- Produces: reusable `vesktop.nix` profile module, installed commands, and user override `com.discordapp.Discord.desktop`.

- [ ] **Step 1: Extend the contract with module assertions**

Append before the final PASS line in `tests/discord-vesktop-webrtc-policy.bats.sh`:

```bash
grep -Fq './vesktop.nix' "$ROOT/nixos/profiles/common_hyprland.nix" \
  || fail 'common Hyprland profile does not import vesktop module'
if grep -Eq '^[[:space:]]+vesktop[[:space:]]*$' "$ROOT/nixos/profiles/common_hyprland.nix"; then
  fail 'raw Vesktop package remains in common Hyprland package list'
fi

for profile in orgm-hyprland orgm-hyprlandqs-caelestia; do
  packages="$(cd "$ROOT" && nix eval ".#nixosConfigurations.$profile.config.environment.systemPackages" --json)"
  jq -e 'any(.[]; test("vesktop-webrtc-"))' <<<"$packages" >/dev/null \
    || fail "wrapped Vesktop missing from $profile"
  jq -e 'any(.[]; test("discord-"))' <<<"$packages" >/dev/null \
    || fail "Discord wrapper missing from $profile"
done

exec_line="$(cd "$ROOT" && nix eval --raw \
  '.#nixosConfigurations.orgm-hyprland.config.home-manager.users.osmarg.xdg.desktopEntries."com.discordapp.Discord".exec')"
[[ "$exec_line" == */bin/discord\ %U ]] \
  || fail "unexpected Discord desktop Exec: $exec_line"
```

- [ ] **Step 2: Run contract to verify RED**

Run:

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
```

Expected: FAIL because `common_hyprland.nix` does not import `vesktop.nix`.

- [ ] **Step 3: Create the reusable profile module**

Create `nixos/profiles/vesktop.nix`:

```nix
{
  pkgs,
  userName ? "osmarg",
  ...
}:

let
  discord = pkgs.callPackage ../packages/discord-webrtc.nix { };
  vesktop = pkgs.callPackage ../packages/vesktop-webrtc.nix { };
in
{
  environment.systemPackages = [
    discord
    vesktop
  ];

  home-manager.users.${userName}.xdg.desktopEntries."com.discordapp.Discord" = {
    name = "Discord";
    genericName = "Internet Messenger";
    comment = "All-in-one voice and text chat";
    exec = "${discord}/bin/discord %U";
    icon = "com.discordapp.Discord";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "InstantMessaging"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
    settings = {
      StartupWMClass = "discord";
      X-Flatpak = "com.discordapp.Discord";
    };
  };
}
```

- [ ] **Step 4: Import module and remove raw Vesktop**

In `nixos/profiles/common_hyprland.nix`, add `./vesktop.nix` to `imports` and delete only the raw `vesktop` line under `# Communication`.

- [ ] **Step 5: Run module contract and Nix checks**

Run:

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
nixfmt --check nixos/profiles/vesktop.nix nixos/profiles/common_hyprland.nix
for profile in orgm-hyprland orgm-hyprlandqs-caelestia; do
  nix eval --raw ".#nixosConfigurations.$profile.config.system.build.toplevel.drvPath" >/dev/null
done
```

Expected: PASS and both profiles evaluate.

- [ ] **Step 6: Commit reusable profile**

```bash
git add \
  nixos/profiles/vesktop.nix \
  nixos/profiles/common_hyprland.nix \
  tests/discord-vesktop-webrtc-policy.bats.sh
git commit -m "feat(desktop): enforce Discord Vesktop WebRTC policy"
```

---

### Task 3: Harden Hyprland Discord autostart

**Files:**

- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord`
- Test: `tests/discord-vesktop-webrtc-policy.bats.sh`

**Interfaces:**

- Consumes: managed `discord` wrapper when available; native `discord`/`Discord` and Flatpak remain transition fallbacks.
- Produces: every autostart branch passes the required policy explicitly.

- [ ] **Step 1: Add failing autostart assertions**

Append before the final PASS line in `tests/discord-vesktop-webrtc-policy.bats.sh`:

```bash
helper="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord"
grep -Fq 'command -v Discord' "$helper" \
  || fail 'uppercase Discord fallback missing'
[[ "$(grep -Fc '"$policy"' "$helper")" == 3 ]] \
  || fail 'not every Discord autostart branch carries policy'
```

- [ ] **Step 2: Run contract to verify RED**

Run:

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
```

Expected: FAIL with `uppercase Discord fallback missing`.

- [ ] **Step 3: Implement all executable fallbacks**

Replace `dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord` with:

```sh
#!/bin/sh
set -eu

policy='--force-webrtc-ip-handling-policy=default_public_and_private_interfaces'

if command -v discord >/dev/null 2>&1; then
  exec discord "$policy" --start-minimized
fi

if command -v Discord >/dev/null 2>&1; then
  exec Discord "$policy" --start-minimized
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info com.discordapp.Discord >/dev/null 2>&1; then
  exec flatpak run com.discordapp.Discord "$policy" --start-minimized
fi
```

- [ ] **Step 4: Verify full WebRTC contract**

Run:

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
bash -n dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord
git diff --check
```

Expected: PASS and clean syntax/diff.

- [ ] **Step 5: Commit autostart hardening**

```bash
git add \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord \
  tests/discord-vesktop-webrtc-policy.bats.sh
git commit -m "fix(hypr): enforce Discord WebRTC policy at startup"
```

---

### Task 4: Build, deploy, and inspect managed launchers

**Files:**

- No source changes expected.

**Interfaces:**

- Consumes: completed wrapper packages, profile module, desktop entry, and autostart helper.
- Produces: active NixOS generation with managed Discord/Vesktop policy.

- [ ] **Step 1: Run focused and project diagnostics**

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
nix flake check --no-build
```

Expected: PASS.

- [ ] **Step 2: Build active system**

```bash
nh os build
```

Expected: system toplevel builds successfully.

- [ ] **Step 3: Activate configuration**

```bash
nh os switch
```

Expected: NixOS and Home Manager activation complete successfully.

- [ ] **Step 4: Inspect effective commands and desktop launcher**

```bash
command -v vesktop
command -v discord
grep -F 'Exec=' "$HOME/.local/share/applications/com.discordapp.Discord.desktop"
grep -RF -- '--force-webrtc-ip-handling-policy=default_public_and_private_interfaces' \
  "$(readlink -f "$(command -v vesktop)")" "$(readlink -f "$(command -v discord)")"
```

Expected: commands resolve through `/run/current-system/sw/bin`; desktop `Exec=` points at managed Discord wrapper; generated wrappers contain policy.

- [ ] **Step 5: Record manual runtime check**

With Tailscale enabled, start one Discord call from Discord and one from Vesktop. Expected: DTLS connects rather than remaining stuck. If interactive call testing is unavailable, report it explicitly as the only remaining user validation.
