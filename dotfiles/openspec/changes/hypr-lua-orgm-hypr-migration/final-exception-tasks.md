# Final Exception Closure Tasks: hypr-lua-orgm-hypr-migration

Final follow-up after Slice 10. User explicitly expanded scope to close remaining exceptions by moving behavior to `orgm-hypr <function>` / `orgm-hypr <function> <subfunction>` surfaces, with scripts kept only as thin `exec orgm-hypr ... "$@"` compatibility wrappers where safe.

No application code changes belong in this tasks phase.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 650-1,200 additions + deletions across final closure |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 11 tests/audit → PR 12 command surfaces + wrappers → PR 13 sway caller + final audit/verify |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

## Non-negotiable final-closure instructions

- STRICT TDD MODE IS ACTIVE.
- Follow RED → GREEN → TRIANGULATE → REFACTOR for every Go behavior migration.
- Do not change app behavior while writing this task artifact.
- Scripts may remain only as no-logic wrappers that `exec orgm-hypr ... "$@"`, unless Slice 11 discovers a blocker and documents it before Slice 12 starts.
- No destructive action may run without explicit confirmation and/or `--dry-run` / `--print` support. This applies especially to `hypr-lock`, webapp creation/overwrite, and webapp removal/profile deletion.
- Current runtime blocks Nix/dot validators. During apply, run focused Go tests and `git diff --check`; record blocked evidence for `nix fmt`, `nix flake check`, `nix build .#packages.x86_64-linux.orgm-hypr --no-link`, `orgm-dot diff --host orgm`, and `./dot.sh diff --host orgm` when unavailable.
- Do not run `orgm-dot sync --host orgm` unless later explicitly approved.
- Preserve rollback by keeping old wrapper bodies recoverable from git and converting callers only after command parity tests pass.

## Target final command surfaces

| Current entrypoint / caller | Target command surface |
|---|---|
| `config/shared/.local/bin/hypr-webapp-maker` | `orgm-hypr webapp create --interactive` |
| `config/shared/.local/bin/hypr-webapp-remover` | `orgm-hypr webapp remove --interactive` |
| `config/shared/.local/bin/hypr-fuzzel` | `orgm-hypr launcher apps` or `orgm-hypr fuzzel apps` after Slice 11 naming decision |
| `config/shared/.local/bin/hypr-lock` | `orgm-hypr session lock` |
| `config/shared/.local/bin/hypr-focus-notification-app` | `orgm-hypr notify focus-app` |
| `config/shared/.local/bin/fuzzel-open-file` | `orgm-hypr file open --launcher fuzzel` |
| `config/shared/.local/bin/fuzzel-open-file-dir` | `orgm-hypr file open-dir --launcher fuzzel` |
| `config/shared/.local/bin/fuzzel-open-file-terminal` | `orgm-hypr file open-terminal --launcher fuzzel` |
| `config/shared/.local/bin/fuzzel-ssh-host` | `orgm-hypr ssh host --launcher fuzzel` |
| `config/shared/.local/bin/fuzzel-tmux-arch` | `orgm-hypr tmux arch --launcher fuzzel` |
| `config/shared/.local/bin/fuzzel-calc` | `orgm-hypr calc fuzzel` |
| `config/shared/.config/hypr/scripts/pi-walker-prompt.sh` | `orgm-hypr pi prompt --launcher walker` |
| `config/shared/.config/sway/config` caller of `waybar-watch` | `orgm-hypr waybar watch <config-dir>` |

## Slice 11: Characterize remaining wrappers and add command surface tests

