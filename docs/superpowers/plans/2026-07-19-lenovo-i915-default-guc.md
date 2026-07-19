# Lenovo i915 Default GuC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the forced `i915.enable_guc=3` parameter from all graphical Lenovo P14s Gen 2i profiles and test HDMI detection with Tiger Lake's Linux 6.12 default GuC-disabled behavior.

**Architecture:** The shared Lenovo hardware module stops overriding i915 GuC policy while retaining Linux 6.12 and every Intel/NVIDIA/PRIME setting. A focused source contract and flake evaluations protect the one-variable experiment before a full NixOS build, deployment, reboot, and physical HDMI validation.

**Tech Stack:** NixOS modules, Nix flakes, Bash contract tests, Linux i915, `nh`, systemd-boot.

## Global Constraints

- Remove only `i915.enable_guc=3` from the Lenovo P14s hardware module.
- Keep Linux LTS 6.12, initrd i915 loading, Intel graphics packages, NVIDIA 580.142, PRIME/offload, Hyprland, BIOS, firmware, and monitor rules unchanged.
- Apply the change to all seven graphical Lenovo outputs through `p14s-gen2i.nix`.
- Do not add `i915.enable_guc=0`; Linux 6.12 automatic policy already resolves to 0 on Tiger Lake.
- Do not restore the rejected HDMI watchdog.
- Preserve unrelated Herdr, Rofi, and Pi subagent changes.
- Treat generation 105 as the Linux 6.12 plus GuC=3 rollback target.

---

### Task 1: Stop Forcing GuC on Lenovo

**Files:**

- Create: `tests/lenovo-i915-default-guc.bats.sh`
- Modify: `nixos/hosts/lenovo/p14s-gen2i.nix`
- Verify: `tests/lenovo-lts-kernel.bats.sh`

**Interfaces:**

- Consumes: `p14s-gen2i.nix`, imported by all seven graphical Lenovo outputs.
- Produces: Lenovo kernel arguments without an explicit `i915.enable_guc` override.

- [ ] **Step 1: Write the failing contract test**

Create `tests/lenovo-i915-default-guc.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$ROOT/nixos/hosts/lenovo/p14s-gen2i.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -Fq 'i915.enable_guc' "$HOST"; then
  fail 'Lenovo P14s must use the kernel default GuC policy'
fi

grep -Fq '../../hardware/kernel/lts.nix' "$HOST" ||
  fail 'Lenovo P14s must remain on Linux LTS'

printf 'PASS: Lenovo P14s uses default i915 GuC policy\n'
```

- [ ] **Step 2: Run the contract and verify RED**

Run:

```bash
bash tests/lenovo-i915-default-guc.bats.sh
```

Expected:

```text
FAIL: Lenovo P14s must use the kernel default GuC policy
```

- [ ] **Step 3: Remove only the forced GuC parameter**

Delete this line from `nixos/hosts/lenovo/p14s-gen2i.nix`:

```nix
boot.kernelParams = [ "i915.enable_guc=3" ];
```

Leave this line unchanged:

```nix
boot.initrd.kernelModules = [ "i915" ];
```

Do not add a replacement kernel parameter.

- [ ] **Step 4: Run focused contracts and verify GREEN**

Run:

```bash
bash tests/lenovo-i915-default-guc.bats.sh
bash tests/lenovo-lts-kernel.bats.sh
git diff --check -- \
  tests/lenovo-i915-default-guc.bats.sh \
  nixos/hosts/lenovo/p14s-gen2i.nix
```

Expected:

```text
PASS: Lenovo P14s uses default i915 GuC policy
PASS: all Lenovo graphical profiles select Linux LTS
```

`git diff --check` must print nothing and exit 0.

- [ ] **Step 5: Evaluate all Lenovo kernel argument lists**

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
  params="$(nix eval --json ".#nixosConfigurations.${host}.config.boot.kernelParams")"
  printf '%s=%s\n' "$host" "$params"
  jq -e '((index("i915.enable_guc=3") == null) and ((map(select(startswith("i915.enable_guc="))) | length) == 0))' <<< "$params" >/dev/null

done

version="$(nix eval --raw .#nixosConfigurations.lenovo-hyprland.config.boot.kernelPackages.kernel.version)"
printf 'lenovo-hyprland kernel=%s\n' "$version"
[[ "$version" == 6.12.* ]]
```

Expected: all seven argument arrays lack every `i915.enable_guc=` value; kernel starts with `6.12.`; command exits 0.

- [ ] **Step 6: Commit the tested change**

```bash
git add \
  tests/lenovo-i915-default-guc.bats.sh \
  nixos/hosts/lenovo/p14s-gen2i.nix
