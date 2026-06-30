# Tasks: hypr-lua-orgm-hypr-migration

Implementation status: Slice 7 complete in apply phase with approved partial verification. Proposal/spec/design/tasks approval and auto-chain delivery path were provided by parent/user.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 1,200-2,200 additions + deletions across full migration |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 inventory/test harness → PR 2 Lua foundation → PR 3 compositor parity → PR 4 session/Waybar/Dock CLI → PR 5 Windows/Zen/OSD CLI → PR 6 menu/smart-run/webapp → PR 7 cleanup/docs/verify |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

## Non-negotiable apply instructions

- STRICT TDD MODE IS ACTIVE.
- Test runner: `nix flake check`.
- Follow RED → GREEN → TRIANGULATE → REFACTOR for each implementation slice where practical.
- Record evidence for each task before marking it complete: failing/characterization test evidence, passing test evidence, parity/manual evidence, and dotfile diff evidence.
- Before moving shell logic into Go, add focused Go characterization tests for current behavior, parsed inputs, generated output/actions, exit/error behavior, and dependency failures.
- Do not run cleanup/removal before replacements, caller migration, and parity checks pass.
- Preserve unrelated existing change: do not edit or include `config/shared/.config/nwg-dock-hyprland/style.css` in this SDD change.

## Slice 1: Inventory and test harness

- [x] 1.1 Refresh migration inventory without behavior changes.
  - Owner target: deferred/discovery.
  - Files/discovery targets: `config/shared/.config/hypr/**`, `config/shared/.config/hypr/scripts/**`, `config/shared/.local/bin/hypr-*`, `config/shared/.local/bin/fuzzel-*`, `config/shared/.local/bin/*-osd`, `config/shared/.local/bin/waybar-*`, `cmd/orgm-hypr/main.go`, `internal/**`, `nixos/packages/orgm-hypr.nix`, `config/dotfiles.json`.
  - Acceptance checks: every discovered in-scope entry has domain, current path, owner target, rationale, parity check, rollback note, and assigned slice; uncertain entries marked retained or deferred.
  - Validation commands: `nix flake check`; `go test ./...`; `orgm-dot diff --host orgm`; `./dot.sh diff --host orgm`.
  - Rollback note: inventory-only changes revert by deleting/restoring inventory artifact; no live behavior touched.

- [x] 1.2 Add Go CLI test harness before new command behavior.
  - Owner target: orgm-hypr.
  - Files/discovery targets: `cmd/orgm-hypr/main.go`, `cmd/orgm-hypr/*_test.go`, `internal/cli/**`, future `internal/<domain>/*_test.go`.
  - Acceptance checks: tests capture current implemented groups (`version`, `wallpaper`) and current placeholder errors for `waybar`, `dock`, `zen`, `menu`, `updates`, `webapp`, `windows`, `notify`, `smart-run` before any behavior replacement.
  - Validation commands: `go test ./cmd/orgm-hypr ./internal/cli ./...`; `nix flake check`.
  - Rollback note: revert test harness files; current CLI behavior remains unchanged.

## Slice 2: Lua foundation

- [x] 2.1 Characterize current Lua/hyprlang load structure before refactor.
  - Owner target: Lua.
  - Files/discovery targets: `config/shared/.config/hypr/hyprland.lua`, `config/shared/.config/hypr/lua/*.lua`, `config/shared/.config/hypr/hyprland.conf`, `config/shared/.config/hypr/*-*.conf`.
  - Acceptance checks: current module/source order documented; Lua runtime blockers captured; fallback hyprlang path remains intact.
  - Validation commands: `nix flake check`; `nix fmt`; `orgm-dot diff --host orgm`; manual Hyprland reload/load evidence or documented blocker.
  - Rollback note: disable/revert `hyprland.lua` changes and keep `hyprland.conf`/split conf fallback.

- [x] 2.2 Add or normalize Lua module tree additively.
  - Owner target: Lua.
  - Files/discovery targets: `config/shared/.config/hypr/hyprland.lua`, `config/shared/.config/hypr/lua/init.lua`, `config/shared/.config/hypr/lua/core/*.lua`, `config/shared/.config/hypr/lua/compositor/*.lua`, `config/shared/.config/hypr/lua/compat/*.lua`.
  - Acceptance checks: entrypoint only requires modules in deterministic order; modules are non-blocking; external command paths still point to existing wrappers; no script deletion.
  - Validation commands: `nix flake check`; `orgm-dot diff --host orgm`; manual Hyprland reload/load evidence or documented blocker.
  - Rollback note: revert new Lua files or switch entrypoint back to previous module names.

## Slice 3: Compositor parity

