# Envy Internal Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare one Envy configuration with normal, gaming, Windows VFIO and server modes, without deployment.

**Architecture:** Keep `envy` as the only public flake output, factor Envy GPU ownership behind its own options, and add three internal specialisations. Publish an immutable host-specific Windows manifest/Compose and a guarded rootless Podman supervisor reused by the Envy RDP adapter. Do not refactor Lenovo's VM lifecycle or the user's mutable preferences.

**Tech Stack:** NixOS/Home Manager, Python3 standard library, systemd user services, Podman/podman-compose, NVIDIA580, Gamescope, Compose and FreeRDP.

**Spec:** `docs/superpowers/specs/2026-10-17-envy-modes-design.md`, complementing the approved historical `2026-10-15-envy-design.md`.

## Global Constraints

- No activation, VM install/image pull/run/build, reboot, live driver changes or DPMS/sleep tests.
- One public `envy` output, user `osmarg`; specialisations `gaming`, `windows-vfio`, `server`; normal remains default, menu1second.
- Intel0000:00:02.0/8086:9b41 stays host-owned; MX2500000:02:00.0/10de:1d13 belongs either to NVIDIA or VFIO, never both.
- Kernel candidate6.18 LTS and proprietary legacy_580; retain flake.lock and do not enable unsupported Pascal finegrained RTD3.
- No ACS override, unsafe interrupts, hot-unbind/reset, Lenovo group16/T500 IDs, broken-panel or lid policy.
- Optane/partitions/credentials/user files untouched; use existing ENVY_ROOT/@windows, NoCoW before creating any image.
- One envy-windows container/shared96GiB dynamic Windows11 disk,4GiBRAM,4vCPU, virtualVRAM1GiB; public manifests never contain passwords.
- Rootless Podman only; ports127.0.0.1:8006 and3389tcp/udp; no VM firewall opening, privileged container or Docker fallback.
- Normal render manual; gaming blocks Windows; Windows/server autostart conditioned on preflight, private password and local image readiness.
- Existing Ryoku native ownership and normal/console preference restoration, server remote access and mandatory tray policies remain intact.
- No changes to Lenovo/orgm boot defaults, runtimes or SOPS provision; no new required encrypted secret.

## Review Focus

- Existing active container with older public config after rebuild: preserve its disk and process, report pending config; reconcile only after graceful stop.
- Lost supervisor/Podman error/racing start: do not interpret errors as absence or allow a second owner of the disk; recover lock/monitor ownership conservatively.
- Different DRM numbering, missing/nonisolated IOMMU group or bus-reset neighbors: prove MX250 identity or refuse before provisioning, never choose Intel/software silently.
- Missing password/image/CDI/kernel capability on a future server boot: fail VM startup with actionable nonsecret diagnostics while preserving SSH and host login.
- Envy RDP commands including toggle/web/status: all start/stop paths delegate to its controller, never bypass guards or fall back to osmar/Lenovo credentials or Docker.

---

### Task 1: Host-specific GPU ownership and mode matrix

**Files:** create `nixos/hosts/envy/{options,gpu,modes}.nix`, `tests/envy-modes.bats.sh`; modify `nixos/hosts/envy/default.nix`, `tests/envy-{normal,gaming}.bats.sh`.

**Interfaces:** options `orgm.envy.mode` enum normal/gaming/windows/server (default normal), `orgm.envy.windowsVfio.enable` default derived from windows/server. `gpu.nix` consumes these options, emits one GPU ownership policy; `modes.nix` declares the3specialisations and their desktop/server/TTY1 behavior. No VM services until Task3.

