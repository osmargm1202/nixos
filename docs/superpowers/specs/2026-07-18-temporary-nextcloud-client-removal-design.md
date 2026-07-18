# Temporary Nextcloud client removal design

## Goal

Temporarily remove the Nextcloud desktop client and every declarative desktop autostart without deleting user data, credentials, or configuration.

## Scope

Remove `nextcloud-client` from `nixos/common.nix`.

Remove Nextcloud startup commands from:

- `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua`.
- `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua`.
- `dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl`.
- `dotfiles/config/profiles/labwc/.config/labwc/autostart`.

Delete the active entries instead of commenting them out or adding a feature flag. Git history provides the temporary rollback path with less configuration debt.

## Data preservation

Do not touch:

- `~/Nextcloud` or any synchronized content.
- Nextcloud user configuration, cache, credentials, or account state.
- AGE key paths that reference files under `~/Nextcloud`.
- Obsidian, Pi, Claude, Herdr, or documentation paths that merely reference Nextcloud directories.

## Verification

A shell contract test requires the package and all four startup commands to be absent while preserving known AGE-path references. Run focused shell syntax checks, affected Nix profile evaluations, diagnostics, and `git diff --check`. Commit and push only the intended source/test files; preserve unrelated working-tree changes.