- [x] 3.1 Migrate/validate keybindings through Lua without removing shell entrypoints.
  - Owner target: Lua.
  - Files/discovery targets: `config/shared/.config/hypr/lua/keybindings.lua`, `config/shared/.config/hypr/lua/compositor/bindings.lua`, `config/shared/.config/hypr/70-keybindings.conf`, `config/shared/.local/bin/hypr-*`, `config/shared/.local/bin/fuzzel-*`.
  - Acceptance checks: binding list and user-visible actions match current behavior; interactive commands remain external wrappers; keybinding help data impact documented.
  - Validation commands: `nix flake check`; `orgm-dot diff --host orgm`; manual keybinding smoke checklist.
  - Rollback note: restore old `70-keybindings.conf` callers or disable Lua bindings module.

- [x] 3.2 Migrate/validate monitor, input, look/layout, windows, and workspace rules.
  - Owner target: Lua.
  - Files/discovery targets: `config/shared/.config/hypr/lua/monitors.lua`, `lua/input.lua`, `lua/look-and-feel.lua`, `lua/windows-workspaces.lua`, `config/shared/.config/hypr/00-monitors.conf`, `50-look-and-feel.conf`, `55-layout.conf`, `60-input.conf`, `80-windows-workspaces.conf`.
  - Acceptance checks: monitor scale/mode, input layout, gestures, gaps/borders/animations, window rules, opacity/float/scratchpad behavior match current behavior.
  - Validation commands: `nix flake check`; `orgm-dot diff --host orgm`; manual Hyprland reload and workspace/window parity checklist.
  - Rollback note: keep old conf files available; disable corresponding Lua modules if runtime parity fails.

## Slice 4: Session, Waybar, and Dock CLI

- [x] 4.1 Add `orgm-hypr session` characterization tests, then implementation.
  - Owner target: orgm-hypr.
  - Files/discovery targets: `cmd/orgm-hypr/main.go`, `internal/session/**`, `config/shared/.config/hypr/lua/autostart.lua`, `config/shared/.config/hypr/20-autostart.conf`.
  - Acceptance checks: env import, container start, Discord/autostart decisions are typed, idempotent where possible, and old autostart remains fallback until verified.
  - Validation commands: RED focused Go tests first; GREEN `go test ./internal/session ./cmd/orgm-hypr`; `nix flake check`; manual autostart parity evidence.
  - Rollback note: revert callers to old `exec-once` shell snippets or scripts.

- [x] 4.2 Add `orgm-hypr waybar` tests and commands with wrappers retained.
  - Owner target: orgm-hypr.
  - Files/discovery targets: `config/shared/.local/bin/waybar-watch`, `waybar-date-es`, `waybar-day-month-es`, `waybar-time-ampm`, `waybar-swap-usage`, `hypr-workspace-button`, `cmd/orgm-hypr/main.go`, `internal/waybar/**`.
  - Acceptance checks: watcher restart behavior, workspace JSON/status/click, and tiny date/swap helpers either match current output or remain explicitly retained.
  - Validation commands: RED focused Go tests first; `go test ./internal/waybar ./cmd/orgm-hypr`; `nix flake check`; manual Waybar module evidence.
  - Rollback note: wrappers continue calling old scripts; callers can switch back per wrapper.

- [x] 4.3 Add `orgm-hypr dock` tests and command with compatibility wrapper.
  - Owner target: orgm-hypr.
  - Files/discovery targets: `config/shared/.local/bin/hypr-nwg-dock`, `cmd/orgm-hypr/main.go`, `internal/dock/**`, `config/shared/.config/nwg-dock-hyprland/**`.
  - Acceptance checks: `dock start --reload` is idempotent, preserves current args and missing-binary behavior; unrelated `config/shared/.config/nwg-dock-hyprland/style.css` is untouched.
  - Validation commands: RED focused Go tests first; `go test ./internal/dock ./cmd/orgm-hypr`; `nix flake check`; manual dock start/reload evidence.
  - Rollback note: wrapper points back to old shell body or slice revert restores script.

## Slice 5: Windows, Zen, and OSD CLI

- [x] 5.1 Add `orgm-hypr windows` tests and commands before wrapper switch.
  - Owner target: orgm-hypr.
  - Files/discovery targets: `config/shared/.local/bin/fuzzel-hypr-window`, `hypr-kill-windows`, `config/shared/.config/hypr/scripts/walker-window-switch.sh`, `cmd/orgm-hypr/main.go`, `internal/windows/**`.
  - Acceptance checks: hyprctl JSON parsing, list labels, focus by address, kill menu filtering, cancellation, and error paths match current behavior; interactive prompt may remain wrapper.
  - Validation commands: RED focused Go tests first; `go test ./internal/windows ./cmd/orgm-hypr`; `nix flake check`; manual focus/kill menu evidence.
  - Rollback note: keep scripts/wrappers unchanged until parity passes; revert wrapper switch if needed.

- [x] 5.2 Add `orgm-hypr zen` tests and command.
  - Owner target: orgm-hypr.
  - Files/discovery targets: `config/shared/.local/bin/hypr-zen-new-window`, `cmd/orgm-hypr/main.go`, `internal/zen/**`.
  - Acceptance checks: Zen open/focus retry behavior, missing install behavior, and hyprctl parsing match current script.
  - Validation commands: RED focused Go tests first; `go test ./internal/zen ./cmd/orgm-hypr`; `nix flake check`; manual Zen parity evidence.
  - Rollback note: wrapper calls old script body or old path restored.

