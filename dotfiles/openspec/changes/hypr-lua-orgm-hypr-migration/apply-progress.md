# Apply Progress: hypr-lua-orgm-hypr-migration

## Workload / PR boundary

- Delivery path: auto-chain approved by parent/user.
- Applied PR slices: Slice 1 (inventory + Go CLI test harness), Slice 2 (Lua foundation), Slice 3 (compositor parity), Slice 4 (Session, Waybar, Dock CLI), Slice 5 (Windows, Zen, OSD CLI), Slice 6 (Menu, smart-run, webapp), and Slice 7 (cleanup decision, docs, partial verification).
- Current stop point: after Slice 7. User requested stop after Slice 7.
- PR boundary: Slice 7 performs documentation and final partial verification only. Because manual Hyprland parity, `nix`, `orgm-dot`, and project `./dot.sh` verification are blocked, no script deletion, shrinking, caller migration, dotfile sync, or cleanup was performed.

## Completed tasks

- [x] 1.1 Refresh migration inventory without behavior changes.
- [x] 1.2 Add Go CLI test harness before new command behavior.
- [x] 2.1 Characterize current Lua/hyprlang load structure before refactor.
- [x] 2.2 Add or normalize Lua module tree additively.
- [x] 3.1 Migrate/validate keybindings through Lua without removing shell entrypoints.
- [x] 3.2 Migrate/validate monitor, input, look/layout, windows, and workspace rules.
- [x] 4.1 Add `orgm-hypr session` characterization tests, then implementation.
- [x] 4.2 Add `orgm-hypr waybar` tests and commands with wrappers retained.
- [x] 4.3 Add `orgm-hypr dock` tests and command with compatibility wrapper.
- [x] 5.1 Add `orgm-hypr windows` tests and commands before wrapper switch.
- [x] 5.2 Add `orgm-hypr zen` tests and command.
- [x] 5.3 Add `orgm-hypr osd` tests and commands with wrappers retained.
- [x] 6.1 Characterize menu wrappers before optional Go migration.
- [x] 6.2 Add `orgm-hypr smart-run` parser tests, then implementation or wrapper delegation.
- [x] 6.3 Characterize webapp maker/remover and defer unless tests make migration safe.
- [x] 7.1 Remove or shrink scripts only after replacement and parity evidence exists (evaluated; cleanup skipped because required runtime/dot/nix parity evidence is incomplete).
- [x] 7.2 Update docs and verification evidence.

## Files changed by completed slices

- `openspec/changes/hypr-lua-orgm-hypr-migration/inventory.md` — refreshed classification inventory.
- `openspec/changes/hypr-lua-orgm-hypr-migration/tasks.md` — marked Slice 1, Slice 2, Slice 3, and Slice 4 tasks complete.
- `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md` — cumulative evidence.
- `openspec/changes/hypr-lua-orgm-hypr-migration/compositor-parity.md` — Slice 3 parity checklist and runtime smoke matrix.
- `cmd/orgm-hypr/main.go` — Slice 1 testability refactor only: `runWithIO` / `runWallpaperWithIO`, injected stdout/stderr; no intended CLI behavior change.
- `cmd/orgm-hypr/main_test.go` — Slice 1 characterization tests for version, missing command usage, placeholder groups, and wallpaper usage errors.
- `config/shared/.config/hypr/lua/README.md` — Slice 2 Lua foundation notes: current Lua entrypoint order, module contract, hyprlang fallback order, rollback note.
- `config/shared/.config/hypr/10-programs.conf` — Slice 3 fallback parity: adds `$control_center` for existing Lua `programs.control_center`.
- `config/shared/.config/hypr/70-keybindings.conf` — Slice 3 fallback parity: adds `SUPER+ALT+Space` control center bind matching Lua.
- `config/shared/.config/hypr/55-layout.conf` — Slice 3 fallback parity: adds `scrolling` block matching Lua `layout.lua`.
- `cmd/orgm-hypr/main.go` — Slice 4 command routing for `session`, `waybar`, and `dock`; wrappers remain untouched.
- `cmd/orgm-hypr/main_test.go` — Slice 4 CLI characterization tests for session import env print, Waybar date/swap helpers, and dock compatibility args.
- `internal/session/session.go` / `internal/session/session_test.go` — typed session command decisions for env import, container engine choice, and Discord native/Flatpak choice.
- `internal/waybar/waybar.go` / `internal/waybar/waybar_test.go` — Waybar date, swap usage, workspace JSON, and watch-plan characterization helpers.
- `internal/dock/dock.go` / `internal/dock/dock_test.go` — nwg-dock compatibility args and idempotent start-plan characterization.
- `cmd/orgm-hypr/main.go` — Slice 5 command routing for `windows`, `zen`, and `osd`; live OSD/Zen open-new-window remains deferred to existing wrappers, while print/list/focus paths are available for safe partial verification.
- `cmd/orgm-hypr/main_test.go` — Slice 5 CLI tests for windows list/focus, Zen focus, and OSD print planning.
- `internal/windows/windows.go` / `internal/windows/windows_test.go` — Hyprland client JSON parsing, window labels, focus dispatch construction, and kill-menu candidate filtering/labels.
- `internal/zen/zen.go` / `internal/zen/zen_test.go` — Zen client focus selection and install/run command planning.
- `internal/osd/osd.go` / `internal/osd/osd_test.go` — volume, mic, and brightness command/notification planning.
- `openspec/changes/hypr-lua-orgm-hypr-migration/menu-webapp-characterization.md` — Slice 6 menu inventory, smart-run characterization, and webapp maker/remover deferral rationale.
- `cmd/orgm-hypr/main.go` — Slice 6 command routing for `smart-run parse` and print-safe `smart-run run --print`; live execution remains deferred to existing wrapper.
- `cmd/orgm-hypr/main_test.go` — Slice 6 CLI tests for smart-run parse/run print plans.
- `internal/smartrun/smartrun.go` / `internal/smartrun/smartrun_test.go` — pure smart-run parser covering URL/search/app/command/domain/default/no-op decisions.
- `openspec/changes/hypr-lua-orgm-hypr-migration/tasks.md` — Slice 7 marked complete with cleanup skipped by safety gate.
- `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md` — final partial verification evidence and blockers.
- `openspec/changes/hypr-lua-orgm-hypr-migration/verify-report.md` — final partial verification report.

## Slice 2 characterization

### Current Lua entrypoint order

`config/shared/.config/hypr/hyprland.lua` loads:

1. `lua.monitors`
2. `lua.programs`
3. `lua.autostart`
4. `lua.environment`
5. `lua.permissions`
6. `lua.look-and-feel`
7. `lua.layout`
8. `lua.input`
9. `lua.keybindings` via `.setup(programs)`
10. `lua.windows-workspaces`

### Current Lua modules

- `monitors.lua`: single preferred monitor rule with explicit scale 1.
- `programs.lua`: centralized command strings and compatibility wrapper paths.
- `autostart.lua`: `hyprland.start` event executes startup command list.
- `environment.lua`: pure `hl.env` declarations.
- `permissions.lua`: documented/commented permissions only; no active permission changes.
- `look-and-feel.lua`: general, decoration, animations, curves.
- `layout.lua`: dwindle/master/scrolling/misc config.
- `input.lua`: keyboard/mouse/touchpad plus 3-finger workspace gesture.
- `keybindings.lua`: `setup(programs)` binds compositor actions and existing external wrappers.
- `windows-workspaces.lua`: opacity, utility float/size/center, modal float, XWayland empty class rule.

### Hyprlang fallback order

`config/shared/.config/hypr/hyprland.conf` still sources:

1. `00-monitors.conf`
2. `10-programs.conf`
3. `20-autostart.conf`
4. `30-environment.conf`
5. `40-permissions.conf`
6. `50-look-and-feel.conf`
7. `55-layout.conf`
8. `60-input.conf`
9. `70-keybindings.conf`
10. `80-windows-workspaces.conf`
11. `90-noctalia-colors.conf`

Fallback remains intact. No script, caller, or manifest changed through Slice 3.

## Slice 3 characterization

- Existing Lua modules already own keybindings, monitors, input, look/layout, windows, and workspace behavior.
- No Lua module reorganization was needed; low-churn parity validation was preferred.
- All shell entrypoints referenced by keybindings remain external wrappers.
- Split conf fallback remains active and was brought closer to current Lua behavior:
  - Added `$control_center = ~/.local/bin/hypr-main-menu` to `10-programs.conf`.
  - Added fallback `SUPER+ALT+Space` bind to `$control_center` in `70-keybindings.conf`.
  - Added fallback `scrolling` layout block to `55-layout.conf`.