- [x] 11.1 Refresh final exception audit before implementation.
  - Owner target: discovery/docs.
  - Files/discovery targets: `openspec/changes/hypr-lua-orgm-hypr-migration/wrapper-migration-audit.md`, `openspec/changes/hypr-lua-orgm-hypr-migration/final-exception-tasks.md`, `config/shared/.local/bin/hypr-webapp-maker`, `config/shared/.local/bin/hypr-webapp-remover`, `config/shared/.local/bin/hypr-fuzzel`, `config/shared/.local/bin/hypr-lock`, `config/shared/.local/bin/hypr-focus-notification-app`, `config/shared/.local/bin/fuzzel-open-file`, `config/shared/.local/bin/fuzzel-open-file-dir`, `config/shared/.local/bin/fuzzel-open-file-terminal`, `config/shared/.local/bin/fuzzel-ssh-host`, `config/shared/.local/bin/fuzzel-tmux-arch`, `config/shared/.local/bin/fuzzel-calc`, `config/shared/.config/hypr/scripts/pi-walker-prompt.sh`, `config/shared/.config/sway/config`, `config/dotfiles.json`.
  - RED boundary: no Go, wrapper, or caller edits yet.
  - Tasks: document current arguments, no-arg behavior, prompts, selection rows, cancel exits, dependencies, files read/written, destructive paths, callers, target command, wrapper disposition, parity check, and exact rollback for each exception.
  - Finish boundary: every listed exception has one target command surface or documented blocker approved before Slice 12.
  - Verification: docs diff only; `git diff --check`; record blocked Nix/dot validators if attempted.
  - Rollback: revert audit/task artifact edits only.

- [x] 11.2 Add RED CLI contract tests for final command names and safety flags.
  - Owner target: `orgm-hypr` command router.
  - Files/discovery targets: `cmd/orgm-hypr/main_test.go`, `cmd/orgm-hypr/main.go`, future `internal/launcher/**` or `internal/fuzzel/**`, `internal/session/**`, `internal/notify/**`, future `internal/filelauncher/**`, future `internal/sshmenu/**`, future `internal/tmuxmenu/**`, future `internal/calc/**`, future `internal/pi/**`, `internal/webapp/**`, `internal/waybar/**`.
  - RED tasks: assert usage/help and stable exit behavior for `webapp create --interactive`, `webapp remove --interactive`, launcher/fuzzel app command chosen in 11.1, `session lock`, `notify focus-app`, `file open`, `file open-dir`, `file open-terminal`, `ssh host`, `tmux arch`, `calc fuzzel`, `pi prompt`, and `waybar watch` direct sway usage.
  - Safety tests: cancel exits 0 without action; usage errors exit 2; runtime failures are non-zero with `orgm-hypr: ...`; `--print`/`--dry-run` modes do not launch fuzzel/rofi/walker/kitty/hyprlock/remove files.
  - Finish boundary: tests fail because command surfaces or safety behavior are missing/incomplete.
  - Verification: RED `go test ./cmd/orgm-hypr ./internal/...`; `git diff --check`.
  - Rollback: revert tests only; existing wrappers remain behavior owners.

- [x] 11.3 Add RED characterization tests for wrapper behavior models.
  - Owner target: domain packages.
  - Files/discovery targets: `internal/webapp/**`, future `internal/launcher/**` or `internal/fuzzel/**`, `internal/session/**`, `internal/notify/**`, future `internal/filelauncher/**`, future `internal/sshmenu/**`, future `internal/tmuxmenu/**`, future `internal/calc/**`, future `internal/pi/**`.
  - RED tasks: create fake runner/filesystem tests for current wrapper behavior: fuzzel row generation, selected row parsing, file path quoting, opener command plans, ssh host discovery, tmux arch container/session plan, calculator output plan, Pi walker prompt plan, notification app focus matching, lock command plan, webapp interactive prompts and remove choices.
  - Destructive gates: tests must prove `session lock` requires explicit live execution boundary; webapp overwrite/remove/profile deletion requires confirmation; print/dry-run performs no mutation.
  - Finish boundary: failing tests identify missing domain behavior before implementation.
  - Verification: RED focused tests per new package plus `go test ./cmd/orgm-hypr`; blocked validators recorded if applicable.
  - Rollback: revert tests only.

## Slice 12: Implement interactive command surfaces and convert safe wrappers to thin exec

