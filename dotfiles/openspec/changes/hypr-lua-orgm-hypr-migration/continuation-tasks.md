# Continuation Tasks: hypr-lua-orgm-hypr-migration

Continuation starts after completed Slice 7. New requirement: every remaining external action/caller MUST route through `orgm-hypr <function>` or `orgm-hypr <function> <subfunction>` where applicable. Hyprland Lua may still own compositor-local config, but scripts may remain only as thin compatibility wrappers that `exec orgm-hypr ...`; scripts must not own behavior.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 700-1,400 additions + deletions across continuation |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 8 command surface + wrapper migration → PR 9 menu/smart-run/webapp migration → PR 10 caller migration/cleanup verification |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

## Non-negotiable continuation instructions

- STRICT TDD MODE IS ACTIVE.
- Test runner remains `nix flake check`, but current runtime blocks `nix`; use focused Go tests, `go test ./...`, and `git diff --check`, then record blocked `nix`/`orgm-dot`/`dot.sh` evidence.
- Follow RED → GREEN → TRIANGULATE → REFACTOR for every Go behavior migration.
- No behavior-owning shell script may remain after Slice 10 unless explicitly out of scope and documented with caller audit.
- Thin compatibility wrappers are allowed only when they exec `orgm-hypr ... "$@"` or an equivalent no-logic delegation.
- Destructive actions must be gated by explicit confirmation, `--dry-run`/`--print`, or both.
- Concurrent project changes are allowed; report unrelated errors only when untouched files/functions fail.
- Do not run `orgm-dot sync` during planning/apply unless later explicitly approved.

## Slice 8: Command surface normalization and wrapper migration

- [x] 8.1 Refresh command-surface inventory against live wrappers and callers.
  - Owner target: discovery/docs.
  - Files/discovery targets: `openspec/changes/hypr-lua-orgm-hypr-migration/inventory.md`, `config/shared/.local/bin/hypr-*`, `config/shared/.local/bin/fuzzel-*`, `config/shared/.local/bin/*-osd`, `config/shared/.local/bin/waybar-*`, `config/shared/.config/hypr/scripts/*.sh`, `config/shared/.config/hypr/lua/programs.lua`, `config/shared/.config/hypr/10-programs.conf`, `config/shared/.config/hypr/20-autostart.conf`, `config/shared/.config/hypr/70-keybindings.conf`.
  - Start boundary: read existing inventory, menu/webapp characterization, apply progress, and current wrappers; do not edit behavior.
  - Tasks: list each external action, current caller, target `orgm-hypr <function> [subfunction]`, wrapper disposition, parity check, and rollback path.
  - Finish boundary: every remaining script behavior has target command/subcommand or explicit out-of-scope rationale.
  - Verification: docs diff only; `git diff --check` after artifact updates.
  - Rollback: revert inventory/continuation artifact updates only.

- [x] 8.2 Add RED CLI contract tests for all remaining command/subcommand names before wrapper changes.
  - Owner target: `orgm-hypr`.
  - Files/discovery targets: `cmd/orgm-hypr/main_test.go`, `cmd/orgm-hypr/main.go`, `internal/session/**`, `internal/waybar/**`, `internal/dock/**`, `internal/windows/**`, `internal/zen/**`, `internal/osd/**`, `internal/smartrun/**`, future `internal/menu/**`, future `internal/webapp/**`.
  - Start boundary: no wrapper or caller edits.
  - Tasks: assert stable usage/output/exit behavior for `session`, `waybar`, `dock`, `windows`, `zen`, `osd`, `menu`, `smart-run`, `webapp`, and compatibility aliases needed by wrappers.
  - Finish boundary: tests fail for missing or incomplete command surface before implementation.
  - Verification: RED focused `go test ./cmd/orgm-hypr ./internal/...` evidence recorded.
  - Rollback: revert tests only; wrappers remain old behavior.

