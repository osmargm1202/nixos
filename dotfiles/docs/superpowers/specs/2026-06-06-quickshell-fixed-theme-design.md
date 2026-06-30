# Quickshell fixed theme design

## Goal

Keep the Quickshell keybinding help menu and wallpaper picker visually stable when `orgm-theme apply` switches global dark/light themes.

## Problem

`orgm-themes` currently renders `~/.config/quickshell/theme/theme.json` from each global palette. Both Quickshell surfaces read that file, so palette changes can corrupt their carefully tuned colors.

## Design

Use fixed Quickshell theme files instead of generated palette colors:

- `orgm-dark.json` contains the known-good dark UI colors.
- `orgm-light.json` contains the known-good light UI colors.
- `current.json` is the active file read by Quickshell.
- `theme.json` remains as a compatibility copy during transition.

`orgm-theme apply orgm-dark|orgm-light` selects the matching fixed file and writes/copies it to `current.json` and `theme.json`. If a future custom theme exists without a matching fixed file, `orgm-themes` falls back to rendered colors so apply still works.

## Files

- `config/shared/.config/quickshell/theme/orgm-dark.json` — fixed dark Quickshell palette.
- `config/shared/.config/quickshell/theme/orgm-light.json` — fixed light Quickshell palette.
- `config/shared/.config/quickshell/theme/current.json` — repo default active fixed palette.
- `config/shared/.config/quickshell/modules/keyhelper/shell.qml` — read `current.json` first.
- `config/shared/.config/quickshell/wallpaper-picker/shell.qml` — read `current.json` first.
- `internal/orgmtheme/render.go` — render fixed Quickshell writes.
- `internal/orgmtheme/render_test.go` — cover fixed file behavior.
- `internal/orgmtheme/apply_test.go` — cover apply writing fixed theme files.

## Validation

- `go test ./internal/orgmtheme`
- `bash tests/helpers/orgm-theme-wallpaper.bats.sh`
- `bash tests/helpers/orgm-theme-light-contrast.bats.sh`