- [x] 12.1 Implement interactive webapp create/remove in `orgm-hypr webapp`.
  - Owner target: `orgm-hypr webapp`.
  - Files/discovery targets: `cmd/orgm-hypr/main.go`, `internal/webapp/**`, `config/shared/.local/bin/hypr-webapp-maker`, `config/shared/.local/bin/hypr-webapp-remover`.
  - GREEN tasks: implement no-arg interactive rofi-compatible UX in Go for maker/remover; keep prompt/data/action planning testable; preserve `webapp list`, `create --dry-run`, `remove --dry-run`; add `--print` where useful.
  - Destructive gates: require explicit selected app and confirmation for remove/profile deletion; require overwrite confirmation for existing desktop/profile/icon paths; cancel exits 0 with no mutation.
  - Wrapper conversion: after tests pass, replace maker/remover scripts with `exec orgm-hypr webapp create --interactive "$@"` and `exec orgm-hypr webapp remove --interactive "$@"`.
  - Verification: GREEN `go test ./internal/webapp ./cmd/orgm-hypr`; `go test ./...`; wrapper static grep for `exec orgm-hypr`; `git diff --check`; record blocked Nix/dot validators.
  - Rollback: restore previous `hypr-webapp-maker` / `hypr-webapp-remover` bodies and keep Go command unused.

- [x] 12.2 Implement fuzzel/app launcher and lock/notification command surfaces.
  - Owner target: launcher/session/notify.
  - Files/discovery targets: `cmd/orgm-hypr/main.go`, future `internal/launcher/**` or `internal/fuzzel/**`, `internal/session/**`, `internal/notify/**`, `config/shared/.local/bin/hypr-fuzzel`, `config/shared/.local/bin/hypr-lock`, `config/shared/.local/bin/hypr-focus-notification-app`, `config/shared/.config/swaync/config.json`.
  - GREEN tasks: implement chosen app launcher command preserving `hypr-fuzzel` monitor/scale behavior; implement `session lock` with safe command planning and optional `--print`; implement `notify focus-app` by moving focus-notification app matching/dispatch into Go.
  - Destructive/unsafe gates: lock live mode must be explicit and test-covered; cancel/no-match exits safely; missing `hyprlock`, `hyprctl`, `swaync-client`, or launcher dependencies report non-destructive errors.
  - Wrapper conversion: convert `hypr-fuzzel`, `hypr-lock`, and `hypr-focus-notification-app` to thin `exec orgm-hypr ... "$@"` only after parity tests pass.
  - Verification: focused package tests; `go test ./cmd/orgm-hypr ./internal/session ./internal/notify ./...`; wrapper static checks; `git diff --check`; manual lock/notify smoke only if safe and approved, otherwise record blocked/manual-not-run reason.
  - Rollback: restore prior wrapper bodies and any swaync caller if changed.

- [x] 12.3 Implement file/ssh/tmux/calc/Pi interactive command surfaces.
  - Owner target: file launcher, ssh menu, tmux menu, calc, Pi prompt.
  - Files/discovery targets: `cmd/orgm-hypr/main.go`, future `internal/filelauncher/**`, future `internal/sshmenu/**`, future `internal/tmuxmenu/**`, future `internal/calc/**`, future `internal/pi/**`, `config/shared/.local/bin/fuzzel-open-file`, `config/shared/.local/bin/fuzzel-open-file-dir`, `config/shared/.local/bin/fuzzel-open-file-terminal`, `config/shared/.local/bin/fuzzel-ssh-host`, `config/shared/.local/bin/fuzzel-tmux-arch`, `config/shared/.local/bin/fuzzel-calc`, `config/shared/.config/hypr/scripts/pi-walker-prompt.sh`.
  - GREEN tasks: move file discovery/selection/open plans, ssh host discovery/selection, tmux arch session/container plan, calculator prompt/evaluation plan, and Pi walker prompt/kitty launch plan into Go with fake runner tests.
  - Safety gates: selection cancel exits 0; paths are passed as args not shell-concatenated; terminal/open/ssh/tmux/pi commands support `--print`; no container/tmux/kitty/process launch occurs in print/dry-run tests.
  - Wrapper conversion: convert all listed fuzzel/Pi scripts to thin `exec orgm-hypr ... "$@"` wrappers after GREEN tests.
  - Verification: focused package tests; `go test ./cmd/orgm-hypr ./...`; wrapper static checks for all listed paths; `git diff --check`; blocked Nix/dot validators recorded.
  - Rollback: restore previous script bodies; leave new commands unused or revert Slice 12 package files.

