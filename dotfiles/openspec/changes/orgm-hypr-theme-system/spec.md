# Spec: orgm-hypr-theme-system

## Requirement: theme registry

The system SHALL define a JSON theme registry at `config/shared/.config/orgm-hypr/themes.json`.

The registry SHALL include:

- schema version;
- theme id/name/description;
- dark and light palettes;
- optional wallpaper path or wallpaper color source;
- target-specific overrides;
- reload policy;
- safety policy for profile-mutating targets.

Initial registry SHALL include `neutral`, derived from current config.

## Requirement: CLI

`orgm-hypr` SHALL add a `theme` command group:

- `list` lists available themes and modes.
- `status` reports active theme, mode, wallpaper, generated state paths, and last apply result.
- `validate` validates registry and templates.
- `preview <theme>` prints planned writes/reloads.
- `apply <theme>` applies a theme.
- `export-neutral` creates or updates neutral theme data from current config.

All write-capable commands SHALL support `--dry-run` where meaningful.

## Requirement: color modes

Theme mode SHALL support:

- `dark`
- `light`
- `auto`

`auto` SHALL derive mode from wallpaper brightness when wallpaper data exists. If brightness cannot be detected, system SHALL fall back to theme default mode and warn.

## Requirement: target coverage

Phase 1 SHALL support generated outputs for:

- Hyprland colors/fragments compatible with current Lua/hyprlang setup;
- Waybar Hypr CSS;
- nwg-dock CSS;
- GTK 3/4 settings and CSS variables;
- Qt 5/6 color/icon settings;
- Fuzzel and Rofi colors;
- Kitty theme include;
- Yazi/Helix theme pointers or generated theme files;
- Kvantum/KDE colors where existing config is present;
- Chromium theme export directory;
- Zen Browser best-effort export with explicit limitation notes.

Unsupported or unsafe target operations SHALL produce warnings, not partial silent mutation.

## Requirement: safe writes

The engine SHALL write generated files atomically.

The engine SHALL avoid overwriting hand-edited source files unless they are declared generated/current files.

The engine SHALL keep backup/rollback metadata for non-cache writes.

Runtime generated files SHOULD live in `$XDG_STATE_HOME/orgm-hypr/theme` or `$XDG_CACHE_HOME/orgm-hypr/theme`, with stable `current` files under config only when needed by apps.

## Requirement: reloads

Each target SHALL define reload behavior:

- `hyprctl reload` for Hyprland where safe;
- Waybar signal/restart policy;
- nwg-dock restart/reload policy;
- GTK/Qt settings update with restart hints;
- browser theme output with manual load instructions if automatic apply is unsafe.

Reload failures SHALL be reported per target without hiding successful writes.

## Requirement: testing

Tests SHALL cover:

- JSON schema validation;
- invalid theme errors;
- dark/light/auto palette selection;
- dry-run plan output;
- template rendering for representative targets;
- atomic write behavior;
- preservation of existing wallpaper commands.

## Requirement: Phase 2 boundary

Quickshell selector SHALL not duplicate theme logic. It SHALL consume registry/status data and call `orgm-hypr theme apply`.
