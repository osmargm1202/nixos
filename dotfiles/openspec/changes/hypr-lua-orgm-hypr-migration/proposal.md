# Proposal: hypr-lua-orgm-hypr-migration

## Status

proposed

## Problem

Current Hyprland behavior is spread across shared Hypr config, shell helper scripts, menu wrappers, Waybar helpers, OSD utilities, and the `orgm-hypr` Go module. This makes behavior harder to audit, test, reuse, and migrate as Hyprland 0.55+ moves toward `~/.config/hypr/hyprland.lua` and away from hyprlang.

## Intent

Plan a low-risk migration that moves live compositor behavior into Hyprland Lua modules and moves CLI/session orchestration into `orgm-hypr`, while preserving scripts that are still the right interface for interactive menus or Unix glue.

## Goals

- Define a plan-only migration path before implementation.
- Reduce standalone Hyprland scripts where Lua modules or `orgm-hypr` subcommands are better owners.
- Preserve current user-facing Hyprland behavior during migration.
- Use Hyprland Lua for compositor-local behavior: bindings, reusable action modules, events, timers, rules, workspace/monitor logic, and reactive behavior.
- Use `orgm-hypr` for CLI/system orchestration that benefits from typed code, tests, and subcommands.
- Keep truly interactive launchers, menu wrappers, and small Unix glue as scripts when they remain simpler and safer.
- Keep implementation reviewable within the 400 changed-line review budget by forecasting slices.

## Non-goals

- Do not implement the migration in this proposal phase.
- Do not delete existing scripts until later spec/design/tasks approve equivalence and rollback.
- Do not move blocking or long-running interactive flows into compositor Lua unless validated safe.
- Do not write C++ Hyprland plugins in this change.
- Do not redesign unrelated NixOS profiles, non-Hypr desktops, or unrelated dotfiles.
- Do not require immediate full replacement of hyprlang before compatibility is confirmed.

## In scope

- Inventory and classify migration-relevant files under:
  - `config/shared/.config/hypr/**`
  - `config/shared/.config/hypr/scripts/**`
  - `config/shared/.local/bin/hypr-*`
  - `config/shared/.local/bin/fuzzel-*`
  - OSD, Waybar, and desktop helper scripts tied to Hyprland behavior
  - `orgm-hypr` Go module in this repo
- Plan Hyprland Lua module ownership for compositor-local behavior.
- Plan `orgm-hypr` command/subcommand ownership for external orchestration.
- Plan script retention criteria for menu wrappers, subprocess launchers, and Unix glue.
- Plan validation around dotfile sync, Go tests, Hypr config loading, and existing behavior preservation.

## Out of scope

- Editing Hyprland config, scripts, Go code, Nix files, or dotfile manifests during proposal phase.
- Changing installed files through `orgm-dot sync`.
- Rebinding user shortcuts or changing launcher UX without later approved spec/design.
- Solving behavior that requires arbitrary compositor internals beyond Lua APIs.

## Acceptance criteria

Later phases should be considered successful when:

- Proposal, spec, design, and tasks are approved before implementation starts.
- Each migration target has clear owner: Hyprland Lua, `orgm-hypr`, retained script, or deferred.
- Current core Hyprland behavior remains available after each slice.
- `orgm-dot diff --host orgm` shows only expected managed dotfile changes after implementation slices.
- Go changes in `orgm-hypr` have focused tests where practical.
- Hyprland Lua entrypoint/module loading is validated on Hyprland 0.55+ or documented as blocked by local version/runtime.
- Retained scripts have explicit rationale instead of being left by accident.
- Rollback path restores previous script/config behavior without broad unrelated changes.

## Migration strategy

1. Inventory current Hyprland-adjacent files and group them by behavior domain.
2. Classify each item:
   - **Lua module** for compositor-local state, rules, binds, dispatchers, events, timers, monitor/workspace/window actions, and portable `Config.setup` style configuration.
   - **`orgm-hypr` subcommand** for external system orchestration, typed logic, reusable CLI actions, and testable operations.
   - **Retained script** for interactive fuzzel/menu flows, subprocess wrappers, blocking tools, and small shell glue.
   - **Deferred/plugin** for behavior requiring unsupported compositor internals or possible C++ plugin work.
3. Introduce Lua entrypoint/modules alongside existing behavior first, not as a destructive replacement.
4. Move one behavior domain per implementation slice, with before/after validation and rollback notes.
5. Remove or shrink scripts only after equivalent behavior is validated.

## Affected areas

- Hyprland Lua/hyprlang config under `config/shared/.config/hypr/**`.
- Hyprland helper scripts under `config/shared/.config/hypr/scripts/**`.
- User PATH helpers under `config/shared/.local/bin/**` for `hypr-*`, `fuzzel-*`, OSD, and Waybar integration.
- `orgm-hypr` Go module commands and tests.
- Dotfile manifest and sync flow if new/renamed managed files are added later.
- OpenSpec artifacts for spec, design, tasks, apply progress, and verify report.

## Review slicing forecast

If implementation exceeds 400 changed lines, use chained slices:

1. **Inventory and test harness slice**: classify files, add/adjust `orgm-hypr` tests or fixtures without behavior changes.
2. **Lua foundation slice**: add `hyprland.lua` entrypoint and module structure while preserving existing behavior.
3. **Compositor behavior slice(s)**: migrate binds/rules/workspace/monitor/reactive logic by domain.
4. **`orgm-hypr` CLI slice(s)**: move orchestration into subcommands with focused tests.
5. **Script cleanup slice**: retire or simplify only validated redundant scripts; keep documented retained wrappers.
6. **Docs/verification slice**: update OpenSpec progress and final validation evidence.

## Rollback

- Keep old scripts/config paths until replacement behavior is validated.
- Prefer additive Lua modules and `orgm-hypr` subcommands before removing old entrypoints.
- Revert individual slices if validation fails.
- Use managed dotfile workflow to inspect and apply only expected changes: `orgm-dot diff --host orgm`, then `orgm-dot sync --host orgm` only in later implementation/verification phases.

## Risks

- Hyprland Lua behavior and APIs may differ across local Hyprland versions despite 0.55+ research.
- Blocking or interactive flows inside compositor Lua can freeze or degrade session responsiveness.
- Script behavior may encode undocumented side effects that inventory misses.
- Existing uncommitted change exists outside this SDD change: `config/shared/.config/nwg-dock-hyprland/style.css`.
- Exploration and proposal rely on summarized research; later phases should verify local runtime behavior.
- Engram persistence was requested for important discoveries, but no memory tool is available in this phase context.

## Success criteria

- Migration plan is clear enough for spec/design/tasks without implementation guesswork.
- Scope separates Lua, Go CLI, retained scripts, and deferred/plugin work.
- Risks and rollback are explicit.
- Review slicing keeps changes small and reversible.