- Host/manual parity checklist lives in `openspec/changes/hypr-lua-orgm-hypr-migration/compositor-parity.md`.

## Slice 4 characterization

- `orgm-hypr session import-env --print` prints the same `systemctl --user import-environment ...` and `dbus-update-activation-environment --systemd ...` command shapes as current Lua/hyprlang autostart.
- `internal/session` also characterizes container startup engine selection (`docker` before `podman`) and Discord startup selection (native `discord --start-minimized` before Flatpak). These decisions are typed but not wired into live autostart; old shell autostart remains fallback.
- `orgm-hypr waybar date --format date-es|day-month-es|time-ampm` and `orgm-hypr waybar swap-usage` match current tiny helper outputs. `watch-plan` captures current config/style/log paths. Workspace JSON helper is characterized internally, but live hyprctl status/click wiring stays with existing `hypr-workspace-button` wrapper for now.
- `orgm-hypr dock start --print-args` prints current `hypr-nwg-dock` `nwg-dock-hyprland` argument list. `dock start --reload` has minimal live compatibility behavior, but the existing `hypr-nwg-dock` script remains unchanged and is still the runtime fallback.
- No scripts were deleted or rewritten. No callers were migrated.

## Slice 5 characterization

- `orgm-hypr windows list --clients PATH` prints address + compatibility labels from hyprctl JSON (`[workspace] class — title`). Without `--clients`, it reads `hyprctl -j clients`; existing `fuzzel-hypr-window`, `hypr-kill-windows`, and Walker scripts remain runtime fallback.
- `orgm-hypr windows focus ADDRESS --print` constructs the same Hyprland Lua focus dispatch shape used by current scripts. Non-print execution can run `hyprctl dispatch ...`; no wrapper switched.
- `internal/windows.KillCandidatesFromJSON` characterizes safe kill-menu candidate filtering: unique PID, current-user ownership via injected RSS/ownership probe, RSS threshold, sorted labels. Interactive fuzzel flow remains wrapper-owned.
- `orgm-hypr zen focus --clients PATH --print` chooses the most recent Zen window by `focusHistoryID` from classes `app.zen_browser.zen` and `zen-browser`, then prints the focus dispatch. `zen open-new-window` run behavior is characterized in pure code but not enabled live; existing `hypr-zen-new-window` remains fallback.
- `orgm-hypr osd volume|mic|brightness ACTION --print` prints planned device command and notify-send payload from injected state. Live hardware execution is intentionally deferred to existing `volume-osd`, `mic-volume-osd`, and `brightness-osd` wrappers.
- No scripts were deleted or rewritten. No callers were migrated.

## Slice 6 characterization

- Menu wrappers (`hypr-main-menu`, system/tools/performance/WiFi/Bluetooth/keyboard/power/keybindings) were documented in `menu-webapp-characterization.md` with callers, menu items/actions, dependencies, cancel paths, and retained-script rationale.
- `orgm-hypr smart-run parse QUERY...` and `orgm-hypr smart-run run QUERY... --print` now expose parser decisions without launching GUI/browser/apps. Existing `hypr-smart-run` remains live runtime fallback.
- Smart-run parser captures current shell behavior: trim/no-op, direct URL, localhost URL, ChatGPT/Claude desktop hints, Google/YouTube search hints, executable command, domain URL, and default ChatGPT desktop query.
- Webapp maker/remover were characterized and deferred. Destructive remover profile deletion (`rm -rf`) and maker file/network writes are not migrated in Slice 6.
- No scripts were deleted or rewritten. No callers were migrated.

## TDD Cycle Evidence