- [x] 8.3 Implement missing safe `orgm-hypr` command/subcommand surfaces with print/dry-run modes first.
  - Owner target: `orgm-hypr`.
  - Files/discovery targets: `cmd/orgm-hypr/main.go`, `internal/session/**`, `internal/waybar/**`, `internal/dock/**`, `internal/windows/**`, `internal/zen/**`, `internal/osd/**`, `internal/smartrun/**`, `internal/menu/**`, `internal/webapp/**`.
  - Start boundary: RED tests from 8.2 exist.
  - Tasks: fill safe command routing so wrappers can delegate without shell-owned decisions; preserve exit 0 on cancel/no-op, usage errors exit 2, runtime errors non-zero with `orgm-hypr: ...`.
  - Finish boundary: command surface complete enough for wrapper delegation; destructive/runtime actions have `--print` or `--dry-run`.
  - Verification: GREEN focused Go tests; `go test ./...`; `git diff --check`; record blocked `nix flake check` if still unavailable.
  - Rollback: leave old wrappers untouched until 8.4; revert Go command additions if unsafe.

- [x] 8.4 Convert non-interactive and already-characterized wrappers to thin `exec orgm-hypr ...` compatibility wrappers.
  - Owner target: script compatibility.
  - Files/discovery targets: `config/shared/.local/bin/waybar-date-es`, `waybar-day-month-es`, `waybar-time-ampm`, `waybar-swap-usage`, `hypr-workspace-button`, `hypr-nwg-dock`, `hypr-zen-new-window`, `volume-osd`, `mic-volume-osd`, `brightness-osd`, `hypr-current-wallpaper`, `hypr-random-wallpaper`, relevant tests/docs.
  - Start boundary: Go command parity tests pass; old wrapper body preserved in git rollback.
  - Tasks: replace behavior-owning shell bodies with no-logic wrappers that `exec orgm-hypr <function> <subfunction> "$@"`; keep only env/path compatibility needed for invocation.
  - Finish boundary: listed wrappers contain no behavior decisions beyond exec delegation.
  - Verification: wrapper static checks for `exec orgm-hypr`; focused Go tests; `go test ./...`; `git diff --check`; manual smoke checklist if runtime available.
  - Rollback: restore previous wrapper body or revert Slice 8 wrapper commit.

- [x] 8.5 Convert window/session helper wrappers where safe, keep interactive prompts only as delegated modes.
  - Owner target: `orgm-hypr` + script compatibility.
  - Files/discovery targets: `config/shared/.local/bin/fuzzel-hypr-window`, `hypr-kill-windows`, `config/shared/.config/hypr/scripts/walker-window-switch.sh`, `config/shared/.config/hypr/lua/autostart.lua`, `config/shared/.config/hypr/20-autostart.conf`, `cmd/orgm-hypr/main.go`, `internal/windows/**`, `internal/session/**`.
  - Start boundary: command equivalents exist and cancellation/destructive paths are tested.
  - Tasks: route window listing/focus/kill and session/autostart helper calls through `orgm-hypr`; any retained prompt wrapper must only collect selection and exec `orgm-hypr` or use `orgm-hypr` interactive subcommand.
  - Finish boundary: no window/session shell behavior remains owner of parsing, filtering, dispatch, or kill decisions.
  - Verification: focused Go tests; wrapper static checks; manual focus/kill/autostart parity where available; blocked runtime evidence recorded.
  - Rollback: restore previous wrappers/autostart callers.

## Slice 9: Interactive menu/webapp migration

- [x] 9.1 Add RED characterization tests for menu models and actions.
  - Owner target: `orgm-hypr menu`.
  - Files/discovery targets: `openspec/changes/hypr-lua-orgm-hypr-migration/menu-webapp-characterization.md`, `cmd/orgm-hypr/main_test.go`, `internal/menu/**`, wrappers `hypr-main-menu`, `hypr-system-menu`, `hypr-tools-menu`, `hypr-performance-menu`, `hypr-wifi-menu`, `hypr-bluetooth-menu`, `hypr-keyboard-menu`, `hypr-power-menu`, `hypr-keybindings-help`.
  - Start boundary: wrappers still own live behavior.
  - Tasks: test menu item lists, labels, cancel/no-op exits, selected action plans, missing dependency behavior, keybinding category data, and power/destructive action confirmation requirements.
  - Finish boundary: tests fail before `internal/menu` implementation.
  - Verification: RED focused `go test ./internal/menu ./cmd/orgm-hypr` evidence.
  - Rollback: revert tests only.