- [ ] Add Nix assertions evaluated from the real Envy output: exact3specialisations, no extra public flake outputs,1second/default-normal boot ordering; Ryoku normal/windows only, Gamescope tty1 gaming only, headless multi-user server with SSH/network/Tailscale preserved.
- [ ] Assert correct PCI IDs/driver580/kernel6.18 across modes, no NVIDIA loading/offload/CDI in VFIO, i915 retained, no unsafe options/Lenovo display overrides and all NixOS assertions pass.
- [ ] Run `bash tests/envy-modes.bats.sh`: expect RED on missing modes, not an unrelated evaluator failure. Capture baseline `envy-normal`/`envy-gaming` PASS before updating their intentional normal-only assertions.
- [ ] Extract existing GPU policy without changing normal power/SDDM security, add candidate kernel and explicit sort keys. Reuse Gamescope module; server derives Lenovo console policy, not generic server.nix. Disable both Hyprland/Niri and GUI services for console modes, preserve login on graphical modes.
- [ ] Run mode+updatednormal/gaming contracts and `bash tests/configuration-inventory.bats.sh`: expect PASS. Commit `feat(envy): declare isolated gaming windows and server modes`.

### Task 2: Declarative VM data and guarded lifecycle controller

**Files:** create `nixos/containers/windows/hosts/envy/{compose.yml,compose.render.yml,compose.vfio.yml,image.json}`, `nixos/hosts/envy/{windows-runtime.py,windows-storage.sh}`, `tests/envy-windows-runtime.py`, `tests/envy-windows-compose.bats.sh`.

**Interfaces:** Python `main(argv)` dispatches `preflight|supervise|stop|status` from an explicit public JSON manifest. Internal pure boundaries `resolve_gpu(manifest, sysfs_root) -> dict`, `validate_storage(manifest, mounts)`, `config_digest(manifest, hardware) -> str`; manifest contains mode/BDF/expectedIDs/storage/allocations/public generation/image/absolute command paths/private password-file path, never password contents. Storage helper prepares only verified Btrfs mount/empty NoCoW storage; packaging/wrappers are Task3.

- [ ] Resolve and record the selected compatible Windows image's amd64 OCI digest through registry metadata only; audit that image version's QEMU display contract against the design. If metadata cannot be verified, stop this step rather than invent or pull an image.
- [ ] Write failing real-script tests with fake sysfs/mounts/Podman processes: missing/wrong driver, missing group, shared group, unsafe reset neighbors, changed render indices, unavailable KVM/CDI/kernel, absent private password/image, Podman failures distinct from not-found. Expect refusal before any create/start/data mutation, secret-free errors.
- [ ] Write failure cases for concurrent supervisors, daemon crash/adoption, active stale config, stopped stale config, malicious public paths/symlinked state/storage, existing non-NoCoW guest data, signal/stop timeout. Preserve live guest on rebuild; hold lock for actual lifetime; never force kill/delete volumes. Tests use only generated fixture credentials and temporary paths.
- [ ] Implement public host-specific Compose with fixed loopback binds, shared storage, identity-resolved runtime hardware overlay and matching NVIDIA CDI libraries only for render. Do not inherit generic wildcard binds or let private dotenv override data paths/devices. Validate password-file mode/owner/nonempty without logging it; pass runtime password via controlled subprocess env, not shell interpolation or public hashes.
- [ ] Implement supervisor reconciliation and lifetime locking: inspect before mutations; reuse matching live VM and adopt monitoring; refuse incompatible live VM; reconcile changed stopped VM without deleting storage/volumes; detect other active mounts of owned disk within the managed engine. No implicit image download; graceful stop waits for real exit instead of Podman's timeout force-kill.
- [ ] Implement mount/NoCoW helper idempotently; nonempty incompatible storage fails without conversion. Kernel/render/guest limitations remain separate diagnostics, not claimed hardware success.
- [ ] Run `python3 tests/envy-windows-runtime.py` and `bash tests/envy-windows-compose.bats.sh` with real Compose config validation using dummy password: expect PASS. Commit `feat(envy): add persistent guarded Windows runtime`.

### Task 3: Nix service wiring and Envy-only client integration

**Files:** create `nixos/hosts/envy/windows.nix`, `tests/envy-windows-wiring.bats.sh`; modify Envy imports/mode wiring, `dotfiles/config/users/osmarg/programs/containers/.local/bin/windows-rdp`, `tests/windows-rdp-client.bats.sh`.

