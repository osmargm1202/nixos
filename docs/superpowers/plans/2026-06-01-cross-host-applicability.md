# Cross-Host Applicability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure Lenovo, Ero, server, and generic NixOS targets only receive applicable host changes and can update via rebuild plus `orgm-dot sync`.

**Architecture:** Keep host-specific SDDM output config optional unless the host provides `nixos/hosts/<host>/sddm-kwinoutputconfig.json`. Update the Nix flake lock so packaged `orgm-dot` includes dotfiles local-default seeding. Verify each target by Nix dry-run and dotfiles simulated sync.

**Tech Stack:** Nix flakes, NixOS modules, `orgm-dot`, Go tests in dotfiles.

---

### Task 1: Make Hyprland SDDM display config host-optional

**Files:**
- Modify: `nixos/profiles/hyprland.nix`

- [ ] **Step 1: Use existing failing verification**

Run:

```bash
cd /home/osmarg/Hobby/nixos
distrobox-host-exec nix build .#nixosConfigurations.lenovo-hyprland.config.system.build.toplevel --dry-run
```

Expected before fix: fails with missing `nixos/hosts/lenovo/sddm-kwinoutputconfig.json`.

- [ ] **Step 2: Gate SDDM kwinoutput config by path existence**

In `nixos/profiles/hyprland.nix`, define `sddmKwinOutputConfig` and `hasSddmKwinOutputConfig`, then wrap `environment.etc` and tmpfiles rule in `lib.mkIf hasSddmKwinOutputConfig`.

- [ ] **Step 3: Verify Lenovo and generic Hyprland dry-run**

Run:

```bash
cd /home/osmarg/Hobby/nixos
for cfg in orgm-hyprland lenovo-hyprland hyprland; do
  distrobox-host-exec nix build ".#nixosConfigurations.$cfg.config.system.build.toplevel" --dry-run >/dev/null
done
```

Expected: all exit 0. `orgm-hyprland` still uses its host SDDM JSON; Lenovo/generic skip that optional file.

### Task 2: Update dotfiles flake input for orgm-dot package

**Files:**
- Modify: `flake.lock`

- [ ] **Step 1: Confirm old lock does not seed local defaults**

Run:

```bash
cd /home/osmarg/Hobby/nixos
distrobox-host-exec nix build .#orgm-dot --print-out-paths --no-link
```

Expected before lock update: built `orgm-dot` comes from old dotfiles rev and does not seed `.config/rofi/orgm-current.rasi`.

- [ ] **Step 2: Update only `dotfiles-orgm-source`**

Run:

```bash
cd /home/osmarg/Hobby/nixos
distrobox-host-exec nix flake update dotfiles-orgm-source
```

- [ ] **Step 3: Verify new package seeds local defaults**

Run a temp-home `orgm-dot sync` with the Nix-built package and verify `.config/rofi/orgm-current.rasi` is created.

### Task 3: Cross-host verification matrix

**Files:**
- No source changes unless verification exposes another blocker.

- [ ] **Step 1: Verify host targets**

Run dry-runs for:

```bash
orgm-hyprland
lenovo-hyprland
ero-labwc
ero-server
hyprland
labwc
gnome
sway
i3
```

Expected: no missing-path errors.

- [ ] **Step 2: Verify dotfiles host sync simulation**

Run temp-home `orgm-dot diff --host lenovo`, `--host orgm`, `--host ero` with `ORGM_DOT_DESKTOP=hyprland` where applicable.

Expected: local defaults appear only when missing, host-specific paths stay scoped to their host.
