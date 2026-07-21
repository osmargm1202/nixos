# Lenovo LTS Kernel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run every graphical Lenovo P14s Gen 2i profile on `pkgs.linuxPackages_6_12`, then deploy and physically validate HDMI behavior.

**Architecture:** The Lenovo hardware profile replaces its Zen 7.0.10 pin import with the repository's existing LTS kernel module. A focused shell contract protects the host-local import and package selection; flake evaluation verifies all Lenovo outputs and a non-Lenovo control before the active Hyprland profile is built and deployed.

**Tech Stack:** NixOS modules, Nix flakes, Bash contract tests, `nh`, systemd-boot, Linux DRM/i915.

## Global Constraints

- Apply Linux 6.12 to `lenovo-labwc`, `lenovo-gnome`, `lenovo-hyprland`, `lenovo-hyprlandqs-caelestia`, `lenovo-i3`, `lenovo-xfce`, and `lenovo-mate`.
- Keep ORGM, Jarq, server, and terminal-only kernel selection unchanged.
- Preserve `i915.enable_guc=3`, Intel graphics packages, NVIDIA 580.142, PRIME/offload, Hyprland, BIOS, firmware, and monitor rules.
- Do not restore or merge the rejected HDMI watchdog.
- Preserve unrelated Herdr, Rofi, and concurrent Pi SDD/TDD changes.
- Treat a successful build as necessary but not sufficient; require post-reboot physical HDMI validation.

---

### Task 1: Select Linux LTS for the Lenovo Hardware Profile

**Files:**

- Create: `tests/lenovo-lts-kernel.bats.sh`
- Modify: `nixos/hosts/lenovo/p14s-gen2i.nix:11-17`
- Read: `nixos/hardware/kernel/lts.nix`
- Read: `nixos/hardware/kernel/zen70-pin.nix`

**Interfaces:**

- Consumes: `nixos/hosts/lenovo/p14s-gen2i.nix` as the shared hardware module imported by all seven graphical Lenovo outputs.
- Consumes: `nixos/hardware/kernel/lts.nix`, which sets `boot.kernelPackages = pkgs.linuxPackages_6_12`.
- Produces: a host-local LTS import and a source contract runnable with Bash.

- [ ] **Step 1: Write the failing contract test**

Create `tests/lenovo-lts-kernel.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$ROOT/nixos/hosts/lenovo/p14s-gen2i.nix"
LTS="$ROOT/nixos/hardware/kernel/lts.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq '../../hardware/kernel/lts.nix' "$HOST" ||
  fail 'Lenovo P14s must import the LTS kernel module'

if grep -Fq '../../hardware/kernel/zen70-pin.nix' "$HOST"; then
  fail 'Lenovo P14s must not import the Zen 7.0 pin'
fi

grep -Fq 'boot.kernelPackages = pkgs.linuxPackages_6_12;' "$LTS" ||
  fail 'LTS module must select linuxPackages_6_12'

printf 'PASS: all Lenovo graphical profiles select Linux LTS\n'
```

- [ ] **Step 2: Run the contract and verify RED**

Run:

```bash
bash tests/lenovo-lts-kernel.bats.sh
```

Expected:

```text
FAIL: Lenovo P14s must import the LTS kernel module
```

- [ ] **Step 3: Replace the Lenovo Zen pin import with LTS**

In `nixos/hosts/lenovo/p14s-gen2i.nix`, change only the kernel import and its comment:

```nix
  imports = [
    ./webapps.nix
    # Keep every graphical Lenovo profile on the stable LTS kernel line.
    ../../hardware/kernel/lts.nix
    ../../deskflow.nix
  ];
```

Do not modify any Intel, NVIDIA, PRIME, or power-management settings.

- [ ] **Step 4: Run the contract and verify GREEN**

Run:

```bash
bash tests/lenovo-lts-kernel.bats.sh
git diff --check -- \
  tests/lenovo-lts-kernel.bats.sh \
  nixos/hosts/lenovo/p14s-gen2i.nix
```

Expected:

```text
PASS: all Lenovo graphical profiles select Linux LTS
```

`git diff --check` must print nothing and exit 0.

- [ ] **Step 5: Evaluate every Lenovo profile and the ORGM control**

Run:

```bash
for host in \
  lenovo-labwc \
  lenovo-gnome \
  lenovo-hyprland \
  lenovo-hyprlandqs-caelestia \
  lenovo-i3 \
  lenovo-xfce \
  lenovo-mate
do
  version="$(nix eval --raw ".#nixosConfigurations.${host}.config.boot.kernelPackages.kernel.version")"
  printf '%s=%s\n' "$host" "$version"
  [[ "$version" == 6.12.* ]]
done

orgm_version="$(nix eval --raw .#nixosConfigurations.orgm-hyprland.config.boot.kernelPackages.kernel.version)"
printf 'orgm-hyprland=%s\n' "$orgm_version"
[[ "$orgm_version" == 7.0.10 ]]
```

Expected: all seven Lenovo lines start with `6.12.`; `orgm-hyprland=7.0.10`; command exits 0.

- [ ] **Step 6: Commit the tested kernel selection**

