# Envy — juegos, pantallas y refuerzo de la instalación

> **For agentic workers:** Use executing-plans for host/deployment work; independent offline test/source investigations may use dispatching-parallel-agents. No parallel SSH operators or destructive disk work.

**Goal:** Add requested game integrations to normal, validate a real hotplugged monitor and strengthen the reusable installation without touching Optane or provisioning personal secrets.
**Architecture:** Reuse existing Lenovo gaming modules without importing Lenovo hardware/specialisations. Keep Ryoku monitor auto-layout and isolate phantom DP-1 policy. Improve offline guards/source reproducibility before defining recovery automation.
**Tech Stack:** NixOS/HomeManager, Ryoku/Hyprland Lua, Btrfs, SSH, Bash/Python regression tests.
**Spec:** User follow-up in current conversation: SOPS optional until user supplies identity; add gaming components; monitor connected through USB-C/HDMI; remaining safe improvements delegated to operator. User delegated decisions, no further blanket design gate.

## Constraints
- Normal desktop stays default, Intel desktop/NVIDIA580 offload. No server/Windows/VFIO/gaming-specialisation, no reboot without a new need/notice.
- Keep existing4userdiffs/untracked document intact. Use existing isolated feature worktree; no merge/push.
- No Optane/USB writes or rerun actual disk formatting. Disk guard work runs only against boundary doubles.
- Do not provision/copy SOPS identity or prioritise its absent-file failure: user accepts it until supplying file. Never embed credentials in source/Store/logs.
- External display tests require physical user cable moves; identify EDID/connector rather than assuming a USB-C connector name. Do not disable real outputs based only on connector names.
- Avoid claiming backup exists: local snapshots and recovery generations do not replace external backup; unknown backup destination stays an explicit pending input.

## Review focus
- Steam installed but missing offload wrapper; Steam must actually select NVIDIA for games, no global desktop offload.
- Non-enrolled SOPS can return partial switch; report honestly without treating it as user-blocking or hiding unrelated failures.
- Missing/failed inventory commands must prevent disk writes in tests.
- Ignored metadata filtering must preserve real selected config and executable scripts/symlinks.
- Auto-layout must not re-enable phantom output or discard real LG display/workspaces on hotplug.

### Task1: Offline safety and baseline verification
Files: tests/envy-disk.bats.sh; tests/flake-architecture.bats.sh; optional narrowly scoped test helpers.
- [ ] Add behavioral negative cases for mapping/type/size/UID and inventory failures; no writes on any rejection. Run actual guard with command doubles, never real formatter.
- [ ] Replace obsolete hostname textual assertion with evaluated builder contract; demonstrate regression detects hostname propagation break.
- [ ] Run suites, inspect diff, commit owned files only.

### Task2: Reproducible dotfile source
Files: nixos/common-dotfiles.nix, small pure filter helper if needed, focused tests.
- [ ] Establish real ignored source/metadata failure with two fixture trees/clean export; compare effective sources, preserve selected runtime behavior.
- [ ] Minimal stable source filter excluding metadata and obsolete unselected top-level roots; never delete user files or require Git at Nix evaluation time.
- [ ] Verify consistent source hashes under metadata changes, preserved regular source/executable/symlink behavior, representative host/profile tests. Commit owned changes.

### Task3: Normal gaming and physical monitors
Files: nixos/hosts/envy/default.nix, tests/envy-normal.bats.sh, hostREADME, validation report.
- [ ] Confirm meaning of gaming request and reuse selected steam/emulators/sunshine modules (Lenovo-like if confirmed), not host hardware or auto-login GamescopeTTY1.
- [ ] Check NVIDIA game launcher dependency, add only necessary shared helper or host-scoped implementation, test offloadenv and isolation with RED/GREEN.
- [ ] Record current LG EDID/connector/mode; capture hotplug events while user moves/disconnects/reconnects cable. Test both ports only when physically exercised.
- [ ] Build/review/copy/activate; preserve password/menu/network and report SOPS partial activation accepted by user. No unnecessary reboot.

### Task4: Recovery and installation runbook
Files: hostREADME; followup/validation/gaps docs; optional host-scoped snapshot policy after checking pinned module interface.
- [ ] Fix known invalid findmnt example, document resumable private provisioning/recovery gates without secrets.
- [ ] Evaluate bounded local Btrfs snapshot retention for root/home, exclude subvolumesNix/log/Windows and never call it independent backup. Implement only if safe pinned-module behavior verified; otherwise record exact remaining decision.
- [ ] Keep external backup pending until destination known; no changes to encryption/SecureBoot or disks under a generic hardening request.
- [ ] Final focused tests, honest broadcheck status, independent review, source+Git/docs sync, report completed vs remaining physical work.