- [x] 5.3 Add `orgm-hypr osd` tests and commands with wrappers retained.
  - Owner target: orgm-hypr.
  - Files/discovery targets: `config/shared/.local/bin/volume-osd`, `mic-volume-osd`, `brightness-osd`, `cmd/orgm-hypr/main.go`, `internal/osd/**`.
  - Acceptance checks: volume, mic mute, brightness step, notify hints, dependency failures, and exit statuses match current scripts.
  - Validation commands: RED focused Go tests first; `go test ./internal/osd ./cmd/orgm-hypr`; `nix flake check`; manual OSD evidence.
  - Rollback note: wrappers remain available; callers return to old scripts if hardware/runtime behavior differs.

## Slice 6: Menu, smart-run, and webapp

- [x] 6.1 Characterize menu wrappers before optional Go migration.
  - Owner target: script/orgm-hypr/deferred per item.
  - Files/discovery targets: `config/shared/.local/bin/hypr-main-menu`, `hypr-system-menu`, `hypr-tools-menu`, `hypr-performance-menu`, `hypr-wifi-menu`, `hypr-bluetooth-menu`, `hypr-keyboard-menu`, `hypr-power-menu`, `hypr-keybindings-help`, `cmd/orgm-hypr/main.go`, `internal/menu/**`.
  - Acceptance checks: every menu item, cancel path, dependency call, and caller is documented; retained interactive wrappers have rationale; Go migration only begins after characterization tests.
  - Validation commands: RED focused Go tests before moved logic; `go test ./internal/menu ./cmd/orgm-hypr`; `nix flake check`; manual menu parity evidence.
  - Rollback note: all interactive wrappers stay until parity passes; defer complex menus rather than force migration.

- [x] 6.2 Add `orgm-hypr smart-run` parser tests, then implementation or wrapper delegation.
  - Owner target: orgm-hypr + retained script wrapper.
  - Files/discovery targets: `config/shared/.local/bin/hypr-smart-run`, `cmd/orgm-hypr/main.go`, `internal/smartrun/**`.
  - Acceptance checks: URL/search/app detection, argument handling, launcher behavior, and failure messages match current script or approved delta.
  - Validation commands: RED focused parser tests first; `go test ./internal/smartrun ./cmd/orgm-hypr`; `nix flake check`; manual launch evidence.
  - Rollback note: wrapper can call old script body; new command can remain unused.

- [x] 6.3 Characterize webapp maker/remover and defer unless tests make migration safe.
  - Owner target: deferred by default; orgm-hypr only if safe.
  - Files/discovery targets: `config/shared/.local/bin/hypr-webapp-maker`, `hypr-webapp-remover`, `config/shared/.local/share/applications/**`, `cmd/orgm-hypr/main.go`, `internal/webapp/**`.
  - Acceptance checks: desktop/icon/profile creation/removal, destructive deletion prompts, network/file writes, and rollback are understood; otherwise explicitly retained/deferred.
  - Validation commands: RED focused tests before moved logic; `go test ./internal/webapp ./cmd/orgm-hypr`; `nix flake check`; manual dry-run/parity evidence if implemented.
  - Rollback note: do not replace scripts unless generated files and deletion behavior are fully recoverable.

## Slice 7: Cleanup, docs, and verify

- [x] 7.1 Remove or shrink scripts only after replacement and parity evidence exists.
  - Owner target: script.
  - Files/discovery targets: validated wrappers under `config/shared/.local/bin/hypr-*`, `config/shared/.local/bin/fuzzel-*`, `config/shared/.local/bin/*-osd`, `config/shared/.local/bin/waybar-*`, `config/shared/.config/hypr/scripts/**`.
  - Acceptance checks: each cleanup entry lists previous path, replacement command/module, affected callers, evidence link/notes, and rollback action; retained wrappers documented explicitly.
  - Validation commands: `go test ./...`; `nix flake check`; `orgm-dot diff --host orgm`; `./dot.sh diff --host orgm`; manual affected-entrypoint smoke tests.
  - Rollback note: restore wrapper/script from prior slice or revert cleanup commit only.

- [x] 7.2 Update docs and verification evidence.
  - Owner target: deferred/docs.
  - Files/discovery targets: `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md`, `openspec/changes/hypr-lua-orgm-hypr-migration/verify-report.md`, optional README/docs touched by implementation.
  - Acceptance checks: final evidence includes `nix flake check`, focused Go tests, Lua load/reload status or blocker, `orgm-dot diff --host orgm`, `./dot.sh diff --host orgm`, and manual parity checklist by domain.
  - Validation commands: `nix fmt`; `go test ./...`; `nix flake check`; `nix build .#packages.x86_64-linux.orgm-hypr --no-link`; `nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link`; `orgm-dot diff --host orgm`; `./dot.sh diff --host orgm`.
  - Rollback note: docs-only revert does not affect live behavior; verify report records any remaining deferred work.