```bash
git add \
  tests/lenovo-lts-kernel.bats.sh \
  nixos/hosts/lenovo/p14s-gen2i.nix
git commit -m "fix(lenovo): switch graphical profiles to LTS kernel"
```

Expected: one commit containing exactly the contract test and Lenovo hardware-profile import change.

---

### Task 2: Build the Lenovo Hyprland System

**Files:**

- Verify: `tests/lenovo-lts-kernel.bats.sh`
- Verify: `nixos/hosts/lenovo/p14s-gen2i.nix`
- Verify: `nixos/hardware/kernel/lts.nix`

**Interfaces:**

- Consumes: Task 1's evaluated `linuxPackages_6_12` selection.
- Produces: a complete NixOS toplevel with i915 and NVIDIA 580.142 built for Linux 6.12.

- [ ] **Step 1: Format and rerun focused checks**

Run:

```bash
nix fmt -- \
  nixos/hosts/lenovo/p14s-gen2i.nix
bash tests/lenovo-lts-kernel.bats.sh
git diff --check
```

Expected: formatter exits 0, contract prints PASS, and diff check prints nothing.

- [ ] **Step 2: Run proactive diagnostics**

Run Pi LSP diagnostics on:

```text
nixos/hosts/lenovo/p14s-gen2i.nix
nixos/hardware/kernel/lts.nix
```

Expected: zero blocking errors.

- [ ] **Step 3: Build the active system closure**

Run:

```bash
nix build --no-link \
  .#nixosConfigurations.lenovo-hyprland.config.system.build.toplevel
```

Expected: exit 0. The build must include a Linux 6.12 kernel and a matching NVIDIA kernel module; do not treat evaluation alone as sufficient.

- [ ] **Step 4: Verify branch contents**

Run:

```bash
git status --short
git show --stat --oneline HEAD
git diff HEAD^ HEAD --check
git diff HEAD^ HEAD --name-only
```

Expected: clean worktree; latest implementation commit lists only:

```text
nixos/hosts/lenovo/p14s-gen2i.nix
tests/lenovo-lts-kernel.bats.sh
```

---

### Task 3: Integrate, Deploy, Reboot, and Validate HDMI

**Files:**

- Integrate: implementation commit from Task 1
- Runtime verify: `/run/current-system`
- Runtime verify: `/sys/class/drm/card*-HDMI-A-*/status`
- Runtime verify: `/sys/class/drm/card*-HDMI-A-*/edid`

**Interfaces:**

- Consumes: Task 2's successfully built Linux 6.12 NixOS closure.
- Produces: the active Lenovo system booted on Linux 6.12 with physical HDMI evidence.

- [ ] **Step 1: Integrate the isolated implementation branch**

Use `superpowers:finishing-a-development-branch`. Rebase or merge without staging or rewriting unrelated Herdr, Rofi, or Pi SDD/TDD changes. Verify the implementation commit remains limited to the two Task 1 files.

- [ ] **Step 2: Deploy the active Lenovo profile**

Run in an interactive terminal for sudo:

```bash
cd /home/osmarg/Hobby/nixos
export NH_FLAKE=/home/osmarg/Hobby/nixos
nh os switch -H lenovo-hyprland
```

Expected: activation exits 0 and `/run/current-system` points to the new `nixos-system-lenovo-hyprland` generation. Before reboot, confirm the previous generation remains listed in systemd-boot.

- [ ] **Step 3: Reboot into Linux 6.12**

Save open work, reboot normally, and select the newest generation. If boot or graphics fails, select the previous generation from systemd-boot and stop deployment work.

- [ ] **Step 4: Verify kernel and graphics after boot**

Run:

```bash
uname -r
cat /sys/module/i915/version 2>/dev/null || true
lsmod | grep -E '^(i915|nvidia)'
hyprctl version
hyprctl configerrors
```

Expected: `uname -r` starts with `6.12.`; i915 and required NVIDIA modules are loaded; Hyprland responds; config errors are empty.

- [ ] **Step 5: Validate HDMI at boot**

With monitor powered, correct HDMI input selected, and cable connected, run:

```bash
for status in /sys/class/drm/card*-HDMI-A-*/status; do
  connector="$(dirname "$status")"
  printf '%s status=%s edid=%s\n' \
    "$(basename "$connector")" \
    "$(cat "$status")" \
    "$(wc -c < "$connector/edid")"
done
hyprctl monitors all -j
```

Expected for improvement: HDMI reports `connected`, EDID byte count is greater than 0, and Hyprland lists the LG monitor.

- [ ] **Step 6: Validate physical hotplug without restarting Hyprland**

Record the compositor PID:

```bash
pgrep -f -o '/Hyprland --watchdog-fd'
```

Disconnect HDMI, wait for DRM to report `disconnected`, reconnect HDMI, and wait for `connected` plus a non-empty EDID. Re-run the PID command.

Expected: both transitions occur and the Hyprland PID remains unchanged.

- [ ] **Step 7: Validate suspend and hotplug again**

Suspend once, resume, confirm `uname -r` still reports 6.12, then repeat Step 6.

Expected: system resumes, HDMI hotplug still transitions, and Hyprland PID remains unchanged. If detection still fails, preserve kernel/i915 logs and report Linux 6.12 as a failed hypothesis rather than adding another workaround.
