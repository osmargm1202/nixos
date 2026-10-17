# Ryoku First-Seed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Preserve editable Ryoku preferences after initial personal seeding and fix the erroneous resume DPMS toggle.

**Architecture:** Extend the existing pinned package compatibility boundary; deliver missing native Bash resources and use the native materializer's seed/live-owned contract for personal app configuration. A manifest-driven local initializer seeds absent files and migrates only proven old Home Manager links; native stores/overrides remain authoritative afterward.

**Tech Stack:** NixOS/Home Manager, Python 3, Bash, Lua and pinned Ryoku Go providers/CLI.

**Spec:** `docs/superpowers/specs/2026-10-16-ryoku-first-seed-design.md` (approved by user: “dale”).

## Global Constraints

- Hosts: envy, lenovo and orgm, user osmarg; i3/Jarq and internal boot modes remain isolated.
- No activation, restart, lock, DPMS changes or suspend on live hosts; user runs nh os switch.
- Existing regular files and arbitrary/dangling personal links win; no writes through Store links.
- Only proven old managed bootstrap/preference links may migrate, with private versioned backups.
- Seed absent files individually; never force deleted imports or Hub rows back into existing files.
- Keep mandatory Syncthing/Tailscale; packages, hardware, security and secrets remain declarative.
- Standalone user functions import without old prompt/banner/fzf/zoxide initialization.
- Preserve current Fastfetch and native Save/readback; native runtime updates are distinct from preferences.

## Review Focus

- Existing custom `.bashrc` regular or dangling symlink must remain untouched and produce an actionable warning if it omits the native import (Task 3).
- Old managed links may point at earlier Store generations: prove ownership by known source/content, back up bytes+link provenance, never silently replace arbitrary links (Task 3).
- A first seed must survive the *real* native materializer, not just prepare twice (Tasks 2–3).
- Missing resources/dependencies or noninteractive Bash must not produce duplicate banners, recursive loading or unexpected subprocesses (Task 2–3).
- Every executable resolution route (bundle, PATH, materializer, HM and service wrappers) must use the same corrected packages after DPMS/resource changes (Tasks 1–2).

---

### Task 1: Correct DPMS provider translation

**Files:** modify `nixos/profiles/ryoku/provider-compat.nix`, `tests/ryoku-provider-compat.bats.sh`; create `tests/ryoku-dpms.py`.

**Interfaces:** compatibility helper returns `.packages.ryoku-wm-hyprland`, `.packages.ryoku-wm-niri`, `.packages.ryoku-materialize`, `.packages.ryoku-bundle`; keep the existing module factory.

- [x] Write actual-binary test using an isolated listening Unix socket and fake `hyprctl`; on/on/off/off, optional monitor and invalid state; require explicit action not state and simulate idempotent outcomes.
- [x] Run against current provider: expect FAIL on state field (not missing executable/live session).
- [x] Patch only the pinned DPMS emitter; rewire both provider paths in materializer and bundle. Update wiring test to require corrected Hypr provider and unchanged compositor ABI, rather than unchanged broken provider.
- [x] Build selected packages and run DPMS + provider wiring tests: expect PASS.
- [x] Commit `fix(ryoku): make display power actions idempotent`.

### Task 2: Native Bash resources and native app seed semantics

**Files:** modify `provider-compat.nix`; create `tests/ryoku-native-resources.py`.

**Interfaces:** compatibility packages additionally expose corrected `ryoku-desktop-data` and `ryoku` CLI. Base under `share/ryoku/config` includes `bash/{ryoku.bash,rashin.bash}` and `ryoku-terminal/env.sh`. App seed/live-owned contract covers Fastfetch/nvim existing native paths and personal Starship/btop preferences; never freeze generated WM settings or Quickshell runtime.

- [x] Write tests of built base resources, actual CLI materialization preserving edited Starship/btop/Fastfetch and arbitrary links, and updated base runtime independently. Native Bash fixture checks one banner/import/prompt initialization and proper noninteractive behavior.
- [x] Run current packages: expect FAIL missing native Bash resources and overwritten personal app defaults.
- [x] Publish exact pinned native Bash/env sources through desktop-data; patch only missing preference seed/live-owned classifications in CLI. Rewire CLI/data references in module/materializer/bundle without changing upstream package set/ABI.
- [x] Build and run new resource tests plus Task 1 tests: expect PASS.
- [x] Commit `feat(ryoku): ship native Bash and preserve app preferences`.

