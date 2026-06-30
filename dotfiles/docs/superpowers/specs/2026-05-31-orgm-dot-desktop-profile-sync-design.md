# orgm-dot Desktop Profile Sync Design

## Goal

Make `orgm-dot` synchronize desktop-specific dotfiles only when they match the active graphical environment, while leaving GNOME-managed settings alone.

## Scope

This change affects sync selection only. It does not delete files already present in the destination home. Existing unmanaged or previously synced files from other desktops remain until removed by an explicit cleanup flow.

## Desktop Profiles

`orgm-dot` will classify the current session into a desktop profile:

- `hyprland`
- `gnome`
- `labwc`
- `sway`
- `all` / unknown fallback

Detection should use common environment signals such as `XDG_CURRENT_DESKTOP`, `DESKTOP_SESSION`, `XDG_SESSION_DESKTOP`, and Hyprland-specific variables. A manual override should exist for tests and intentional runs, using `ORGM_DOT_DESKTOP=hyprland|gnome|labwc|sway|all`.

## Sync Rules

Common non-desktop-specific paths continue to sync in all profiles.

Profile-specific behavior:

- Hyprland: sync Hyprland config and helpers, including `.config/hypr`, `.config/orgm-hypr`, `.config/waybar-hypr`, `.config/nwg-dock-hyprland`, `hypr-*`, and Hyprland-specific helpers.
- GNOME: do not sync compositor/theme helpers that would interfere with GNOME. Block Hyprland, labwc, Sway, and compositor-specific Waybar/dock helpers. GNOME should configure itself.
- labwc: sync labwc config and labwc helpers. Block Hyprland helpers/config.
- Sway: sync Sway config/helpers and labwc helpers. Block Hyprland helpers/config.
- unknown/all: keep current behavior to avoid surprising headless or unusual environments unless explicitly overridden.

## Architecture

Add a small filtering layer in `internal/dotsync` before each configured path reaches `syncOne`.

Proposed units:

- `DesktopProfile`: typed profile enum or string constants.
- `DetectDesktopProfile(env lookup)`: converts environment into a profile.
- `ShouldSyncPath(profile, rel)`: pure path filter for tests.
- `Run`: resolves profile once, then filters `rt.Config.Shared.Paths` and host paths before syncing.

Keep path matching explicit and conservative. Use normalized slash paths and path-prefix checks for directories.

## Error Handling

Invalid `ORGM_DOT_DESKTOP` should return a clear error before sync starts. Unknown auto-detected environments should fall back to `all`/current behavior rather than silently dropping paths.

## Tests

Add focused tests for:

- GNOME blocks `.config/hypr`, `.config/labwc`, `.config/sway`, `.config/waybar-hypr`, `.config/nwg-dock-hyprland`, `.local/bin/hypr-*`, `.local/bin/sway-*`, and `.local/bin/labwc-*`.
- Hyprland allows Hyprland paths and blocks labwc/sway-only helpers where appropriate.
- labwc allows labwc paths and blocks Hyprland paths.
- Sway allows `.config/sway`, `.local/bin/sway-*`, and labwc helpers, while blocking Hyprland paths.
- `ORGM_DOT_DESKTOP` override controls behavior in tests.
- Unknown profile keeps current sync behavior.

## Verification

Run:

```bash
go test ./internal/dotsync ./internal/dotconfig
go test ./...
git diff --check
```

Do not run `orgm-dot sync` unless explicitly approved. `orgm-dot diff` can be used after implementation to inspect expected changes.
