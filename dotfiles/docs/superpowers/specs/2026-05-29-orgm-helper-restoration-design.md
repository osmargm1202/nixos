# ORGM helper restoration design

## Goal

Return daily Hyprland/Waybar/menu behavior to simple shell helpers in `dotfiles`, keep only stable or expensive ORGM features in small Go binaries maintained from `dotfiles`, and keep the `nixos` repository separate as the system configuration and package consumer.

## Decision

Use **shell helpers by default**. Use Go only where it has clear value:

- `orgm-wallpaper`: wallpaper data, thumbnail generation/cleanup, picker support, and stable wallpaper daemon support when shell is not enough.
- `orgm-calendar`: calendar sync/daemon/reminders/UI bridge already working as a focused helper.
- `orgm-dot`: dotfile compare/sync daemon and CLI, maintained from `dotfiles` so the dotfile repo owns its own management tool.

Do not keep a broad `orgm-hypr` system manager. Hyprland-specific glue returns to named shell helpers. If themes later show real shell latency, introduce a focused `orgm-themes` Go binary; otherwise keep themes in shell.

## Repository boundary

Keep repositories separate:

- `/home/osmarg/Hobby/dotfiles`
  - Source of shell helpers.
  - Source of focused Go helpers: `orgm-wallpaper`, `orgm-calendar`, `orgm-dot`.
  - Owns user config, menus, Waybar, Hypr Lua, SwayNC, helper scripts, tests for helpers.
- `/home/osmarg/Hobby/nixos`
  - NixOS host configuration.
  - Package definitions that build Go helpers from the dotfiles checkout or pinned dotfiles source.
  - Does not own day-to-day shell helper logic.

This keeps editing fast in dotfiles while leaving host rebuild and packaging in NixOS.

## Why change

The broad `orgm-hypr` consolidation made the desktop more fragile:

- Small menu/Waybar/session fixes require Go edit + compile + package/rebuild.
- Shell helpers were faster to change and more transparent.
- The main Go win was the expensive wallpaper thumbnail/image-selection path.
- A missing old wallpaper daemon changed expected behavior: random wallpaper every ~30 minutes was simpler and reliable before consolidation.

## Scope

### In scope

- Inventory all current `orgm-hypr` callers in dotfiles and NixOS.
- Restore shell helpers from git history where possible.
- Rewire menus, Waybar modules, Hypr Lua autostart, OSD actions, launchers, window helpers, session helpers, and theme helpers to shell scripts.
- Split/rename Go helpers into focused commands owned by dotfiles.
- Add tests and smoke checks for restored helpers.
- Preserve working wallpaper thumbnail/picker performance.
- Restore a simple wallpaper daemon behavior, default interval 30 minutes, with one daemon instance.

### Out of scope for first pass

- Moving the NixOS repo into dotfiles.
- Rewriting all NixOS host modules.
- Creating `orgm-themes` before measuring theme latency.
- Removing NixOS packaging before replacement packages exist.

## Target command ownership

| Area | Target owner | Notes |
| --- | --- | --- |
| Main menu, power menu, app launch | shell helper | Fast edits; no compile. |
| Waybar date/swap/workspace helpers | shell helper unless complex | Prefer POSIX/bash and `jq` for JSON. |
| OSD volume/mic/brightness | shell helper | `notify-send` wrappers are enough. |
| Window switch/kill helpers | shell helper | Existing Sway/LabWC helpers provide pattern. |
| Session env/start apps/containers/lock | shell helper | Keep direct command visibility. |
| Themes | shell helper | Later promote to `orgm-themes` only if latency proven. |
| Wallpaper thumbnail/data/picker | `orgm-wallpaper` + shell wrappers | Keep Go where speed mattered. |
| Wallpaper random daemon | shell wrapper + optional `orgm-wallpaper` support | Restore simple 30 min daemon semantics. |
| Calendar | `orgm-calendar` | Focused Go helper remains. |
| Dotfile sync/diff | `orgm-dot` | Go helper maintained in dotfiles. |
| Battery alert | shell helper unless persistence becomes complex | The just-added Go battery code should be reconsidered during split. |

## Desired file layout in dotfiles

```text
config/shared/.local/bin/
  hypr-main-menu
  hypr-power-menu
  hypr-random-wallpaper
  hypr-wallpaper-picker
  hypr-waybar-date
  hypr-waybar-swap
  hypr-workspace-button
  hypr-osd-volume
  hypr-osd-mic
  hypr-osd-brightness
  hypr-session-import-env
  hypr-session-start-containers
  hypr-session-start-discord
  hypr-theme-apply
  orgm-wallpaper        # installed Go binary or wrapper in dev
  orgm-calendar         # installed Go binary or wrapper in dev
  orgm-dot              # installed Go binary or wrapper in dev

cmd/
  orgm-wallpaper/
  orgm-calendar/
  orgm-dot/
internal/
  wallpaper/
  calendar/
  dot*/
tests/
  helpers/
  orgm-wallpaper.bats.sh
  orgm-calendar.bats.sh
  orgm-dot.bats.sh
```