- [x] 12.4 TRIANGULATE and REFACTOR shared launcher primitives.
  - Owner target: shared command runner/interactive selection helpers.
  - Files/discovery targets: new `internal/*` packages from 12.1-12.3, `internal/cli/**`, `cmd/orgm-hypr/main.go`.
  - Tasks: remove duplicated fuzzel/rofi/walker runner code only after two or more domains pass tests; keep pure model functions separate from live runners; maintain small package boundaries.
  - Finish boundary: no behavior changes beyond deduplication; tests remain green.
  - Verification: `go test ./...`; `git diff --check`; blocked Nix validator evidence.
  - Rollback: revert refactor commit only; wrapper conversions from earlier tasks remain recoverable.

## Slice 13: Update sway caller, final audit, and verification

- [x] 13.1 Update Sway `waybar-watch` caller to canonical `orgm-hypr waybar watch`.
  - Owner target: non-Hypr explicit caller migration.
  - Files/discovery targets: `config/shared/.config/sway/config`, `config/shared/.local/bin/waybar-watch`, `internal/waybar/**`, `cmd/orgm-hypr/main.go`.
  - Start boundary: existing `orgm-hypr waybar watch` tests pass and command supports the Sway config path.
  - Tasks: replace Sway caller of `waybar-watch` with direct `orgm-hypr waybar watch <config-dir>`; keep `waybar-watch` wrapper if external compatibility still needed.
  - Verification: focused Waybar tests; static grep confirms Sway caller no longer invokes `waybar-watch`; `git diff --check`; manual Sway smoke or documented blocker.
  - Rollback: restore previous Sway caller string.

- [x] 13.2 Run final wrapper/caller audit and update OpenSpec evidence.
  - Owner target: docs/audit.
  - Files/discovery targets: `openspec/changes/hypr-lua-orgm-hypr-migration/wrapper-migration-audit.md`, `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md`, `openspec/changes/hypr-lua-orgm-hypr-migration/verify-report.md`, `openspec/changes/hypr-lua-orgm-hypr-migration/final-exception-tasks.md`, `config/shared/.local/bin/**`, `config/shared/.config/hypr/scripts/*.sh`, `config/shared/.config/sway/config`, `config/shared/.config/swaync/config.json`, `config/dotfiles.json`.
  - Tasks: record final state for every former exception: target command, wrapper thin/removed/blocked status, caller list, test evidence, manual smoke evidence or blocker, rollback action.
  - Finish boundary: no behavior-owning listed exception remains unless explicitly blocked with user-approved rationale.
  - Verification: static audit for old script callers and non-thin wrapper logic; `git diff --check`.
  - Rollback: docs-only revert does not affect live behavior.

- [x] 13.3 Final validation gate for closure.
  - Owner target: verification.
  - Commands to run when available: `go test ./...`; `git diff --check`; `nix fmt`; `nix flake check`; `nix build .#packages.x86_64-linux.orgm-hypr --no-link`; `orgm-dot diff --host orgm`; `./dot.sh diff --host orgm`.
  - Blocked validator rule: if Nix/dot commands are blocked by current runtime, record exact command and blocker in `verify-report.md`; do not claim those validators passed.
  - Manual smoke checklist: webapp create/remove dry-run; webapp remove cancellation; app launcher cancellation; lock `--print`; notification no-match; file open `--print`; ssh/tmux/calc/Pi prompt cancellation; Sway waybar watcher command plan.
  - Finish boundary: final report states whether all requested exceptions now route through `orgm-hypr` command surfaces and lists any remaining blockers by exact path.
  - Rollback: use per-slice rollback above; for emergency, revert Slices 11-13 and restore prior wrappers/callers from git.