- [x] 9.2 Implement `orgm-hypr menu <subfunction>` with safe print/dry-run and gated destructive actions.
  - Owner target: `orgm-hypr menu`.
  - Files/discovery targets: `cmd/orgm-hypr/main.go`, `internal/menu/**`.
  - Tasks: implement `menu main`, `menu system`, `menu tools`, `menu performance`, `menu wifi`, `menu bluetooth`, `menu keyboard`, `menu power`, and `menu keybindings`; separate pure menu data/action planning from rofi/fuzzel execution; require confirmation or explicit selected action for lock/suspend/hibernate/reboot/poweroff/logout.
  - Finish boundary: print/dry-run modes cover every menu without launching external actions; live mode preserves cancel semantics.
  - Verification: GREEN focused tests; `go test ./internal/menu ./cmd/orgm-hypr`; `go test ./...`; `git diff --check`.
  - Rollback: wrappers continue old behavior until 9.3.

- [x] 9.3 Convert menu wrappers to thin `exec orgm-hypr menu ...` wrappers.
  - Owner target: script compatibility.
  - Files/discovery targets: `config/shared/.local/bin/hypr-main-menu`, `hypr-system-menu`, `hypr-tools-menu`, `hypr-performance-menu`, `hypr-wifi-menu`, `hypr-bluetooth-menu`, `hypr-keyboard-menu`, `hypr-power-menu`, `hypr-keybindings-help`.
  - Tasks: replace shell menu logic with direct delegation to matching `orgm-hypr menu` subcommand; preserve old entrypoint names for keybindings/dock/user muscle memory.
  - Finish boundary: all menu wrappers are no-logic exec wrappers.
  - Verification: wrapper static checks; focused menu tests; manual menu smoke tests or blocked evidence.
  - Rollback: restore old wrapper bodies.

- [x] 9.4 Expand `orgm-hypr smart-run` from parser/print mode to behavior owner with safe execution boundary.
  - Owner target: `orgm-hypr smart-run`.
  - Files/discovery targets: `config/shared/.local/bin/hypr-smart-run`, `cmd/orgm-hypr/main.go`, `internal/smartrun/**`.
  - Tasks: add tests for launcher execution plans, browser/desktop/clipboard command runners, dependency misses, and cancellation; implement `smart-run run` live mode behind runner interface while keeping `--print` stable.
  - Finish boundary: `hypr-smart-run` can be thin wrapper to `orgm-hypr smart-run run "$@"`.
  - Verification: RED/GREEN focused tests; `go test ./internal/smartrun ./cmd/orgm-hypr`; manual launch parity if runtime available.
  - Rollback: restore old `hypr-smart-run` body or keep wrapper pointing to old copy if parity fails.

- [x] 9.5 Implement `orgm-hypr webapp` dry-run/list/create/remove with destructive gates before wrapper switch.
  - Owner target: `orgm-hypr webapp`.
  - Files/discovery targets: `config/shared/.local/bin/hypr-webapp-maker`, `hypr-webapp-remover`, `cmd/orgm-hypr/main.go`, `internal/webapp/**`, `${XDG_DATA_HOME}/applications` behavior modeled in tests.
  - Tasks: add fake filesystem/process tests for slugging, desktop file generation, launcher generation, icon path/download fallback planning, list discovery, safe `Exec=` validation, cancel behavior, and profile deletion requiring explicit confirmation; implement `webapp list`, `webapp create --dry-run`, `webapp remove --dry-run`, then live mode only after tests.
  - Finish boundary: maker/remover scripts can become thin wrappers or remain deferred only if documented blocker prevents safe parity.
  - Verification: focused webapp tests; `go test ./internal/webapp ./cmd/orgm-hypr`; dry-run/manual file diff evidence; no destructive deletion without explicit test and confirmation evidence.
  - Rollback: keep old webapp scripts until parity passes; restore script bodies if live Go behavior differs.