### Task 3: Manifest-driven personal initialization and safe migration

**Files:** create `nixos/profiles/ryoku/seed.py`, bootstrap/import templates and `tests/ryoku-seed.py`; modify `nixos/common-dotfiles.nix`, `nixos/profiles/ryoku/{ryoku.nix,prepare.sh}`, shared/personal Ryoku source routing, `tests/ryoku-transition.bats.sh`.

**Interfaces:** `seed.py CONFIG_HOME STATE_HOME HOME MANIFEST` consumes JSON list of `{source,target,legacySources?,replaceLegacy?}` records with HOME-relative targets and optional XDG mapping; copies source to absent slots only, private backups/provenance for recognized legacy links. Runtime manifests/templates are Nix-owned outside mutable target roots. New `.bashrc` loads Nix env then native Ryoku once; `bash/user.bash` imports `orgm-shell` workflows/functions (no competing theme init). Seed catalog includes selected Fastfetch assets/nvim/Starship/btop, native user overrides and source modules; not historical desktop configs or credentials.

- [x] Write RED tests: missing→regular writable; edits survive changed defaults; new file seeds after previous run; arbitrary/dangling links preserved; proven legacy bootstrap replacement/private backup; helpers detach preserving current bytes; repeated run leaves removed imports removed; unsafe traversal/parent symlink cannot escape HOME.
- [x] Write scope/activation fixture: no HM links for editable preferences, immutable import libraries allowed, both native scripts are present before preparing shell, existing Fastfetch hash unchanged. End-to-end fresh prepare/materialize/native Bash and Hub Save/new terminal same config.
- [x] Run new tests plus update old transition expectations that intentionally forced arbitrary links/palette updates: expect FAIL for old unconditional writes/routing.
- [x] Implement seeder/manifest and hook it before native materialization, before old-HM conflict cleanup can delete evidence. Remove unconditional personal preference installs/reinsertion from prepare. Keep true derived/native migration outputs and security obligations separate.
- [x] Split standalone personal workflows from legacy shell initialization, preserving existing non-Ryoku path unchanged; make current personal modules writable seed targets, not immutable preference dependencies.
- [x] Run seed/migration/native-resource/DPMS/startup/transition/shortcut/utility/bash/OMP regressions: expect PASS; no live operations.
- [x] Commit `feat(ryoku): seed personal settings once and yield ownership`.

### Task 4: Validation, documentation and handoff

**Files:** update `nixos/profiles/ryoku/README.md`, `nixos/hosts/envy/PENDING.md`, approved design status and relevant tests.

**Interfaces:** document seed inventory, editable paths/import boundaries, explicit migration exception, known live validation limits and self-switch flow.

- [ ] Evaluate all five canonical hosts and internal mode isolation; build complete Envy, then cached Ryoku host builds if feasible. Run actual Niri/Hypr config validators, all focused regressions and diff check. Expect PASS for focused suites; list pre-existing broad-suite failures separately.
- [ ] Verify source-only behavior: no Envy private data changed or pushed; no deployment. Update pending DPMS state to corrected source/build but still awaiting physical user validation; HDMI/LG clipping stay open.
- [ ] Fresh whole-branch review per requesting-code-review; fix Critical/Important findings with RED→GREEN and rerun focused suite. Commit tested fixes and docs.
- [ ] Push feature branch; integrate to master via the standing user-authorized merge/commit/push workflow if clean, preserving user work and backup stashes; no switch. Provide commit, self-update/switch/reopen instructions and physical sleep validation request.

## Self-review

Spec mapped to Tasks 1–4; source/mutable/derived interfaces are consistent. Per-file absence, link provenance, real materialization, shell idempotence and executable route checks all have explicit tests. User already approved the design and requested continuation; proceed inline with one fresh review at end rather than adding another confirmation loop.
