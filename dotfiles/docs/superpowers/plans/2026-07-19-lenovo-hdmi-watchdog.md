# Lenovo HDMI Hotplug Watchdog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Lenovo-only NixOS service that forces an `i915` HDMI connector reprobe every ten seconds so DRM and Hyprland recover missed hotplug transitions without restarting the compositor.

**Architecture:** `p14s-gen2i.nix` imports one focused host module. That module owns a root systemd service with one persistent shell loop; the loop writes `detect` to every HDMI DRM connector and lets the kernel emit normal hotplug changes consumed by Hyprland.

**Tech Stack:** NixOS modules, systemd, Bash, DRM sysfs, shell contract tests, Nix flake evaluation.

## Global Constraints

- Apply only to Lenovo configurations through `nixos/hosts/lenovo/p14s-gen2i.nix`.
- Reprobe `/sys/class/drm/card*-HDMI-A-*/status` every exactly 10 seconds.
- Keep Linux Zen 7.0.10, BIOS/firmware, Hyprland monitor rules, resolution, refresh rate, scale, workspaces, and NVIDIA PRIME configuration unchanged.
- Do not invoke `hyprctl` or reload Hyprland configuration from the watchdog.
- Ignore missing/disappearing connectors and continue after transient sysfs write failures.
- Preserve unrelated dirty files: `dotfiles/config/shared/.config/herdr/session.json` and `dotfiles/tests/helpers/rofi-font-scale.bats.sh`.

---

### Task 1: Add the Lenovo HDMI watchdog under contract test

**Files:**

- Create: `tests/lenovo-hdmi-watchdog.bats.sh`
- Create: `nixos/hosts/lenovo/hdmi-watchdog.nix`
- Modify: `nixos/hosts/lenovo/p14s-gen2i.nix:11-18`

**Interfaces:**

- Consumes: Linux DRM connector sysfs files matching `/sys/class/drm/card*-HDMI-A-*/status`.
- Produces: systemd service `lenovo-hdmi-watchdog.service`, enabled by `multi-user.target`.

- [ ] **Step 1: Write the failing contract test**

Create `tests/lenovo-hdmi-watchdog.bats.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$ROOT/nixos/hosts/lenovo/p14s-gen2i.nix"
MODULE="$ROOT/nixos/hosts/lenovo/hdmi-watchdog.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$MODULE" ]] || fail "missing Lenovo HDMI watchdog module"
grep -Fq './hdmi-watchdog.nix' "$HOST" || fail "Lenovo hardware profile must import HDMI watchdog"

grep -Fq 'systemd.services.lenovo-hdmi-watchdog' "$MODULE" || fail "missing watchdog service"
grep -Fq 'wantedBy = [ "multi-user.target" ];' "$MODULE" || fail "watchdog must start from multi-user.target"
grep -Fq '/sys/class/drm/card*-HDMI-A-*/status' "$MODULE" || fail "watchdog must target HDMI DRM connectors"
grep -Fq "printf '%s\\n' detect" "$MODULE" || fail "watchdog must force connector detection"
grep -Fq 'sleep 10' "$MODULE" || fail "watchdog interval must be ten seconds"
grep -Fq 'Restart = "always";' "$MODULE" || fail "systemd must restart watchdog"
grep -Fq 'RestartSec = "2s";' "$MODULE" || fail "watchdog restart delay must be bounded"

mapfile -t imports < <(rg -l --fixed-strings './hdmi-watchdog.nix' "$ROOT/nixos" "$ROOT/flake.nix")
[[ "${#imports[@]}" -eq 1 && "${imports[0]}" == "$HOST" ]] ||
  fail "HDMI watchdog module must only be imported by Lenovo hardware profile"

printf 'PASS: Lenovo HDMI watchdog contract\n'
```

- [ ] **Step 2: Run the contract test and verify it fails**

Run:

```bash
bash tests/lenovo-hdmi-watchdog.bats.sh
```

Expected: exit 1 with `FAIL: missing Lenovo HDMI watchdog module`.

- [ ] **Step 3: Implement the minimal NixOS service**

Create `nixos/hosts/lenovo/hdmi-watchdog.nix` with:

```nix
{ ... }:

{
  systemd.services.lenovo-hdmi-watchdog = {
    description = "Force detection of Lenovo HDMI DRM connectors";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "2s";
    };

    script = ''
      while true; do
        for status in /sys/class/drm/card*-HDMI-A-*/status; do
          [ -e "$status" ] || continue
          if ! printf '%s\n' detect > "$status"; then
            echo "lenovo-hdmi-watchdog: failed to reprobe $status" >&2
          fi
        done
        sleep 10
      done
    '';
  };
}
```

Add the import immediately after `./webapps.nix` in `nixos/hosts/lenovo/p14s-gen2i.nix`:

```nix
  imports = [
    ./webapps.nix
    ./hdmi-watchdog.nix
    # T500 builds the NVIDIA kernel module too; needs the zen 7.0.10 pin
```

- [ ] **Step 4: Run focused static validation**

Run:

```bash
bash tests/lenovo-hdmi-watchdog.bats.sh
git diff --check -- \
  tests/lenovo-hdmi-watchdog.bats.sh \
  nixos/hosts/lenovo/hdmi-watchdog.nix \
  nixos/hosts/lenovo/p14s-gen2i.nix
```

Expected: `PASS: Lenovo HDMI watchdog contract`; `git diff --check` prints nothing and exits 0.

- [ ] **Step 5: Evaluate host scoping and service policy**

Run:

```bash
nix eval --raw \
  .#nixosConfigurations.lenovo-hyprland.config.systemd.services.lenovo-hdmi-watchdog.serviceConfig.Restart
nix eval --raw \
  .#nixosConfigurations.orgm-hyprland.config.systemd.services \
  --apply 'services: if builtins.hasAttr "lenovo-hdmi-watchdog" services then "present" else "absent"'
```

Expected: first command prints `always`; second command prints `absent`.

- [ ] **Step 6: Run proactive diagnostics and build Lenovo**

Run:

```bash
nix flake check --no-build
nix build --no-link .#nixosConfigurations.lenovo-hyprland.config.system.build.toplevel
```

Expected: both commands exit 0. Warnings about the pre-existing dirty Git tree are acceptable; evaluation or build errors are not.

- [ ] **Step 7: Commit only watchdog implementation files**

Run:

```bash
git add \
  tests/lenovo-hdmi-watchdog.bats.sh \
  nixos/hosts/lenovo/hdmi-watchdog.nix \
  nixos/hosts/lenovo/p14s-gen2i.nix
git commit -m "fix(lenovo): recover missed HDMI hotplug events"
```

Expected: one commit containing exactly the test, new module, and Lenovo import. Do not stage Herdr or Rofi changes.

---

### Task 2: Deploy and verify hotplug without compositor restart

**Files:**

- Verify only; no source changes expected.

**Interfaces:**

- Consumes: built `lenovo-hdmi-watchdog.service` from Task 1 and a physically connected HDMI display.
- Produces: runtime evidence that DRM/Hyprland hotplug recovery occurs within 10–12 seconds while the Hyprland process survives.

- [ ] **Step 1: Record pre-deployment state**

Run:

```bash
HYPR_PID_BEFORE="$(pgrep -xo Hyprland)"
printf 'Hyprland PID before: %s\n' "$HYPR_PID_BEFORE"
hyprctl monitors all -j
```

Expected: a non-empty Hyprland PID and valid monitor JSON. Keep at least one normal GUI application open for survival verification.

- [ ] **Step 2: Deploy the Lenovo configuration**

Run:

```bash
nh os switch -H lenovo-hyprland
```

Expected: activation exits 0 without requiring a reboot.

- [ ] **Step 3: Verify service health**

Run:

```bash
systemctl is-enabled lenovo-hdmi-watchdog.service
systemctl is-active lenovo-hdmi-watchdog.service
systemctl status lenovo-hdmi-watchdog.service --no-pager
```

Expected: `enabled`, `active`, and no restart loop or sysfs permission failure.

- [ ] **Step 4: Verify physical HDMI disconnect and reconnect**

Disconnect HDMI, wait at most 12 seconds, and run:

```bash
cat /sys/class/drm/card1-HDMI-A-1/status
hyprctl monitors all -j
```

Expected: DRM prints `disconnected`; Hyprland no longer lists `HDMI-A-1`.

Reconnect HDMI, wait at most 12 seconds, and run:

```bash
cat /sys/class/drm/card1-HDMI-A-1/status
wc -c < /sys/class/drm/card1-HDMI-A-1/edid
hyprctl monitors all -j
```

Expected: DRM prints `connected`, EDID size is greater than zero, and Hyprland lists the LG UltraGear output at its preferred active mode.

- [ ] **Step 5: Verify compositor and applications survived hotplug**

Run:

```bash
HYPR_PID_AFTER="$(pgrep -xo Hyprland)"
printf 'Hyprland PID after: %s\n' "$HYPR_PID_AFTER"
test "$HYPR_PID_AFTER" = "$HYPR_PID_BEFORE"
hyprctl configerrors
```

Expected: PID comparison exits 0, the test application remains open, and `hyprctl configerrors` prints no errors.

- [ ] **Step 6: Verify one suspend/resume cycle**

Suspend with HDMI connected:

```bash
systemctl suspend
```

After resume, repeat Task 2 Steps 4 and 5 once. Expected: HDMI disconnect/reconnect still converges within 10–12 seconds and Hyprland PID remains unchanged.

- [ ] **Step 7: Run final repository and session diagnostics**

Run:

```bash
bash tests/lenovo-hdmi-watchdog.bats.sh
git status --short
journalctl -u lenovo-hdmi-watchdog.service -b --no-pager | tail -n 100
```

Expected: contract passes; only pre-existing Herdr/Rofi changes remain dirty; watchdog journal has no persistent errors.

If Hyprland enters safe mode despite successful DRM transitions, stop. Preserve the new `~/.cache/hyprland/hyprlandCrashReport*.txt` and rolling log before making any plugin or compositor change.