Exact names may change during inventory, but each helper should have one clear purpose.

## SDD phases

### Phase 0 — Safety and inventory

1. Record dirty state in both repos.
2. Preserve current working changes before broad edits.
3. Build a caller map:
   - `orgm-hypr` references in `dotfiles/config/shared`.
   - `orgm-hypr` references in `nixos` package/tests/modules.
   - Shell helpers currently present.
   - Shell helpers recoverable from git history.
4. Classify each command as shell, `orgm-wallpaper`, `orgm-calendar`, `orgm-dot`, deferred, or delete.

Output: inventory markdown with table and proposed owner for every caller.

### Phase 1 — Restore shell helpers without changing callers

1. Restore helper scripts into `config/shared/.local/bin` or `config/shared/.config/hypr/scripts`.
2. Use existing historical behavior where available.
3. Add `--print` or dry-run modes where useful for tests.
4. Add helper tests before rewiring broad callers.

Output: scripts exist, tests pass, live behavior unchanged.

### Phase 2 — Rewire callers from `orgm-hypr` to helpers

1. Update Hypr Lua autostart and keybindings.
2. Update Waybar config/modules.
3. Update menu entries.
4. Update wrappers and compatibility aliases.
5. Keep temporary compatibility wrappers if needed:
   - old command name calls new shell helper
   - no silent behavior changes

Output: dotfiles no longer depends on broad `orgm-hypr` for daily glue.

### Phase 3 — Split Go helpers in dotfiles

1. Copy/move focused Go code from `nixos` to `dotfiles`:
   - wallpaper packages and command into `cmd/orgm-wallpaper`.
   - calendar packages and command into `cmd/orgm-calendar`.
   - dotfile packages and command into `cmd/orgm-dot`.
2. Rename CLI surfaces:
   - `orgm-hypr wallpaper ...` → `orgm-wallpaper ...`.
   - `orgm-hypr calendar ...` → `orgm-calendar ...`.
   - `orgm-dot` remains `orgm-dot`.
3. Keep `orgm-hypr` only as a temporary compatibility shim if needed, then remove.

Output: dotfiles builds focused Go binaries locally.

### Phase 4 — NixOS packaging consumes dotfiles Go helpers

1. Change `/home/osmarg/Hobby/nixos` package expressions to build from dotfiles source or a pinned dotfiles revision.
2. Keep NixOS configs separate.
3. Ensure host packages install:
   - `orgm-wallpaper`
   - `orgm-calendar`
   - `orgm-dot`
4. Remove or deprecate `orgm-hypr` package only after callers are gone.

Output: NixOS rebuild packages focused helpers without owning their source.

### Phase 5 — Verification and cleanup

1. Run helper tests.
2. Run Go tests in dotfiles.
3. Run Nix package builds from NixOS.
4. Run `distrobox-host-exec orgm-dot diff` and `sync` only after reviewing diff.
5. Manual smoke checks:
   - menu opens
   - power menu works
   - Waybar modules render
   - wallpaper picker opens with thumbnails
   - wallpaper daemon changes wallpaper after interval or with forced short interval
   - calendar reminder daemon starts
   - dotfile sync still works

Output: broad `orgm-hypr` removed from active desktop path.

## Testing strategy

- Shell helpers: Bats or portable shell tests with stubbed commands.
- Go helpers: normal `go test ./...` from dotfiles.
- Dotfile sync: `distrobox-host-exec orgm-dot diff` before `sync`.
- Nix packaging: build only affected packages first; full host build later.
- Regression checks: each caller migrated should have at least one test or smoke command proving target helper exists and accepts expected args.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Break live desktop by changing many callers at once | Use phased migration and compatibility wrappers. |
| Lose working wallpaper performance | Keep wallpaper Go path first-class as `orgm-wallpaper`. |
| NixOS package path coupling to local dotfiles checkout | Decide pinned source vs local path in Phase 4; document tradeoff. |
| Shell helper drift/no tests | Add small tests and dry-run modes before rewiring. |
| Dirty working trees obscure changes | Save inventory and avoid commits that mix unrelated existing edits. |
| `orgm-hypr` references remain hidden | Grep audit before completion. |

## Open decisions

1. NixOS package source for dotfiles Go helpers:
   - local path for development speed, or pinned Git source for reproducible rebuilds.
2. Whether compatibility shims live in shell (`orgm-hypr` wrapper) or NixOS package alias during transition.
3. Final helper naming conventions: `hypr-*` versus `orgm-*` for shell helpers.
4. Whether battery alerts stay shell-only or become a small focused Go helper later.

## Approval checkpoint

This spec approves planning only. Implementation starts after a separate SDD plan breaks phases into small reviewable slices.
