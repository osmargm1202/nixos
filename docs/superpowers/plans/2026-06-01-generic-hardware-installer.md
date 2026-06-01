# Generic Hardware Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reusable GPU/kernel modules and update the generic installer to select them.

**Architecture:** Hardware and kernel choices live in focused Nix modules exported by the flake. Current host configs import modules instead of carrying reusable NVIDIA logic inside generated hardware files. `install.sh` writes selected modules into the generated consumer flake and auto-detects NVIDIA PRIME Bus IDs with user confirmation.

**Tech Stack:** Nix flakes, NixOS modules, Bash installer.

---

## File Structure

- Create `nixos/hardware/gpu/intel.nix` — Intel graphics defaults.
- Create `nixos/hardware/gpu/radeon.nix` — AMD/Radeon graphics defaults.
- Create `nixos/hardware/gpu/nvidia.nix` — discrete NVIDIA defaults.
- Create `nixos/hardware/gpu/nvidia-offload.nix` — hybrid NVIDIA PRIME offload defaults; Bus IDs supplied externally.
- Create `nixos/hardware/kernel/zen.nix` — Zen kernel module.
- Create `nixos/hardware/kernel/lts.nix` — LTS kernel module.
- Modify `flake.nix` — export modules via `nixosModules` and import modules in `orgm`/`lenovo` outputs.
- Modify `nixos/hosts/orgm/hardware-configuration.nix` — remove reusable NVIDIA/display settings.
- Modify `nixos/hosts/lenovo/hardware-configuration.nix` — remove reusable NVIDIA/offload/display/power settings.
- Modify `install.sh` — add GPU/kernel selection and offload Bus ID detection.

## Tasks

### Task 1: Add reusable Nix modules

- [ ] Create GPU module files with exact options currently duplicated in host hardware configs.
- [ ] Create kernel module files for Zen and LTS.
- [ ] Run `nixfmt` on new files.

### Task 2: Export modules and migrate host outputs

- [ ] Add `nixosModules.gpu.*` and `nixosModules.kernel.*` to `flake.nix`.
- [ ] Add GPU modules to host-specific `extraModules` for `orgm-*` and `lenovo-*` outputs.
- [ ] Add Lenovo Bus ID override module to `lenovo-*` outputs.
- [ ] Remove reusable NVIDIA logic from `nixos/hosts/orgm/hardware-configuration.nix` and `nixos/hosts/lenovo/hardware-configuration.nix`.

### Task 3: Update installer choices

- [ ] Add GPU choices: Intel, Radeon/AMD, NVIDIA desktop, NVIDIA hybrid offload.
- [ ] Add kernel choices: Zen, LTS. Mention CachyOS as pending.
- [ ] Generate `extraModules` with selected `orgmos.nixosModules.gpu.*` and `orgmos.nixosModules.kernel.*`.
- [ ] For offload, run `lspci`, detect Intel/NVIDIA PCI addresses, convert to NixOS `PCI:x:y:z`, and let user confirm or override.
- [ ] Validate manual Bus IDs with `^PCI:[0-9]+:[0-9]+:[0-9]+$`.

### Task 4: Verify

- [ ] Run `bash -n install.sh`.
- [ ] Run `nix flake check` if available and expected to finish.
- [ ] Inspect generated installer flake logic manually for Intel/Radeon/NVIDIA/offload and Zen/LTS.
