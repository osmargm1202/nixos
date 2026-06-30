# Proposal: orgm-hypr-theme-system

## Status

proposed

## Problem

Hyprland desktop theming is spread across app-specific config files and helper scripts. Wallpaper changes can update wallpaper state, but colors, light/dark mode, Waybar, dock, GTK, Qt, browsers, and terminal/menu apps do not yet share one typed theme contract.

HyDE solves a similar problem, but its implementation is shell-heavy and hyprlang-centric. This repo should copy the architecture ideas, not the script sprawl.

## Goals

- Create a complete first-cycle theme application engine under `orgm-hypr theme`.
- Use `themes.json` as the curated theme registry and include a neutral theme derived from the current config.
- Support dark, light, and auto mode.
- Apply wallpaper-derived colors when requested.
- Update target apps through generated files/templates and safe reload hooks.
- Preserve current Hyprland behavior and Lua setup.
- Keep Phase 2 Quickshell selector out of the engine implementation.

## Non-goals

- Do not build the Quickshell selector in Phase 1.
- Do not blindly port HyDE scripts.
- Do not replace the whole Hyprland Lua migration.
- Do not mutate browser profiles without backup/dry-run and explicit target support.
- Do not commit random generated wallpaper cache output.

## In scope

- `config/shared/.config/orgm-hypr/themes.json`
- `orgm-hypr theme` CLI group: `list`, `status`, `validate`, `apply`, `preview`, `export-neutral`.
- Theme engine internals for schema parsing, palette generation, template rendering, atomic writes, backups, and reload hooks.
- Targets: Hyprland, Waybar Hypr, nwg-dock, GTK 3/4, Qt 5/6, Kvantum/KDE where present, Fuzzel/Rofi, Kitty, Yazi/Helix, Chromium theme export, Zen Browser best-effort export.
- Tests for schema validation, render output, dry-run behavior, and atomic write/rollback logic.
- Docs explaining supported targets and limitations.

## Out of scope

- Quickshell selector UI.
- Installing external packages.
- Flatpak overrides unless gated behind explicit config.
- Destructive rewrites of user profile files.
- Theme marketplace/download behavior.

## Acceptance criteria

- `orgm-hypr theme validate` validates `themes.json` and all templates.
- `orgm-hypr theme export-neutral` can generate a neutral starter theme from current tracked config/state.
- `orgm-hypr theme apply neutral --mode dark --dry-run` reports planned writes and reloads without writing.
- Non-dry apply writes only approved generated/current theme files with atomic replace and backup/rollback metadata.
- Waybar, nwg-dock, GTK, Qt, Hyprland, terminal/menu targets receive generated theme outputs.
- Browser targets produce safe theme artifacts or clear actionable unsupported warnings.
- Existing wallpaper commands/tests continue passing.
- Validation uses existing runner: `nix flake check`; focused smoke: `tests/orgm-hypr.bats.sh`.

## Review strategy

Expected implementation exceeds 400 changed lines. Use review slices:

1. Schema + neutral theme + validation tests.
2. Core renderer/atomic writer + dry-run.
3. Desktop targets: Hyprland, Waybar, nwg-dock, GTK, Qt.
4. App targets: Fuzzel/Rofi, Kitty, Yazi/Helix, Kvantum/KDE.
5. Browser export targets + docs.

## Risks

- Full target coverage is broad; strict TDD and slicing are needed.
- Browser theming may be export-only at first for safety.
- Runtime writes can conflict with managed dotfiles if generated paths are not separated.
- Hyprland Lua and hyprlang fragments must remain compatible.