## Slice 10: Caller migration and cleanup verification

- [x] 10.1 Update Hypr Lua and hyprlang fallback callers to canonical `orgm-hypr` command names.
  - Owner target: Hyprland Lua/config callers.
  - Files/discovery targets: `config/shared/.config/hypr/lua/programs.lua`, `config/shared/.config/hypr/lua/keybindings.lua`, `config/shared/.config/hypr/lua/autostart.lua`, `config/shared/.config/hypr/10-programs.conf`, `config/shared/.config/hypr/20-autostart.conf`, `config/shared/.config/hypr/70-keybindings.conf`, `config/shared/.config/hypr/scripts/*.sh`.
  - Start boundary: wrappers are thin or commands are parity-proven.
  - Tasks: replace external caller strings from `hypr-*`, `fuzzel-*`, `waybar-*`, and OSD script paths to canonical `orgm-hypr <function> [subfunction]` where direct caller migration is safe; keep compatibility wrapper paths only where external non-repo callers require them.
  - Finish boundary: repo-owned Hypr Lua/fallback conf callers use `orgm-hypr` command names for external actions.
  - Verification: Lua syntax check; grep/static audit for old script callers; focused Go tests; manual keybinding/autostart smoke or blocked evidence.
  - Rollback: restore previous caller strings or wrapper delegation.

- [x] 10.2 Audit wrappers for keep/remove decisions based on caller parity.
  - Owner target: cleanup/docs.
  - Files/discovery targets: all wrapper paths under `config/shared/.local/bin/` and `config/shared/.config/hypr/scripts/`, `config/dotfiles.json`, `openspec/changes/hypr-lua-orgm-hypr-migration/inventory.md`, `apply-progress.md`, `verify-report.md`.
  - Tasks: for each wrapper, decide `keep thin wrapper`, `remove from managed manifest`, or `defer`; require affected caller list, replacement command, validation evidence, and rollback action.
  - Finish boundary: no behavior-owning wrappers remain; any kept wrapper has compatibility rationale.
  - Verification: static audit for shell logic; manifest diff review; `git diff --check`; blocked `orgm-dot diff --host orgm` recorded if unavailable.
  - Rollback: restore wrapper path and manifest entry from previous commit.

- [x] 10.3 Run cleanup only after parity gate passes.
  - Owner target: script/manifest cleanup.
  - Files/discovery targets: selected wrapper files, `config/dotfiles.json`, `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md`, `verify-report.md`.
  - Start boundary: 10.2 keep/remove decision complete; verification commands available or blockers approved.
  - Tasks: remove only wrappers with no repo/external caller requirement; keep thin wrappers for compatibility; update dotfiles manifest only for removed managed paths.
  - Finish boundary: cleanup diff is limited to approved wrapper/manifest/docs changes.
  - Verification: `go test ./...`; `git diff --check`; `nix flake check` when available; `orgm-dot diff --host orgm` when available; manual wrapper/caller smoke tests.
  - Rollback: restore removed wrappers and manifest entries.

- [x] 10.4 Final continuation verification report.
  - Owner target: verify/docs.
  - Files/discovery targets: `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md`, `verify-report.md`, `continuation-tasks.md`, optional `wrapper-migration-audit.md`.
  - Tasks: record final command surface audit, wrapper keep/remove table, caller migration evidence, Go test evidence, `nix`/dot evidence or blockers, manual Hyprland parity checklist, and remaining deferred items.
  - Finish boundary: report states whether all external actions now route through `orgm-hypr` or names exact exceptions.
  - Verification: docs present; `git diff --check`; no success claim without recorded command output/blockers.
  - Rollback: docs-only revert does not affect live behavior.