git commit -m "fix(lenovo): use default i915 GuC policy"
```

Expected: one implementation commit containing exactly the test and Lenovo hardware module.

---

### Task 2: Build the GuC-Default Lenovo System

**Files:**

- Verify: `tests/lenovo-i915-default-guc.bats.sh`
- Verify: `tests/lenovo-lts-kernel.bats.sh`
- Verify: `nixos/hosts/lenovo/p14s-gen2i.nix`

**Interfaces:**

- Consumes: Task 1's kernel argument removal.
- Produces: a complete Linux 6.12.93/NVIDIA 580.142 system closure without forced GuC.

- [ ] **Step 1: Format and rerun checks**

Run:

```bash
nix fmt -- nixos/hosts/lenovo/p14s-gen2i.nix
bash tests/lenovo-i915-default-guc.bats.sh
bash tests/lenovo-lts-kernel.bats.sh
git diff --check
```

Expected: formatter exits 0, both contracts print PASS, and diff check prints nothing.

- [ ] **Step 2: Run proactive diagnostics**

Run Pi LSP diagnostics on:

```text
nixos/hosts/lenovo/p14s-gen2i.nix
tests/lenovo-i915-default-guc.bats.sh
```

Expected: zero blocking errors.

- [ ] **Step 3: Build the complete active profile**

Run:

```bash
nix build --no-link \
  .#nixosConfigurations.lenovo-hyprland.config.system.build.toplevel
```

Expected: exit 0 with Linux 6.12.93 and NVIDIA 580.142.

- [ ] **Step 4: Verify branch scope**

Run:

```bash
git status --short
git show --stat --oneline HEAD
git diff HEAD^ HEAD --check
git diff HEAD^ HEAD --name-only
```

Expected: clean worktree and exactly:

```text
nixos/hosts/lenovo/p14s-gen2i.nix
tests/lenovo-i915-default-guc.bats.sh
```

---

### Task 3: Integrate, Deploy, and Validate GuC-Disabled Runtime

**Files:**

- Integrate: Task 1 implementation commit
- Runtime verify: `/proc/cmdline`
- Runtime verify: `/sys/class/drm/card*-HDMI-A-*/status`
- Runtime verify: `/sys/class/drm/card*-HDMI-A-*/edid`

**Interfaces:**

- Consumes: Task 2's successfully built closure.
- Produces: physical evidence for or against forced GuC as the HDMI cause.

- [ ] **Step 1: Integrate the isolated branch**

Use `superpowers:finishing-a-development-branch`. Merge locally only after focused contracts and the full build pass. Preserve unrelated dirty files and verify implementation scope remains exactly two files.

- [ ] **Step 2: Deploy Lenovo Hyprland**

Run interactively:

```bash
cd /home/osmarg/Hobby/nixos
export NH_FLAKE=/home/osmarg/Hobby/nixos
nh os switch -H lenovo-hyprland
```

Expected: switch exits 0; new boot entry reports Linux 6.12.93 and its options omit `i915.enable_guc=3`. Generation 105 remains available.

- [ ] **Step 3: Reboot into the new generation**

Save open work and reboot normally. If graphics fail, boot generation 105 and stop.

- [ ] **Step 4: Verify the one-variable runtime change**

Run:

```bash
uname -r
cat /proc/cmdline
journalctl -b -k --no-pager | grep -E 'GuC|HuC|SLPC|i915'
lsmod | grep -E '^(i915|nvidia)'
hyprctl configerrors
```

Expected:

- kernel starts with `6.12.`
- command line has no `i915.enable_guc`
- i915 log does not report GuC submission or SLPC enabled
- i915 and NVIDIA modules are loaded
- Hyprland configuration errors are empty

- [ ] **Step 5: Validate HDMI at boot**

With HDMI connected, monitor powered, and correct input selected:

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

Positive result: HDMI is connected, EDID size is greater than zero, and Hyprland lists the LG monitor.

Negative result: HDMI remains disconnected with EDID 0. Record GuC as a failed hypothesis and do not add another workaround in this task.

- [ ] **Step 6: Validate hotplug and suspend only after a positive boot result**

Record Hyprland PID, perform repeated disconnect/reconnect, suspend/resume, and repeat hotplug. Require connector transitions, non-empty EDID after reconnect, and unchanged Hyprland PID within the boot session.
