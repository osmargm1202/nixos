# Envy normal — Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. No parallel implementation: a single operator owns the destructive install and SSH access. Steps use checkbox syntax for tracking.

**Goal:** Install a reproducible normal-only NixOS desktop on envy and retain the complete repository and advanced-profile roadmap there.

**Architecture:** Add envy-hyprland (aliases envy/envy-normal), its own hardware/base module, and a guarded disk preparation script. Reuse osmarg's current configuration and Hyprland without changing unrelated pending work. Build locally before disk erasure, copy the system closure to the mounted target, provision private networking/access, and install using nixos-install.

**Tech Stack:** NixOS/Home Manager, Bash, Python tests, SSH, Btrfs, systemd-boot, Intel i915, proprietary NVIDIA580 PRIME.

**Spec:** docs/superpowers/specs/2026-10-15-envy-design.md, immediate approved scope at the top.

## Global Constraints
- ONLY normal now: no Windows VM, server, gaming specialisations or VFIO binding.
- Target root@10.0.0.50; erase ONLY Intel SSD serial PHTE9395032P512B-1, by-id nvme-INTEL_HBRPEKNX0202AH_PHTE9395032P512B-1. Preserve Optane serial -2 and USB installer.
- GPT EFI1GiB FAT32 + remaining Btrfs; root/home/nix/log and reserved empty Windows subvolume, no guest image/NTFS partition. Zram, no physical swap/hibernation.
- Intel UHD PCI0:2:0 owns desktop; MX250 PCI2:0:0 proprietary driver and offload; no Lenovo broken-panel/PCI/IOMMU settings.
- Preserve existing local changes and include their current osmarg preferences in the deployment snapshot without committing them as ours.
- All planning and repo go to /home/osmarg/Hobby/nixos; Wi-Fi/credentials/private keys outside repo/Store/logs.
- No push/merge without explicit user instruction. Worktree use pending user's async preference.

## Review Focus
- Wrong disk/serial, mounted partition, or missing erase confirmation must prevent every destructive command.
- Boot Wi-Fi and SSH must survive reboot without exposing passwords or depending on installer root access.
- NVIDIA Pascal must never use open=true, incompatible finegrained PM, or steal desktop rendering from Intel.
- Missing user secrets must not prevent local/SSH hardware validation; document integrations awaiting provisioning.
- A successful build does not prove hardware: distinguish drivers/enumeration, runtime software tests, and physical tests.

### Task 1: Host configuration, regression tests and documentation

**Files:** Modify configurations.nix and nixos/dns/hosts.nix; create nixos/hosts/envy/{hardware-configuration.nix,default.nix,README.md}; create tests/envy-normal.bats.sh. Keep future design updated.

**Interfaces:** Produces nixosConfigurations.envy-hyprland and aliases envy/envy-normal; mounts use ENVY_ROOT/ENVY_EFI labels matching Task2. SSH authorized public key and persisted initial password hash path supported; no private auth material stored in Nix.

- [x] Write failing evaluated-Nix test for envy/envy-normal aliases, host/user, normal marker, no specialisations/Windows autostart, Btrfs mounts, zram, PRIME buses/open=false, networking/SSH and assertions. Run RED (missing output).
- [x] Implement smallest host module and wiring. Reuse desktop common and osmarg; pin compatible kernel/NVIDIA580 from existing package set, Intel media drivers/SOF firmware, TRIM and diagnostics. No global GPU module on envy.
- [x] Run test GREEN plus configuration-inventory/host-role-wiring/flake architecture existing tests. Evaluate toplevel drv and inspect assertions.
- [x] Document first-boot hardware checklist, current scope, Optane findings, optional user integrations and commands. Commit only task-owned files.

### Task 2: Guarded disk preparation

**Files:** Create nixos/hosts/envy/prepare-disk.sh and tests/envy-disk.bats.sh.

**Interfaces:** prepare-disk.sh defaults to --check; --format requires --confirm PHTE9395032P512B-1, exact by-id device and serial/whole-disk/mount checks. Produces ENVY_EFI/ENVY_ROOT labels, @root/@home/@nix/@log/@windows mounted under /mnt. Never accepts an arbitrary target disk.

- [x] Write behavioral tests with boundary-command doubles for default non-destructive mode, wrong/missing confirmation, wrong serial, mounted target partition and successful authorized operation. Ensure failures perform no wipefs/parted/mkfs/mount; run RED.
- [x] Implement guarded script: verify prerequisites/root/device identity and no mounted descendants before writes; format ONLY confirmed target; Btrfs compressed mounts and empty NOCOW Windows subvolume. Repeated --format on mounted /mnt must refuse.
- [x] Run shell syntax and tests GREEN; run --check on actual envy. Capture untouched Optane/USB identity/signature fingerprints and SSD partition table backup outside repo.
- [x] Commit tested script/tests. Run local full system build BEFORE invoking actual --format.

### Task 3: Build, review, install and validate normal

**Files:** nixos/hosts/envy/README.md and docs/superpowers/plans/2026-10-15-envy-validation.md (installation evidence / pending checklist, no secrets).

**Interfaces:** Consumes Task1 system closure and Task2 mounted /mnt. Produces installed NixOS boot entry, osmarg SSH access, complete repo at /mnt/home/osmarg/Hobby/nixos, private Wi-Fi profile/initial password hash, and evidence report.

- [x] Build path snapshot including pending osmarg configuration; do not update lockfile. Use local machine's existing store/cache; record exact result path and build failures honestly.
- [x] Obtain fresh whole-change review before irreversible deployment; fix significant findings with regression tests. Re-run suites and git diff --check. No broad unrelated refactoring.
- [x] On remote revalidate target/authorization; back up metadata and private active NetworkManager profile; provision zram live if needed without touching Optane. Run guarded --format; record fingerprints of untouched devices unchanged.
- [x] Transfer closure directly to mounted target store (avoid filling live tmpfs), complete repo including .git and pending preferences but excluding transient worktrees/caches/secrets, and planning docs. Keep target ownership osmarg1000/users selected primary group.
- [x] Provision current authorized public key, private initial password hash (random initial password retained only in root-owned target file for user recovery), private Wi-Fi profile with permanent MAC for stable DHCP, SSH host identity continuity. Do not display secrets. Run nixos-install --system <closure> --no-root-passwd and verify mounts/boot entries/users/network files before reboot.
- [x] Reboot only after installation verification. Retry SSH osmarg@10.0.0.50 (also hostname if DHCP differs). Check running boot source, mounts, services, Wi-Fi/routes/DNS, GPU binding, Intel/NVIDIA Vulkan or GL offload, PipeWire/audio devices, USB/Bluetooth/camera and display enumeration. Do not fake speaker/microphone/physical port tests; mark user checks.
- [x] Save evidence and future road map in target ~/Hobby/nixos. Commit only task-owned code/docs; report what is installed, how to log in, password retrieval without exposing it, and remaining physical/optional-secret checks.

## Execution notes

- User explicitly requested direct installation after approval; execute inline after workspace preference is resolved, rather than another design approval round.
- No full Windows/VFIO work this phase, and no Optane modification even if swap would be useful.
- If actual build is blocked by preexisting repo issues, diagnose and choose a minimal host-scoped solution; do not silently drop osmarg preferences or replace the desired desktop.

## Phase-one outcome

Normal installation and SSH/Wi-Fi reboot verified; see 2026-10-15-envy-validation.md for actual results. Physical hardware tests, user logins/secrets and advanced profiles remain explicitly pending. Known preexisting flake-architecture textual failure blocks any global-green/merge claim; branch/worktree kept without push or merge.
