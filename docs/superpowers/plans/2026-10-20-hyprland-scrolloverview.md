# Restore Hyprland ScrollOverview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Execute inline with TDD and a final fresh review.

**Goal:** Restore yayuuu's Niri-like ScrollOverview on Hyprland Alt+Tab; leave Sway's current switcher untouched.

**Architecture:** Pin upstream `cfc23b194ba9378d1606c7aa73060f6ffbe38445` for the existing Hyprland 0.55.4 (runtime `a0136d8c04687bb36eb8a28eb9d1ff92aea99704`). Build against the same package using mkHyprlandPlugin; expose `/etc/scrolloverview.so`. A shared Lua module registers the readable plugin declaratively with `hl.plugin.load` on every config evaluation, preventing the former startup race. Alt+Tab uses native plugin overview when available and the existing Quickshell command otherwise.

**Tech Stack:** NixOS, Hyprland native Lua, ScrollOverview C++, Python/Lua regression tests.

**Spec:** User-approved chat: restore ScrollOverview only in Hyprland, preserve scrolling layout and Sway's current UI. User delegates application/testing to the assistant; no further design/implementation-method questions needed.

## Global Constraints

- No Hyprland/nixpkgs upgrade, no system switch/reboot, no Sway changes.
- Do not bypass or kill the existing lock; native graphical verification can be limited by a locked parent.
- Existing Alt+Tab/Shift+Tab fallback commands remain `orgm-hyprland windows` / `orgm-hyprland windows prev`.
- Preserve Win+R cycling, browser startup100 rules, installed dock/Waybar compatibility fixes and personal settings.
- Work in managed isolated checkout `/home/osmarg/.codex/worktrees/9279/nixos`; leave other worktrees alone.
- Apply dotfiles ourselves; root the standalone plugin in `~/.local/state/orgm-hyprland-tools/scrolloverview` until normal NixOS activation.
- Do not commit/push this new task without a fresh user request; plan commit steps are deferred accordingly.

## Review Focus

- Missing plugin or load failure: Alt+Tab must still open the existing selector.
- Config reload/repeated startup: register one plugin path, never accumulate processes/retry loops.
- Personal/base overrides: both choose the plugin; Sway bindings/source stay byte-identical.
- Runtime vs package ABI: compile with exact selected Hyprland; plugin's own hash guard must remain enabled.
- Runtime GC path vs future `/etc`: canonical NixOS path takes precedence; invalid/nonexistent paths must not break config load.

### Task 1: Package and declarative registration

**Files:** `nixos/profiles/hyprland/hyprland-scroll-overview.nix`, `hyprland.nix`, new `tests/hypr-scroll-overview-package.test.py`.
**Interface:** `pkgs.callPackage ... { hyprland = hyprlandPackage; inherit (pkgs.hyprlandPlugins) mkHyprlandPlugin; }` produces `/lib/libscrolloverview.so`, used by `environment.etc."scrolloverview.so".source` only when Hyprland is enabled.

- [x] Write/run failing evaluated-Nix test: OrgM exposes plugin built for its compositor, Envy/Sway has no plugin entry; no compositor override.
- [x] Update pinned revision/hash, use mkHyprlandPlugin + Lua5.4, install actual upstream `scrolloverview.so` as `libscrolloverview.so`.
- [x] Run Nix regression, build standalone package, retain hash mismatch/API guard, inspect exported plugin symbols.

### Task 2: Lua behavior and application

**Files:** new shared `dotfiles/config/profiles/hyprland/.config/hypr/lua/overview.lua`; base/personal `keybindings.lua`, `autostart.lua`; `tests/hypr-sway-bindings.lua`, `tests/hypr-scroll-overview.bats.sh`, new `tests/hypr-scroll-overview.test.py`; adjacent isolated Lua/native fixtures as required; profile/Lua READMEs and report.
**Interfaces:** `overview.register()` chooses existing `/etc/scrolloverview.so` then `$XDG_STATE_HOME/orgm-hyprland-tools/scrolloverview/lib/libscrolloverview.so`; `overview.toggle(fallback)` returns a key callback that calls plugin `overview("toggle")` or `hl.exec_cmd(fallback)`.

- [x] Write/run RED Lua behavior tests: both profile Alt+Tab variants use plugin when loaded, exact fallback when absent; register preferred readable plugin path idempotently; missing file does not call loader.
- [x] Add module/register on each autostart-module evaluation; update bindings, retaining all other key registrations.
- [x] Replace obsolete grep-only ScrollOverview test with actual Lua/Nix tests; update adjacent fixtures for the shared module import and retain plugin-absent switcher integration.
- [x] Run targeted tests and general script suite; name all failures/skips, do not claim full green on partial native coverage.
- [x] Verify plugin loading and actual Alt+Tab in a private native Hyprland before any live load; abort live load on ABI/init failure.
- [x] Root plugin, apply own files to canonical checkout only if base file versions unchanged (otherwise merge non-destructively), run orgm-dot pull, reload, verify live plugin list/config errors. No unsafe unlock.
- [x] Obtain independent final review; fix important findings with RED→GREEN; document application/remaining limitations.

## Execution ledger

- Initial: clean main at `fab9bb9`; isolated managed checkout created from that commit; approved inline execution.
- Ruling: use native `hl.plugin.load` registration on config evaluation, not an asynchronous exec-once loader. Source confirms it participates in the plugin manager's post-load reconciliation and automatic reload.
- Ruling: both Alt+Tab variants toggle the same overview when available; only the plugin-absent fallback retains forward/reverse Quickshell selection.
- Ruling: no commits/push are included in this approval; defer until explicitly requested.

## Completion

Targeted tests, standalone build, private native shortcut/reload tests and live
load/config checks passed; applied via orgm-dot with backup. General suite:
178 scripts, 166 exit0 (may include SKIP), 12 prior failures, same adjusted
baseline, no additional failing scripts. Independent review: no important
findings. See report for exact verification and visual/lock limitation.
No commit/push/system switch/reboot. User's visual trial remains pending.