| Task | Test File / Check | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-------------------|-------|------------|-----|-------|-------------|----------|
| 1.1 | `openspec/.../inventory.md` | Structural artifact | N/A (new artifact) | Structural docs-only; no production code | Inventory written | Triangulation skipped: no code logic, classification artifact only | N/A |
| 1.2 | `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ `go test ./cmd/orgm-hypr ./internal/cli` before edit: packages had no test files, no failures | ✅ `go test ./cmd/orgm-hypr -run 'TestRunWithIO'` failed: `undefined: runWithIO` | ✅ `go test ./cmd/orgm-hypr -run 'TestRunWithIO'` passed | ✅ Multiple cases: version output, missing command usage, 9 placeholder groups, 3 wallpaper usage errors | ✅ `gofmt`; focused and broad Go tests passed during Slice 1 |
| 2.1 | Existing Lua/conf files + `README.md` characterization | Structural/static | ✅ `go test ./...` before Slice 2 change passed in this runtime before writing README | ✅ `test -f config/shared/.config/hypr/lua/README.md` failed before artifact existed | ✅ README written with current Lua entrypoint and fallback order | ✅ `grep` checks confirmed both Lua module order (`lua.keybindings`) and fallback tail (`90-noctalia-colors.conf`) documented | ➖ Docs-only, no behavior refactor |
| 2.2 | `config/shared/.config/hypr/lua/README.md` + `luac -p` | Static Lua syntax/docs | ✅ Existing Lua modules read and no production Lua edited | ✅ Foundation README missing before write | ✅ `test -f .../README.md` passed after write | ✅ `find config/shared/.config/hypr -name '*.lua' -print0 \| xargs -0 luac -p` passed across all Lua modules | ➖ No module tree churn needed; current modules already exist |
| 3.1 | `70-keybindings.conf`, `10-programs.conf`, `compositor-parity.md` | Structural parity | ✅ `find ... '*.lua' \| xargs luac -p` passed; ✅ `go test ./...` passed before Slice 3 edits | ✅ Grep for fallback `SUPER+ALT+Space` / `$control_center` parity failed before edit | ✅ Grep checks passed after edit; wrapper paths retained | ✅ Docs verify help/menu, launcher/file tools, scratchpad, media, window, focus/move, workspace, mouse bind domains | ➖ Minimal fallback parity edit only; no Lua churn |
| 3.2 | `55-layout.conf`, `compositor-parity.md` | Structural parity | ✅ Same Slice 3 safety net; existing Lua modules read before edits | ✅ Grep for fallback `scrolling {` and compositor parity artifact failed before edit | ✅ Grep checks passed after edit; Lua syntax and Go tests passed | ✅ Docs verify monitor, input, gestures, look, layout, window/rule domains and XWayland workaround | ➖ Minimal fallback parity edit only; no Lua churn |
| 4.1 | `internal/session/session_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ `go test ./cmd/orgm-hypr ./internal/cli ./internal/wallpaper` passed before Slice 4 edits | ✅ `go test ./internal/waybar ./internal/dock ./internal/session` failed with undefined session functions; CLI focused tests failed with `session` missing/usage | ✅ `go test ./internal/session ./cmd/orgm-hypr` passed after minimal implementation | ✅ Env import command list, docker/podman selection, native/Flatpak Discord selection, and CLI `--print` covered | ✅ `gofmt`; focused package tests passed |
| 4.2 | `internal/waybar/waybar_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ Same Slice 4 safety net | ✅ Waybar tests failed with undefined `FormatDate`, `SwapUsageFromMeminfo`, `WorkspaceStatusJSON`, `WatchPlan`; CLI tests failed with `waybar: command group not implemented yet` | ✅ `go test ./internal/waybar ./cmd/orgm-hypr` passed | ✅ Date formats, zero/non-zero swap, active/empty workspace JSON, and watch-plan config/log args covered | ✅ `gofmt`; wrappers retained; no caller migration |
| 4.3 | `internal/dock/dock_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ Same Slice 4 safety net | ✅ Dock tests failed with undefined `StartArgs`, `PlanStart`, `Env`, `StartState`; CLI tests failed with `dock: command group not implemented yet` | ✅ `go test ./internal/dock ./cmd/orgm-hypr` passed | ✅ Default args, env overrides, missing-binary notification plan, already-running no-op, and reload kill/no-exec plan covered | ✅ `gofmt`; existing `hypr-nwg-dock` script untouched |
| 5.1 | `internal/windows/windows_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ `go test ./cmd/orgm-hypr ./internal/session ./internal/waybar ./internal/dock` passed before Slice 5 edits | ✅ `go test ./internal/windows ./internal/zen ./internal/osd` failed with undefined windows functions; CLI tests failed with `windows: command group not implemented yet` | ✅ `go test ./internal/windows ./cmd/orgm-hypr -run 'TestRunWithIO(Windows)'` passed after implementation | ✅ Client label parsing, focus command construction, duplicate/small/foreign kill candidate filtering covered | ✅ `gofmt`; wrappers/scripts untouched |
| 5.2 | `internal/zen/zen_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ Same Slice 5 safety net | ✅ Zen tests failed with undefined `FocusAddressFromClients`, `OpenCommand`, `InstallState`; CLI focused test failed with `zen: command group not implemented yet` | ✅ `go test ./internal/zen ./cmd/orgm-hypr -run 'TestRunWithIO(Zen)'` passed after implementation | ✅ Best focus by `focusHistoryID`, flatpak/native/missing install command planning covered | ✅ `gofmt`; existing `hypr-zen-new-window` script untouched |
| 5.3 | `internal/osd/osd_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ Same Slice 5 safety net | ✅ OSD tests failed with undefined `PlanVolume`, `PlanMic`, `PlanBrightness`; CLI test failed because `osd` was absent from usage | ✅ `go test ./internal/osd ./cmd/orgm-hypr -run 'TestRunWithIO(OSD)'` passed after implementation | ✅ Volume up, mic mute, brightness down, and invalid usage errors covered | ✅ `gofmt`; existing OSD scripts untouched |
| 6.1 | `menu-webapp-characterization.md` | Structural/docs | ✅ `go test ./cmd/orgm-hypr ./internal/windows ./internal/zen ./internal/osd` passed before Slice 6 edits | ✅ `test -f openspec/changes/hypr-lua-orgm-hypr-migration/menu-webapp-characterization.md` failed before artifact existed | ✅ Characterization artifact written | ✅ Documents every in-scope menu wrapper with callers/items/dependencies/cancel path/retention rationale | ➖ Docs-only; no menu production code |
| 6.2 | `internal/smartrun/smartrun_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI characterization | ✅ Same Slice 6 safety net | ✅ `go test ./internal/smartrun ./cmd/orgm-hypr -run 'TestParse\|TestRunWithIOSmartRun'` failed with undefined smartrun types/functions and `smart-run: command group not implemented yet` | ✅ Focused smart-run tests passed after minimal parser/CLI implementation | ✅ Direct URL/local URL, hints/default desktop, command/domain/no-op, and CLI parse/run print cases covered | ✅ `gofmt`; live wrapper retained; no caller migration |
| 6.3 | `menu-webapp-characterization.md` | Structural/docs | ✅ Same Slice 6 safety net | ✅ Same missing-characterization artifact RED as 6.1 | ✅ Webapp maker/remover characterization written | ✅ Creation prompts/writes/network/icon flow and remover discovery/cancel/destructive deletion choices documented | ➖ Deferred by design; no destructive production code |
| 7.1 | `tasks.md`, `apply-progress.md`, `verify-report.md` | Structural/docs | ✅ Focused Go package set passed before docs edit | ✅ `verify-report.md` read failed with ENOENT before write; cleanup evidence absent | ✅ Cleanup decision recorded: no scripts removed/shrunk because caller migration and manual/nix/dot parity evidence incomplete | ✅ Retained-script/deferred domains listed by session/Waybar/dock/windows/Zen/OSD/menu/smart-run/webapp | ➖ Docs-only safety decision; no production cleanup |
| 7.2 | `verify-report.md`, `apply-progress.md` | Structural/docs | ✅ Focused Go package set and `git diff --check` passed before docs edit | ✅ `verify-report.md` missing before write | ✅ Final partial verification report written and tasks updated | ✅ Records passing focused Go tests, `go test ./...`, `git diff --check`, and blocked `nix`/`orgm-dot`/`./dot.sh` commands | ➖ Docs-only; no behavior refactor |

## Test Summary

- Total tests/checks written this phase: Slice 5 added 3 new Go package test files plus CLI tests for windows/Zen/OSD; Slice 4 added 3 new Go package test files plus CLI tests for session/Waybar/dock; prior Slice 3 added structural parity checks and `compositor-parity.md` checklist.
- Total Slice 4 production behavior changes: new `internal/session`, `internal/waybar`, and `internal/dock` packages; `orgm-hypr` command routing for `session`, `waybar`, and `dock` helper subcommands. Existing scripts remain untouched.
- Total Slice 5 production behavior changes: new `internal/windows`, `internal/zen`, and `internal/osd` packages; `orgm-hypr` command routing for safe windows list/focus, Zen focus, and OSD print-plan subcommands. Existing scripts remain untouched.
- Total Slice 6 production behavior changes: new `internal/smartrun` package; `orgm-hypr smart-run parse` and `smart-run run --print` print parser plans only. Existing menu/webapp/smart-run scripts remain untouched.
- Layers used: unit/CLI characterization, structural/static, and Lua syntax validation.
- Approval tests: current session autostart snippets, Waybar helper scripts, workspace JSON shape, dock wrapper args, windows labels/focus dispatch, Zen focus/open planning, and OSD command/notify shapes captured in Go tests.
- Pure functions created: `session.ImportEnvCommands`, `session.ContainerStartCommand`, `session.DiscordCommand`, `waybar.FormatDate`, `waybar.SwapUsageFromMeminfo`, `waybar.WorkspaceStatusJSON`, `waybar.WatchPlan`, `dock.StartArgs`, `dock.PlanStart`, `windows.ClientRowsFromJSON`, `windows.FocusCommand`, `windows.KillCandidatesFromJSON`, `zen.FocusAddressFromClients`, `zen.OpenCommand`, `osd.PlanVolume`, `osd.PlanMic`, `osd.PlanBrightness`, `smartrun.Parse`.

## Verification commands run

| Command | Result | Notes |
|---|---|---|
| `find config/shared/.config/hypr -name '*.lua' -print0 \| xargs -0 luac -p` before Slice 3 edits | PASS | Safety net for Lua modules. |
| `go test ./...` before Slice 3 edits | PASS | Safety net in current runtime despite concurrent project changes. |
| `grep -F 'bind = $mainMod ALT, Space, exec, $control_center' config/shared/.config/hypr/70-keybindings.conf` before edit | FAIL expected | RED for keybinding fallback parity. |
| `grep -F '$control_center = ~/.local/bin/hypr-main-menu' config/shared/.config/hypr/10-programs.conf` before edit | FAIL expected | RED for program fallback parity. |
| `grep -F 'scrolling {' config/shared/.config/hypr/55-layout.conf` before edit | FAIL expected | RED for layout fallback parity. |
| `test -f openspec/changes/hypr-lua-orgm-hypr-migration/compositor-parity.md` before write | FAIL expected | RED for Slice 3 parity checklist. |
| Grep checks for fallback bind/program/scrolling and parity doc content after edits | PASS | GREEN/TRIANGULATE structural checks. |
| `find config/shared/.config/hypr -name '*.lua' -print0 \| xargs -0 luac -p` after edits | PASS | Lua syntax unchanged and valid. |
| `go test ./...` after edits | PASS then FAIL on final rerun | Initially passed after Slice 3 edits. Final rerun failed in unrelated concurrent theme work: `internal/theme/plan.go` references undefined `renderHypr`, `renderWaybar`, `renderNWGDock`, `renderGTK`, `renderQt`. Slice 3 did not touch `internal/theme`. |
| `git diff --check` | PASS | Whitespace check fallback. |
| `go test ./cmd/orgm-hypr ./internal/cli ./internal/wallpaper` before Slice 4 edits | PASS | Safety net before modifying `cmd/orgm-hypr/main.go` and adding domain packages. |
| `go test ./internal/waybar ./internal/dock ./internal/session` after writing RED tests | FAIL expected | Undefined functions/types for all three new packages. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(Waybar\|Session\|Dock)'` after writing CLI RED tests | FAIL expected | `waybar`/`dock` not implemented and `session` missing from usage. |
| `go test ./internal/waybar ./internal/dock ./internal/session` after GREEN | PASS | New pure characterization helpers pass. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(Waybar\|Session\|Dock)'` after GREEN | PASS | New CLI helper commands pass. |
| `go test ./internal/waybar ./internal/dock ./internal/session ./cmd/orgm-hypr` | PASS | Focused Slice 4 package set. |
| `go test ./...` after Slice 4 | PASS | Full Go suite passed in current runtime with concurrent project changes present. |
| `git diff --check` after Slice 4 | PASS | Whitespace check fallback. |
| `nix flake check` | BLOCKED | `/bin/bash: line 1: nix: command not found`. |
| `orgm-dot diff --host orgm` | BLOCKED | `/bin/bash: line 1: orgm-dot: command not found`. |
| `./dot.sh diff --host orgm` | BLOCKED | `/bin/bash: line 1: ./dot.sh: No such file or directory`. |
| `dot.sh diff --host orgm` | BLOCKED | `/home/osmarg/.local/bin/dot.sh: line 2: /home/osmarg/Hobby/dotfiles/dot.sh: No such file or directory`. |
| `go test ./cmd/orgm-hypr ./internal/session ./internal/waybar ./internal/dock` before Slice 5 edits | PASS | Safety net before modifying `cmd/orgm-hypr/main.go` and adding new domain packages. |
| `go test ./internal/windows ./internal/zen ./internal/osd` after writing RED tests | FAIL expected | Undefined functions/types for all three new packages. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(Windows\|Zen\|OSD)'` after writing CLI RED tests | FAIL expected | `windows`/`zen` not implemented and `osd` absent from usage. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(Windows\|Zen\|OSD)' && go test ./internal/windows ./internal/zen ./internal/osd` after GREEN | PASS | New CLI and pure helper tests pass. |
| `go test ./internal/windows ./internal/zen ./internal/osd ./cmd/orgm-hypr` | PASS | Focused Slice 5 package set. |
| `go test ./...` after Slice 5 | PASS | Full Go suite passed in current runtime with concurrent project changes present. |
| `git diff --check` after Slice 5 | PASS | Whitespace check fallback. |
| `nix flake check` after Slice 5 | BLOCKED | `/bin/bash: line 1: nix: command not found`. |
| `orgm-dot diff --host orgm` after Slice 5 | BLOCKED | `/bin/bash: line 1: orgm-dot: command not found`. |
| `./dot.sh diff --host orgm` after Slice 5 | BLOCKED | `/bin/bash: line 1: ./dot.sh: No such file or directory`. |
| `go test ./cmd/orgm-hypr ./internal/windows ./internal/zen ./internal/osd` before Slice 6 edits | PASS | Safety net before modifying `cmd/orgm-hypr/main.go` and adding smart-run package. |
| `test -f openspec/changes/hypr-lua-orgm-hypr-migration/menu-webapp-characterization.md` before write | FAIL expected | RED for Slice 6 menu/webapp characterization artifact. |
| `go test ./internal/smartrun ./cmd/orgm-hypr -run 'TestParse\|TestRunWithIOSmartRun'` after writing RED tests | FAIL expected | Undefined smartrun functions/types and `smart-run` still placeholder. |
| `go test ./internal/smartrun ./cmd/orgm-hypr -run 'TestParse\|TestRunWithIOSmartRun'` after GREEN | PASS | Smart-run parser and print-safe CLI passed focused tests. |
| `go test ./internal/smartrun ./cmd/orgm-hypr` after Slice 6 | PASS | Focused Slice 6 package set. |
| `go test ./...` after Slice 6 | PASS | Full Go suite passed in current runtime with concurrent project changes present. |
| `git diff --check` after Slice 6 | PASS | Whitespace check fallback. |
| `nix flake check` after Slice 6 | BLOCKED | `/bin/bash: line 1: nix: command not found`. |
| `orgm-dot diff --host orgm` after Slice 6 | BLOCKED | `/bin/bash: line 1: orgm-dot: command not found`. |
| `./dot.sh diff --host orgm` after Slice 6 | BLOCKED | `/bin/bash: line 1: ./dot.sh: No such file or directory`. |
| `go test ./cmd/orgm-hypr ./internal/session ./internal/waybar ./internal/dock ./internal/windows ./internal/zen ./internal/osd ./internal/smartrun` before Slice 7 docs edit | PASS | Focused safe verification across all SDD-owned Go packages. |
| `command -v nix` before Slice 7 docs edit | BLOCKED | No output; `nix` unavailable in current runtime. |
| `command -v orgm-dot` before Slice 7 docs edit | BLOCKED | No output; `orgm-dot` unavailable in current runtime. |
| `command -v ./dot.sh` before Slice 7 docs edit | BLOCKED | No project-local `./dot.sh` executable/path in repo root. |
| `command -v dot.sh` before Slice 7 docs edit | FOUND | `/home/osmarg/.local/bin/dot.sh`, but it delegates to missing `/home/osmarg/Hobby/dotfiles/dot.sh`. |
| `git diff --check` before Slice 7 docs edit | PASS | No whitespace errors. |
| `go test ./...` after Slice 7 verification | PASS | Full Go suite passed in current runtime with concurrent project changes present. |
| `nix flake check` after Slice 7 verification | BLOCKED | `/bin/bash: line 1: nix: command not found`. |
| `orgm-dot diff --host orgm` after Slice 7 verification | BLOCKED | `/bin/bash: line 1: orgm-dot: command not found`. |
| `./dot.sh diff --host orgm` after Slice 7 verification | BLOCKED | `/bin/bash: line 1: ./dot.sh: No such file or directory`. |
| `dot.sh diff --host orgm` after Slice 7 verification | BLOCKED | `/home/osmarg/.local/bin/dot.sh: line 2: /home/osmarg/Hobby/dotfiles/dot.sh: No such file or directory`. |

## Deviations from design

- No Lua module tree reorganization was done. Current `hyprland.lua` and `lua/*.lua` modules already exist and are deterministic, so Slices 2-3 used low-churn documentation and fallback parity edits instead of loader/module churn.
- Manual Hyprland reload/load was not attempted; runtime validation remains blocked/deferred to host verification.
- `nix flake check`, `orgm-dot diff`, and dot wrapper verification remain blocked by unavailable/broken local tooling.
- No script deletion, caller switching, cleanup, or manifest edit by this SDD slice.
- Slice 4 implements safe helper subcommands and pure typed decisions only. It does not switch `waybar-watch`, `hypr-workspace-button`, date/swap scripts, autostart shell snippets, or `hypr-nwg-dock` wrapper to Go yet.
- Slice 5 implements pure typed decision/planning and print-safe CLI only where hardware/GUI/runtime behavior would otherwise be risky. It does not switch `fuzzel-hypr-window`, `hypr-kill-windows`, `walker-window-switch.sh`, `hypr-zen-new-window`, `volume-osd`, `mic-volume-osd`, or `brightness-osd` to Go yet.
- Slice 6 keeps menu wrappers as scripts and webapp maker/remover deferred. Only smart-run parser/print-safe planning moved to Go; live GUI/browser/app execution remains with `hypr-smart-run`.

## Remaining tasks

- No assigned Slice 7 implementation tasks remain.
- Slice 4 live caller migration remains deferred: existing autostart and PATH wrappers still provide runtime behavior until manual parity is verified.
- Slice 5 live caller migration remains deferred: existing windows/Zen/OSD wrappers still provide runtime behavior until manual parity is verified.
- Slice 6 live caller migration remains deferred: existing menu, smart-run, and webapp wrappers still provide runtime behavior until manual parity/destructive-flow tests are verified.
- Script cleanup remains deferred for all in-scope wrappers because replacement + caller migration + parity evidence is incomplete.
- Re-run `nix flake check`, `nix fmt`, Nix builds, `orgm-dot diff --host orgm`, and `./dot.sh diff --host orgm` from environment where `nix`, `orgm-dot`, and working project dot wrapper are available.
- Run manual Hyprland reload/session startup/Waybar/dock/windows/Zen/OSD/menu/smart-run/webapp parity checklist on compatible host runtime.

## Risks / observations

- Unrelated concurrent work remains present: `openspec/changes/orgm-hypr-theme-system/`, `config/shared/.config/orgm-hypr/`, `internal/theme/`, `config/dotfiles.json`, and theme-related files. Slice 4/5 did not intentionally edit those areas.
- Earlier Slice 3 final rerun had reported unrelated concurrent theme compile errors in `internal/theme/plan.go`; after concurrent work progressed, Slice 4 and Slice 5 `go test ./...` passed in this runtime.
- Slice 5 observed unrelated concurrent tracked/untracked project changes still present outside this slice, including `config/dotfiles.json`, Waybar/theme files, `internal/theme/`, `openspec/changes/orgm-hypr-theme-system/`, and other prior SDD slice artifacts.
- Memory/Engram tool unavailable in this executor; discoveries recorded here only.

## Slice 8 progress: command surface normalization and wrapper migration

### Workload / PR boundary

- Delivery path: auto-chain / continuation Slice 8 only.
- PR boundary: command-surface audit, safe Go command surface additions, and safest thin wrapper conversions. Complex menus, smart-run live mode, webapp, OSD live hardware wrappers, and destructive window/session helpers remain deferred to Slice 9/10.

### Completed tasks

- [x] 8.1 Refreshed command-surface audit in `wrapper-migration-audit.md` against current wrappers/callers.
- [x] 8.2 Added RED CLI contract tests for missing safe command names:
  - `orgm-hypr waybar workspace status|click`
  - `orgm-hypr dock start reload --print-args` compatibility alias
  - `orgm-hypr zen open-new-window --print`
  - `orgm-hypr wallpaper current`
- [x] 8.3 Implemented safe command surfaces:
  - `waybar workspace status|click` with file-backed test flags and live `hyprctl -j monitors/workspaces` fallback.
  - `dock start reload|restart` positional compatibility aliases.
  - `zen open-new-window --print` plus live install selection/launch path using existing Zen planner and focus helper.
  - `wallpaper current` compatibility symlink generation/print path.
- [x] 8.4 Converted safest wrappers to no-logic `exec orgm-hypr ... "$@"` wrappers:
  - `waybar-date-es`
  - `waybar-day-month-es`
  - `waybar-time-ampm`
  - `waybar-swap-usage`
  - `hypr-workspace-button`
  - `hypr-nwg-dock`
  - `hypr-zen-new-window`
  - `hypr-current-wallpaper`
  - `hypr-random-wallpaper` was already thin and left unchanged.
- [x] 8.5 Evaluated window/session helper wrapper conversion. No destructive/interactively prompted window/session helper was converted in Slice 8 because cancellation/destructive paths are not fully migrated/tested. Deferrals recorded in `wrapper-migration-audit.md`.

### Files changed in Slice 8

- `cmd/orgm-hypr/main.go` — added `waybar workspace`, dock positional reload aliases, `zen open-new-window`, and `wallpaper current` command routing/helpers.
- `cmd/orgm-hypr/main_test.go` — added CLI contract tests and updated wallpaper usage expectation.
- `internal/wallpaper/manager.go` — added `CompatibilityCurrent` symlink helper used by `wallpaper current`.
- `config/shared/.local/bin/waybar-date-es` — thin exec wrapper.
- `config/shared/.local/bin/waybar-day-month-es` — thin exec wrapper.
- `config/shared/.local/bin/waybar-time-ampm` — thin exec wrapper.
- `config/shared/.local/bin/waybar-swap-usage` — thin exec wrapper.
- `config/shared/.local/bin/hypr-workspace-button` — thin exec wrapper.
- `config/shared/.local/bin/hypr-nwg-dock` — thin exec wrapper.
- `config/shared/.local/bin/hypr-zen-new-window` — thin exec wrapper.
- `config/shared/.local/bin/hypr-current-wallpaper` — thin exec wrapper.
- `openspec/changes/hypr-lua-orgm-hypr-migration/wrapper-migration-audit.md` — refreshed wrapper/caller/canonical command audit.
- `openspec/changes/hypr-lua-orgm-hypr-migration/continuation-tasks.md` — Slice 8 checkboxes marked complete/evaluated.
- `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md` — this progress entry.

### TDD Cycle Evidence

| Task | Test File / Check | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-------------------|-------|------------|-----|-------|-------------|----------|
| 8.1 | `wrapper-migration-audit.md` | Structural/docs | Existing inventory/progress/verify/menu characterization read first | ✅ Audit artifact absent/stale before write | ✅ Audit written with wrapper/caller/canonical command map | ✅ Includes converted and deferred domains with rollback | ➖ Docs-only |
| 8.2 | `cmd/orgm-hypr/main_test.go` | CLI/unit | ✅ `go test ./cmd/orgm-hypr ./internal/waybar ./internal/dock ./internal/zen ./internal/osd ./internal/wallpaper` passed before edits | ✅ Focused CLI tests failed for missing dock alias, waybar workspace, zen open-new-window, wallpaper current | ✅ Focused tests passed after implementation | ✅ Added multiple behaviors: workspace status via direct flags and Hypr JSON files, click print, dock reload alias, Zen print, wallpaper symlink | ✅ `gofmt`; focused tests passed |
| 8.3 | `cmd/orgm-hypr/main_test.go`, `internal/wallpaper/manager.go` | CLI/unit | ✅ Same Slice 8 safety net | ✅ Same RED failures showed missing safe command surfaces | ✅ `go test ./cmd/orgm-hypr -run 'TestRunWithIO(DockStartAccepts|WaybarWorkspace|ZenOpenNewWindow|WallpaperCurrent)'` passed | ✅ Workspace status tested both override and JSON parsing paths; wallpaper current tests symlink side effect | ✅ `gofmt`; broad focused package tests passed |
| 8.4 | Wrapper static grep | Static/script compatibility | ✅ Go command parity tests passed before wrapper conversion | ✅ Prior wrappers contained behavior-owning shell bodies instead of direct `exec orgm-hypr` | ✅ Static loop confirmed each converted wrapper contains `exec orgm-hypr` | ✅ Nine wrappers checked, including already-thin `hypr-random-wallpaper` | ➖ No refactor beyond replacing shell bodies with thin wrappers |
| 8.5 | `wrapper-migration-audit.md` | Safety decision/docs | ✅ Existing windows/session tests and characterization read | ✅ Destructive/interactive helper conversion lacked fully tested cancellation/destructive paths | ✅ Deferred in audit instead of unsafe conversion | ✅ Explicit deferrals for OSD live, window switch/kill, menus, smart-run live, webapp | ➖ Docs-only safety gate |

### Verification commands run in Slice 8

| Command | Result | Notes |
|---|---|---|
| `go test ./cmd/orgm-hypr ./internal/waybar ./internal/dock ./internal/zen ./internal/osd ./internal/wallpaper` before edits | PASS | Safety net before Go/wrapper changes. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(DockStartAccepts\|WaybarWorkspace\|ZenOpenNewWindow\|WallpaperCurrent)'` after RED tests | FAIL expected | Missing dock alias, waybar workspace, Zen open-new-window, wallpaper current. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIOWaybarWorkspaceStatusReadsHyprctlJSONFiles'` after triangulation test | FAIL expected | `flag provided but not defined: -monitors`. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(DockStartAccepts\|WaybarWorkspace\|ZenOpenNewWindow\|WallpaperCurrent)'` after GREEN | PASS | New safe CLI command surfaces passed. |
| `go test ./cmd/orgm-hypr ./internal/waybar ./internal/dock ./internal/zen ./internal/wallpaper` | PASS | Focused Slice 8 package set. |
| `go test ./...` | PASS | Full Go suite passed with concurrent project changes present. |
| `git diff --check` | PASS | No whitespace errors. |
| Wrapper static loop over converted wrappers checking `^exec orgm-hypr ` | PASS | All converted wrappers plus already-thin `hypr-random-wallpaper` passed. |
| `nix flake check` | BLOCKED | `/bin/bash: line 1: nix: command not found`. |
| `orgm-dot diff --host orgm` | BLOCKED | `/bin/bash: line 1: orgm-dot: command not found`. |
| `./dot.sh diff --host orgm` | BLOCKED | `/bin/bash: line 1: ./dot.sh: No such file or directory`. |
| `dot.sh diff --host orgm` | BLOCKED | `/home/osmarg/.local/bin/dot.sh: line 2: /home/osmarg/Hobby/dotfiles/dot.sh: No such file or directory`. |

### Deviations / deferrals

- OSD wrappers were not converted because `orgm-hypr osd` remains print-only and live hardware/query/notify behavior is not safely implemented in Slice 8.
- `fuzzel-hypr-window`, `hypr-kill-windows`, and `walker-window-switch.sh` were not converted because prompt cancellation/destructive kill flows need Slice 9/10 tests.
- Menu wrappers, smart-run live wrapper, and webapp maker/remover remain behavior-owning scripts pending Slice 9 tests and destructive/file-write safety gates.
- Repo-owned callers still use compatibility wrapper names; caller migration is reserved for Slice 10 after wrapper parity evidence.
- `nix`, `orgm-dot`, and project-local `./dot.sh` verification remain blocked in this runtime.

### Remaining tasks after Slice 8

- Slice 9: interactive menu/webapp migration, smart-run live mode, and destructive/file-write safety tests.
- Slice 10: caller migration to direct `orgm-hypr ...` commands, wrapper keep/remove audit, and final cleanup verification.

## Slice 9 progress: interactive menu/webapp migration

### Workload / PR boundary

- Delivery path: auto-chain / continuation Slice 9 only.
- PR boundary: menu/smart-run/webapp command ownership plus safe wrapper conversions. Webapp maker/remover wrappers remain behavior-owning and deferred because no-arg interactive prompt parity is not implemented in Go.

### Completed tasks

- [x] 9.1 Added RED characterization tests for menu models/actions in `internal/menu/menu_test.go` and CLI menu tests.
- [x] 9.2 Implemented `orgm-hypr menu main|system|tools|performance|wifi|bluetooth|keyboard|power|keybindings` with pure model/action planning, rofi execution boundary, `--print`, `--select`, and destructive `--confirm` gates.
- [x] 9.3 Converted menu wrappers to thin exec wrappers: `hypr-main-menu`, `hypr-system-menu`, `hypr-tools-menu`, `hypr-performance-menu`, `hypr-wifi-menu`, `hypr-bluetooth-menu`, `hypr-keyboard-menu`, `hypr-power-menu`, `hypr-keybindings-help`.
- [x] 9.4 Expanded `orgm-hypr smart-run run` to live execution planning/execution, with `--print` parser plan and `--print-exec` command plan; converted `hypr-smart-run` to thin wrapper.
- [x] 9.5 Implemented `orgm-hypr webapp list|create|remove` with dry-run/list/fake filesystem tests and profile deletion confirmation gate. Maker/remover wrappers kept deferred.

### Files changed in Slice 9

- `cmd/orgm-hypr/main.go` — added menu, webapp, and smart-run execution command routing/helpers.
- `cmd/orgm-hypr/main_test.go` — added CLI tests for menu selected actions/destructive gates, webapp dry-run/list, and smart-run execution print plan.
- `internal/menu/menu.go` / `internal/menu/menu_test.go` — new pure menu data/action model and keybinding category data.
- `internal/webapp/webapp.go` / `internal/webapp/webapp_test.go` — new webapp slug/url/create/list/remove planning with destructive profile gate.
- `internal/smartrun/smartrun.go` / `internal/smartrun/smartrun_test.go` — added execution planning for browser, desktop, clipboard, and command actions.
- Menu wrappers and smart-run wrapper under `config/shared/.local/bin/` — converted to thin `exec orgm-hypr ...` delegators.
- `openspec/changes/hypr-lua-orgm-hypr-migration/continuation-tasks.md` — marked Slice 9 complete/evaluated.
- `openspec/changes/hypr-lua-orgm-hypr-migration/wrapper-migration-audit.md` — updated converted/deferred wrapper evidence.
- `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md` — this entry.

### TDD Cycle Evidence

| Task | Test File / Check | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-------------------|-------|------------|-----|-------|-------------|----------|
| 9.1 | `internal/menu/menu_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI | ✅ `go test ./cmd/orgm-hypr ./internal/smartrun` passed before Slice 9 edits | ✅ `go test ./internal/menu ./internal/webapp ./internal/smartrun` failed with undefined `menu` symbols; CLI menu tests failed with `menu: command group not implemented yet` | ✅ `go test ./internal/menu ./cmd/orgm-hypr -run 'TestRunWithIOMenu'` passed after implementation | ✅ Main labels, submenu dispatch, keyboard action, destructive power gate, and keybinding categories covered | ✅ `gofmt`; focused menu/CLI tests passed |
| 9.2 | `internal/menu/menu_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI | ✅ Same Slice 9 safety net | ✅ Tests referenced missing `Model`, `PlanSelection`, `KeybindingEntries`, and CLI menu routing | ✅ Focused menu package and CLI tests passed | ✅ Print/no-op selected actions plus destructive live confirmation path covered | ✅ Pure menu model separated from rofi execution |
| 9.3 | Wrapper static grep | Static/script compatibility | ✅ Menu/CLI tests passed before wrapper conversion | ✅ Previous menu wrappers contained rofi/case shell behavior | ✅ Static wrapper loop confirmed `exec orgm-hypr` for converted menu wrappers | ✅ Nine menu/keybinding wrappers checked | ➖ Wrapper replacement only |
| 9.4 | `internal/smartrun/smartrun_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI | ✅ Existing smart-run parser tests passed before edit | ✅ Tests failed with undefined `ExecutionPlan`, `BuildExecutionPlan`, and missing `--print-exec` | ✅ `go test ./internal/smartrun ./cmd/orgm-hypr -run 'TestExecutionPlan|TestRunWithIOSmartRun'` passed | ✅ Browser URL, desktop copy/launch, direct command, and CLI browser print-exec paths covered | ✅ Execution planning kept pure; live command runner isolated |
| 9.5 | `internal/webapp/webapp_test.go`, `cmd/orgm-hypr/main_test.go` | Unit/CLI fake filesystem | ✅ Same Slice 9 safety net | ✅ Webapp tests failed with undefined `CreatePlan`, `List`, `RemovePlan`; CLI tests failed with `webapp: command group not implemented yet` | ✅ Focused webapp package and CLI tests passed | ✅ Create plan, list discovery, dry-run no write, and profile delete confirmation paths covered | ✅ Webapp planner separated from filesystem writes/deletes |

### Verification commands run in Slice 9

| Command | Result | Notes |
|---|---|---|
| `go test ./cmd/orgm-hypr ./internal/smartrun` before edits | PASS | Safety net before menu/webapp/smart-run changes. |
| `go test ./internal/menu ./internal/webapp ./internal/smartrun` after RED tests | FAIL expected | Undefined new menu/webapp/smart-run execution symbols. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(Menu|Webapp|SmartRunLive|CurrentPlaceholder)'` after CLI RED tests | FAIL expected | Missing menu/webapp routing and smart-run `--print-exec`. |
| `go test ./internal/menu ./internal/webapp ./internal/smartrun` after GREEN | PASS | Pure menu, webapp, and smart-run execution planner tests passed. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(Menu|Webapp|SmartRunLive|CurrentPlaceholder)'` after GREEN | PASS | New CLI command surfaces passed. |
| Static grep loop over converted menu/smart-run wrappers checking `^exec orgm-hypr ` | PASS | Converted wrappers contain direct exec delegation. |
| `go test ./...` | PASS | Full Go suite passed with concurrent project changes present. |
| `go test ./internal/menu ./internal/webapp ./internal/smartrun ./cmd/orgm-hypr` | PASS | Focused Slice 9 package set. |
| `git diff --check` | PASS | No whitespace errors. |
| `nix flake check` | BLOCKED | Runtime requirement says nix is blocked/unavailable in this executor. |
| `orgm-dot diff --host orgm` | BLOCKED | Runtime requirement says orgm-dot is blocked/unavailable in this executor. |
| `./dot.sh diff --host orgm` | BLOCKED | Runtime requirement says project dot wrapper is blocked/unavailable in this executor. |

### Deviations / deferrals

- Webapp maker/remover wrappers were not converted. Go now owns dry-run/list/create/remove planning and live non-interactive file writes/deletes, but existing wrappers still provide no-arg rofi prompts. Converting them would break current interactive UX; defer until Slice 10 or follow-up adds `orgm-hypr webapp create/remove` interactive prompt parity.
- `hypr-keybindings-help` is now thin to `orgm-hypr menu keybindings`; this exposes keybinding data through `orgm-hypr`, but old interactive category/copy loop parity needs manual review in Slice 10.
- `hypr-performance-menu` dynamic `command -v` filtering was replaced by static Go model. This removes shell ownership but needs Slice 10 manual parity check on host PATH.
- Menu rofi theme/scaling details moved out of shell wrappers and are not fully reimplemented; live smoke is deferred by runtime constraints.
- `nix`, `orgm-dot`, and project-local `./dot.sh` verification remain blocked in this runtime.

### Remaining tasks after Slice 9

- Slice 10 caller migration to direct canonical `orgm-hypr ...` commands.
- Slice 10 wrapper keep/remove audit, especially webapp maker/remover, OSD wrappers, window prompt wrappers, and keybinding/menu parity notes.
- Manual Hyprland/menu/smart-run/webapp smoke tests in host runtime.

## Slice 10 progress: caller migration and cleanup verification

### Workload / PR boundary

- Delivery path: auto-chain / continuation Slice 10 only.
- PR boundary: caller migration to canonical `orgm-hypr ...` commands, thin-wrapper conversion for remaining safe domains, audit/docs/partial verification. No wrapper removal or manifest cleanup was performed because external compatibility and manual host parity are not fully proven.

### Completed tasks

- [x] 10.1 Updated Hypr Lua and hyprlang fallback callers to canonical `orgm-hypr` command names where safe.
- [x] 10.2 Audited wrappers for keep/remove/defer decisions in `wrapper-migration-audit.md`.
- [x] 10.3 Ran cleanup gate: no removals; converted safe wrappers to thin exec; deferred exact exceptions.
- [x] 10.4 Updated final continuation verification report.

### Files changed in Slice 10

- `cmd/orgm-hypr/main.go` — added live/print command surfaces for `waybar watch`, `session start-containers`, `session start-discord`, `windows switch`, `windows kill-menu`, and live OSD execution.
- `cmd/orgm-hypr/main_test.go` — added RED/GREEN CLI tests for Slice 10 command surfaces.
- `config/shared/.config/hypr/lua/programs.lua` — canonical menu/smart-run/power command names.
- `config/shared/.config/hypr/lua/keybindings.lua` — canonical Zen, smart-run, menu, OSD, and window commands.
- `config/shared/.config/hypr/lua/autostart.lua` — canonical session/Waybar/dock autostart commands.
- `config/shared/.config/hypr/10-programs.conf`, `20-autostart.conf`, `70-keybindings.conf` — hyprlang fallback caller migration.
- `config/shared/.config/waybar/config`, `config/shared/.config/waybar-hypr/config` — Waybar module/menu caller migration to `orgm-hypr`.
- `config/shared/.local/bin/waybar-watch`, `volume-osd`, `mic-volume-osd`, `brightness-osd`, `fuzzel-hypr-window`, `hypr-kill-windows`, `config/shared/.config/hypr/scripts/walker-window-switch.sh` — converted to thin exec wrappers.
- `config/shared/.config/hypr/lua/README.md` — updated caller/wrapper contract.
- `openspec/changes/hypr-lua-orgm-hypr-migration/continuation-tasks.md` — Slice 10 tasks marked complete.
- `openspec/changes/hypr-lua-orgm-hypr-migration/wrapper-migration-audit.md` — final wrapper/caller status and exceptions.
- `openspec/changes/hypr-lua-orgm-hypr-migration/verify-report.md` — Slice 10 verification addendum.
- `openspec/changes/hypr-lua-orgm-hypr-migration/apply-progress.md` — this entry.

### Callers migrated

- Hypr Lua and fallback config now call `orgm-hypr menu main|power|keybindings`, `orgm-hypr smart-run run`, `orgm-hypr zen open-new-window`, `orgm-hypr windows switch|kill-menu`, `orgm-hypr osd volume|mic|brightness`, `orgm-hypr session import-env|start-containers|start-discord`, `orgm-hypr waybar watch`, and `orgm-hypr dock start` for migrated domains.
- Waybar configs now call `orgm-hypr waybar date|swap-usage|workspace` and `orgm-hypr menu ...` directly instead of compatibility wrappers.

### Wrappers converted / deferred

- Converted in Slice 10: `waybar-watch`, `volume-osd`, `mic-volume-osd`, `brightness-osd`, `fuzzel-hypr-window`, `hypr-kill-windows`, `walker-window-switch.sh`.
- Kept as thin compatibility wrappers from earlier slices: Waybar tiny helpers, workspace button, dock, Zen, wallpaper, menu wrappers, and smart-run wrapper.
- Deferred behavior-owning exceptions: `hypr-webapp-maker`, `hypr-webapp-remover` (no-arg interactive rofi UX not implemented in Go).
- Out-of-scope behavior-owning utilities: `hypr-fuzzel`, `hypr-lock`, `hypr-focus-notification-app`, `fuzzel-open-file*`, `fuzzel-ssh-host`, `fuzzel-tmux-arch`, `fuzzel-calc`, `pi-walker-prompt.sh`, and non-Hypr `sway/config` `waybar-watch` caller.

### TDD Cycle Evidence

| Task | Test File / Check | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-------------------|-------|------------|-----|-------|-------------|----------|
| 10.1 | `cmd/orgm-hypr/main_test.go`; Lua/conf static grep | CLI/static | ✅ `go test ./cmd/orgm-hypr ./internal/osd ./internal/windows ./internal/webapp ./internal/waybar ./internal/session` passed before edits | ✅ Tests failed for missing `waybar watch`, session start commands, `windows switch`, `windows kill-menu`, and live OSD | ✅ Focused Slice 10 CLI tests passed after implementation | ✅ Covered print and live-planning paths: Waybar watch print, docker/Flatpak session print, selected window focus, selected kill PID, fake-bin OSD action/query/notify | ✅ `gofmt`; Lua callers migrated with syntax check passing |
| 10.2 | `wrapper-migration-audit.md`; static wrapper loop | Docs/static | ✅ Existing audit and wrappers read before conversion | ✅ Static loop showed remaining behavior-owning OSD/window/Waybar wrappers | ✅ Converted wrappers checked for `^exec orgm-hypr ` | ✅ Audit records converted, deferred, and out-of-scope wrappers with exact command/blocker | ➖ Docs/wrapper cleanup only |
| 10.3 | Wrapper files + caller grep | Static/script compatibility | ✅ Focused Go tests passed before wrapper conversion | ✅ Previous wrappers owned shell behavior | ✅ Static wrapper grep passed after conversion; no migrated wrapper callers remain in Hypr/Waybar configs | ✅ Includes OSD, fuzzel window switch, kill menu, Walker switch, Waybar watch | ➖ No removals because compatibility/manual parity gate incomplete |
| 10.4 | `verify-report.md`, `apply-progress.md` | Docs/verification | ✅ `go test ./...` and `git diff --check` run before final report | ✅ Verification addendum absent before docs update | ✅ Report records PASS/BLOCKED evidence and remaining exceptions | ✅ Records blocked nix/orgm-dot/dot.sh and manual smoke requirements | ➖ Docs-only |

### Verification commands run in Slice 10

| Command | Result | Notes |
|---|---|---|
| `go test ./cmd/orgm-hypr ./internal/osd ./internal/windows ./internal/webapp ./internal/waybar ./internal/session` before edits | PASS | Safety net before Slice 10 changes. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIO(WindowsSwitch|WindowsKillMenu|OSDVolumeLive)'` after RED tests | FAIL expected | Missing windows interactive subcommands and live OSD. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIOSessionStart'` after RED tests | FAIL expected | Session start commands still deferred. |
| `go test ./cmd/orgm-hypr -run 'TestRunWithIOWaybarWatch'` after RED test | FAIL expected | `waybar watch` missing. |
| Focused Slice 10 CLI tests after GREEN | PASS | New command surfaces passed. |
| `go test ./cmd/orgm-hypr ./internal/osd ./internal/windows ./internal/webapp ./internal/waybar ./internal/session` | PASS | Focused package set passed. |
| `find config/shared/.config/hypr -name '*.lua' -print0 \| xargs -0 luac -p` | PASS | Lua syntax valid. |
| Static wrapper grep for converted Slice 10 wrappers | PASS | All converted wrappers exec `orgm-hypr`. |
| `go test ./...` | PASS | Full Go suite passed. |
| `git diff --check` | PASS | No whitespace errors. |
| `nix flake check` | BLOCKED | `/bin/bash: line 1: nix: command not found`. |
| `orgm-dot diff --host orgm` | BLOCKED | `/bin/bash: line 1: orgm-dot: command not found`. |
| `./dot.sh diff --host orgm` | BLOCKED | `/bin/bash: line 1: ./dot.sh: No such file or directory`. |

### Deviations / blockers

- No wrappers were removed from the manifest; compatibility wrappers remain because external callers and manual host parity are not fully proven.
- Webapp maker/remover wrappers remain behavior-owning because converting them would break current no-arg interactive rofi prompt flow. Required follow-up: `orgm-hypr webapp create/remove --interactive` or equivalent prompt flags.
- Generic fuzzel/file/tmux/calc/Pi/lock/notification helpers remain out of scope for this SDD change; exact exceptions are listed in `wrapper-migration-audit.md`.
- `nix`, `orgm-dot`, and project-local `./dot.sh` remain blocked in this runtime; no `orgm-dot sync` was run.

## Final exception closure progress: Slices 11-13

### Workload / PR boundary

- Delivery path: user explicitly requested continuing all listed remaining exceptions; treated as final auto-chain exception closure.
- PR boundary: Slices 11-13 close former exception wrappers/caller only; no dotfile sync or destructive runtime commands executed.

### Completed tasks

- [x] 11.1 Final exception audit refreshed in `wrapper-migration-audit.md`.
- [x] 11.2 RED CLI contract tests added in `cmd/orgm-hypr/final_exception_test.go`.
- [x] 11.3 Wrapper behavior model tests covered at CLI/plan layer for lock, launcher, notify, file, SSH, tmux, calc, Pi, and webapp cancellation.
- [x] 12.1 `webapp create/remove --interactive` command surface added with safe cancellation path; wrappers converted thin.
- [x] 12.2 `launcher apps`, `session lock`, and `notify focus-app` command surfaces added; wrappers converted thin.
- [x] 12.3 `file open|open-dir|open-terminal`, `ssh host`, `tmux arch`, `calc fuzzel`, and `pi prompt` command surfaces added; wrappers converted thin.
- [x] 12.4 Shared command runner/picker helpers reused; no larger refactor beyond safe helper additions.
- [x] 13.1 Sway `waybar-watch` caller migrated to `orgm-hypr waybar watch ~/.config/waybar`.
- [x] 13.2 Final audit/evidence updated.
- [x] 13.3 Partial final validation run; blocked validators recorded.

### Files changed in final closure

- `cmd/orgm-hypr/main.go` — added final exception command surfaces: `launcher/fuzzel apps`, `session lock`, `notify focus-app`, `file`, `ssh`, `tmux`, `calc`, `pi`, and webapp interactive cancel gates.
- `cmd/orgm-hypr/final_exception_test.go` — new RED/GREEN CLI contract tests.
- `cmd/orgm-hypr/main_test.go` — `notify` removed from placeholder group after implementation.
- `config/shared/.local/bin/hypr-webapp-maker`, `hypr-webapp-remover`, `hypr-fuzzel`, `hypr-lock`, `hypr-focus-notification-app`, `fuzzel-open-file`, `fuzzel-open-file-dir`, `fuzzel-open-file-terminal`, `fuzzel-ssh-host`, `fuzzel-tmux-arch`, `fuzzel-calc` — converted to thin `exec orgm-hypr ... "$@"` wrappers.
- `config/shared/.config/hypr/scripts/pi-walker-prompt.sh` — converted to thin `exec orgm-hypr pi prompt --launcher walker "$@"` wrapper.
- `config/shared/.config/sway/config` — `waybar-watch` caller replaced with `orgm-hypr waybar watch ~/.config/waybar`.
- `openspec/changes/hypr-lua-orgm-hypr-migration/final-exception-tasks.md`, `wrapper-migration-audit.md`, `apply-progress.md`, `verify-report.md` — final closure evidence.

### TDD Cycle Evidence

| Task | Test File / Check | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 11.1 | `wrapper-migration-audit.md` | Docs/static | Existing final tasks/audit/progress read first | ✅ Audit listed open exceptions before closure | ✅ Final closure table added | ✅ Every target path has command/wrapper/rollback row | ➖ Docs-only |
| 11.2 | `cmd/orgm-hypr/final_exception_test.go` | CLI/unit | Existing command/router code read first | ✅ `go test ./cmd/orgm-hypr -run 'TestRunWithIOFinalException'` failed for missing command surfaces/flags | ✅ Focused final exception tests passed after implementation | ✅ Covers lock, launcher, notify, file, SSH, tmux, calc, Pi, webapp cancel | ✅ `gofmt` and focused tests |
| 11.3 | `cmd/orgm-hypr/final_exception_test.go` | CLI/plan characterization | Existing wrapper bodies read before tests | ✅ Tests expressed current wrapper plans before command surfaces existed | ✅ Print/cancel plans pass without launching GUI/processes | ✅ Path args, selected rows, host discovery, tmux session parse, calc/Pi plans | ✅ Shared runner helpers reused |
| 12.1 | `cmd/orgm-hypr/final_exception_test.go` + existing webapp tests | CLI/safety | Existing `internal/webapp` tests retained | ✅ `--interactive` flag missing before implementation | ✅ `webapp create --interactive --cancel` exits 0 with `cancelled` and no mutation | ✅ Existing dry-run/remove/profile gate tests remain in full suite | ➖ Full rofi UX not live-smoked in runtime |
| 12.2 | `cmd/orgm-hypr/final_exception_test.go` | CLI/plan | Existing session/windows tests retained | ✅ `session lock`, `launcher apps`, `notify focus-app` missing before implementation | ✅ Focused tests pass | ✅ Lock print vs forced live gate; launcher scaled args; notify pid plan | ✅ No destructive live lock without `--force` |
| 12.3 | `cmd/orgm-hypr/final_exception_test.go` | CLI/plan | Existing command tests retained | ✅ file/ssh/tmux/calc/pi groups missing before implementation | ✅ Focused tests pass | ✅ Terminal/file path, SSH config parse, tmux row parse, calc/Pi print plans | ✅ Shared `runOrPrintCommand` used |
| 12.4 | `go test ./cmd/orgm-hypr ./...` | Refactor safety | ✅ Focused final tests green | ➖ No new behavior beyond helper reuse | ✅ Full Go suite passed | ✅ Static wrapper audit checked converted paths | ✅ `gofmt`; no broad risky refactor |
| 13.1 | Static grep + Waybar tests | Static/caller | Existing `waybar watch --print` tests already passed | ✅ Sway config invoked `~/.local/bin/waybar-watch` before edit | ✅ Static grep found `orgm-hypr waybar watch ~/.config/waybar` | ✅ `go test ./...` includes Waybar tests | ➖ Caller string only |
| 13.2 | Wrapper static loop | Static | Go tests green before wrapper conversion | ✅ Listed wrappers had behavior-owning bodies before conversion | ✅ Static loop confirmed direct `exec orgm-hypr` lines | ✅ All final exception wrappers checked | ➖ Wrapper replacement only |
| 13.3 | Verification commands | CLI/static | N/A | ✅ Blocked external validators attempted and failed with tool/runtime blockers | ✅ `go test ./cmd/orgm-hypr ./...`, `git diff --check`, Lua syntax passed | ✅ Manual-safe print/cancel tests cover smoke checklist subset | ➖ No destructive smoke |

### Verification commands run in final closure

| Command | Result | Notes |
|---|---|---|
| `go test ./cmd/orgm-hypr -run 'TestRunWithIOFinalException'` after RED tests | FAIL expected | Missing command surfaces/flags before implementation. |
| `gofmt -w cmd/orgm-hypr/main.go cmd/orgm-hypr/final_exception_test.go && go test ./cmd/orgm-hypr -run 'TestRunWithIOFinalException'` | PASS | Focused final exception CLI tests. |
| `go test ./cmd/orgm-hypr ./...` | PASS | Full Go suite passed. |
| `git diff --check` | PASS | No whitespace errors. |
| `find config/shared/.config/hypr -name '*.lua' -print0 \| xargs -0 luac -p` | PASS | Lua syntax untouched/valid. |
| Static wrapper loop for final exception paths | PASS | All converted wrappers contain `exec orgm-hypr ...`. |
| Static grep for Sway `orgm-hypr waybar watch ~/.config/waybar` | PASS | Sway caller migrated. |
| `nix flake check` | BLOCKED | `/bin/bash: line 2: nix: command not found`; exit 127. |
| `orgm-dot diff --host orgm` | BLOCKED | `/bin/bash: line 4: orgm-dot: command not found`; exit 127. |
| `./dot.sh diff --host orgm` | BLOCKED | `/bin/bash: line 6: ./dot.sh: No such file or directory`; exit 127. |
| `nix fmt` | BLOCKED | `/bin/bash: line 8: nix: command not found`; exit 127. |
| `nix build .#packages.x86_64-linux.orgm-hypr --no-link` | BLOCKED | `/bin/bash: line 10: nix: command not found`; exit 127. |

### Deviations / notes

- Full rofi/fuzzel/walker GUI smoke not run in this executor. Command surfaces expose print/cancel paths and wrappers now delegate, but host manual smoke remains recommended.
- `hypr-lock` compatibility wrapper passes `--force` to preserve one-command lock behavior; safe non-destructive test surface is `orgm-hypr session lock --print`.
- Webapp interactive command surface currently has safe cancellation and explicit non-interactive dry-run/write paths; live rofi prompts were not host-smoked here.

### Remaining tasks

- No listed final exception remains behavior-owning.
- Run Nix/dot validators and manual Hypr/Sway smoke on host/runtime where tools are available.
