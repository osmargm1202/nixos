# Host Desktop Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax.

**Goal:** Apply agreed one-host outputs and native Ryoku startup/panel integration while preserving hardware modes, user state and existing files.
**Architecture:** Select each host's preferred existing configuration without merging alternative desktops. Preserve historical inventory internally for regression fixtures, not public flake outputs. Use supported mutable Ryoku stores backed by host/user declarative defaults and migrations; secrets remain private.
**Tech Stack:** NixOS/Home Manager, Ryoku locked28c5207, Bash/Python/Lua tests.
**Spec:** 2026-10-15-host-desktop-ryoku-audit.md, especially confirmed user decisions; user said apply changes (skip further design questions).

## Global Constraints
- Work only .worktrees/envy-normal, preserve four pre-existing user diffs and Windows draft; no merge/push.
- Canonical outputs exactly envy,lenovo,orgm,ero,jarq; chosen desktops Ryoku,Ryoku,Ryoku,i3,i3; Jarq userjarq unchanged.
- Keep internal modes and defaults; preserve unused profile files, no merging alternatives.
- Syncthing/Tailscale startup preserved. Other apps derive from user settings, not host forced defaults. Preserve existing user choices through migration.
- Claude NO API key; no login/token copying/authentication/API billing changes. Bitwarden CLI endpoint https://vw.or-gm.com; don't logout or alter existing sessions.
- No experimental biometric driver/PAM activation; reader00c9 unsupported normalroute, security-sensitive work separate. No Optane/disk changes. Screens deferred.
- No graphics-session restart or reboot. Only envy deployment eligible after build/review and verify display-manager unit unchanged; other hosts build-only to avoid disrupting active session.

## Review Focus
- Removing aliases must not silently lose default boot modes/GPU/Compose configuration.
- Existing dirty user files must not be overwritten or committed wholesale.
- Native startup seed migration must preserve unrelated Hub data and avoid duplicates/XDG/service ownership.
- H/K currentlyreserved; restore panel/help access without losing personal workflows and document actual chords.
- Missing optional secrets must not trigger login/logout or be embedded into store; Bitwarden server selection cannot overwrite existing authenticated state.

## Task1: Canonical host inventory
- [x] RED test exact five public output names, host/user/selecteddesktop/modes/default parity.
- [x] Preserve old inventory in configurations-legacy.nix; select only approved host descriptors, aliasesempty; nested host metadata if practical without needless builder redesign.
- [x] Adapt tests to internal historical fixtures where they intentionally test old desktops, not reintroducing public variants.
- [x] GREEN canonicalinventory, hostrole, normal, selectedRyoku/i3 and Lenovo mode tests. Docs active examples canonical names.

## Task2: Native Ryoku startup and accessible panels
- [x] RED startup ownership/migration/idempotence/conflicts tests.
- [x] Declare user startup selection, preserve mandatory Syncthing/Tailscale; move optional personal commands from Hypr-onlycallback to user-owned data and effective native desktop.autostart for both sessions.
- [x] Backup/versioned migration, no whole-store overwrite, avoid Nextcloud/Sunshine duplicates, preserve daemon vsindicator semantics.
- [x] Native supported panel/help shortcut integration, choose Super+H Stash and Super+K help if collision-free after adjusting only reserved placeholder ownership; preserve existing meaningful user actions. Retain backend-specific actions explicitly where no Niri support.
- [x] GREEN prepare/transition/shortcuts/native render tests; document operator-selected H/K mapping and remaining legend limitations honestly.

## Task3: Bitwarden CLI and startup correctness
- [x] RED package selection/server bootstrap tests for Osmarg and isolation from Jarq.
- [x] Add Bitwarden CLI user-selected integration and bw-orgm convenience wrapper if needed: configure server only if unauthenticated and unset, refuse mismatched authenticated endpoint, never logout; normal bw remains available. No credentials/automaticlogin.
- [x] Preserve existing NumLock fix in envy; generated SDDM config on and normal suite GREEN.
- [x] Reproduce actual hypridle missinghyprctlPATH using exact unit/runtime; fix narrowly only if root cause proven and testable, otherwise record separate rather than speculative changes.

## Task4: Verification, independent review and deployment
- [x] Full focused suites and evaluated allhost assertions; report preexisting Jarq/global failures honestly.
- [x] Build selected systems where resources permit; build envy closure, compare display-manager unit to prevent session restart.
- [x] Fresh whole-change review; fix Critical/Important with RED/GREEN, preserve userdiffs.
- [x] Sync source/docs preserving remote diffs; activate envy only without reboot/session restart if safe; SOPS known partialactivation limitation explicit. Otherwise boot-only/staged with clear reason, don't call staged active.
- [x] Verify outputs/apps/services/NumLock/default/modes and write handoff. Explain bw usage without retrieving vault secrets.