**Interfaces:** `windows.nix` packages `system.build.envyWindowsController`, `system.build.envyWindowsManifest`, `system.build.envyWindowsCompose`; public CLI `envy-windows {start|stop|status|preflight}` delegates service lifecycle, private service entry invokes supervisor. Marker `/etc/orgm/windows-vm-profile` is envy-render-node, envy-vfio or envy-disabled; `orgm.envy.mode` distinguishes windows/server for autostart. Client uses same controller, local name envy-windows and explicit Envy credential paths.

- [ ] Add evaluated RED tests: immutable Compose/manifest sources in HM, exact controller executable/dependencies in service, local-only ports, linger, no default-target Windows in normal/gaming, default-target Windows in windows/server. No credentials/public env writes during activation, no private reads during eval/build.
- [ ] Add client RED cases for Envy render/VFIO/disabled, graphical/window/web/toggle/status and Podman failure. A fake controller must receive exact actions; assert no direct docker/podman start and no wrong-host credential fallback. Existing Lenovo/orgm tests remain unchanged except additional cases.
- [ ] Wire packaged runner manifest, runtimeInputs, storage prerequisite and systemd user supervisor. Ensure display/normal login succeeds if password/image/preflight is absent, but automatic VM status is clearly failed/blocked. Rebuild must not restart active VM when only declarative inputs change. No autologin beyond gaming, no silent SOPS dependency.
- [ ] Expose immutable Compose by host and controller/client configuration; RDP adapter delegates every Envy lifecycle path, respects VFIO no-offload on client, retains existing full-width/fullscreen app ID. Normal start is manual and gaming explicitly blocked, not a generic fallback.
- [ ] Run runtime/Compose/wiring suites plus `tests/windows-{rdp,rdp-client,compose-layout}.bats.sh` and `tests/lenovo-windows-{vfio,autostart}.bats.sh`: expect PASS, proving unchanged other-host contracts. Commit `feat(envy): wire Windows services and desktop launcher`.

### Task 4: Full construction, reviewed handoff and documentation

**Files:** update `nixos/hosts/envy/{README,PENDING}.md`, `nixos/hosts/envy/hardware-configuration.nix` comment only, plan/design status; create `docs/superpowers/reports/2026-10-17-envy-modes.md`.

**Interfaces:** delivered artifacts remain source-only; report separates config/tests/builds from unperformed live GPU/Windows/sleep validation and preserves manual deploy gate.

- [ ] Run all Envy mode/runtime/client suites, canonical5host eval, Ryoku profile/startup/native-session/seed integration, GPU/Steam/SOPS and Lenovo mode regressions. Attribute historical unrelated failures to a reproduced baseline, not new behavior.
- [ ] Build `.#nixosConfigurations.envy.config.system.build.toplevel` and each `.#nixosConfigurations.envy.config.specialisation.{gaming,windows-vfio,server}.configuration.system.build.toplevel` with `--no-link`. Verify all4complete, NVIDIA580/6.18 driver compatibility, no input-lock changes or evaluation assertions. No switch/test/boot/VM/container pull.
- [ ] Document local password/image provisioning (user action later), exact manual first normal boot/rollback, display+sleep checks and IOMMU/VFIO eligibility tests; no automatic default switch. Record renderer/guest drivers as not physically validated and preserve HDMI/LG clipping/clipboard pending threads.
- [ ] One fresh-context whole-branch code review per requesting-code-review, regrade by user impact, fix Critical/Important in one RED→GREEN pass and rerun complete focused suite. Commit tested source/docs.
- [ ] Push branch and merge/push master only under standing authorization, with clean checkout and preservation of stashes; validate merged tree again. If the worktree is externally managed, retain it per host tooling. Do not deploy Envy.

## Self-review

All spec requirements map to Tasks1–4. GPU ownership/mode options precede VM manifest packaging; controller interfaces precede client delegation. All5ReviewFocus cases have explicit tests. Registry inspection, source compilation and fixture execution do not authorize a real guest or hardware transition. The kernel candidate is a substantive new choice highlighted for plan approval; implementation remains gated.
