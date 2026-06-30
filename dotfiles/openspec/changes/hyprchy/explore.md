# Explore: hyprchy

## Status

completed

## Executive summary

Create a new NixOS Hyprland-based profile, `nixos/profiles/hyprchy.nix`, inspired by Omarchy. It should use git/flaked Walker and Elephant, make Walker the central launcher, support multiple hosts, and preserve the existing Hyprland setup.

## User decisions

- Walker source: upstream git/flaked version.
- Elephant source: upstream git/flaked version.
- Profile strategy: new profile, `hyprchy.nix`, not replacing current `hyprland.nix`.
- Launcher strategy: Walker as central launcher.
- Host strategy: multi-host.

## Current repo shape

- `flake.nix` owns host/profile matrix through `mkHost` and `mkProfile`.
- Current Hyprland baseline lives in `nixos/profiles/hyprland.nix`.
- Current Hyprland dotfiles live in `config/shared/.config/hypr/**`.
- Dotfile sync is managed by `config/dotfiles.json` and `./dot.sh`.
- Current launcher is still mostly `fuzzel`, with existing Walker helper scripts already present:
  - `config/shared/.config/hypr/scripts/pi-walker-prompt.sh`
  - `config/shared/.config/hypr/scripts/walker-window-switch.sh`

## External research

- Walker upstream: `https://github.com/abenz1267/walker`
- Elephant upstream: `https://github.com/abenz1267/elephant`
- Omarchy upstream: `https://github.com/basecamp/omarchy`
- Omarchy uses Walker as visible menu/launcher and Elephant as backend/provider service.
- Walker and Elephant compatibility must be pinned together because protocol/provider compatibility has broken across revisions.

## Important findings

- `hyprland.nix` is safest compatibility baseline for `hyprchy.nix`.
- Fuzzel is embedded in `programs.lua`, `keybindings.lua`, Waybar config, helper scripts, and help text.
- New Walker/Elephant dotfile paths must be added to `config/dotfiles.json` if managed by dot.sh.
- Conservative first provider set should avoid heavy file indexing until CPU/inotify behavior is validated.

## Risks

- Git inputs increase flake lock/build risk.
- Walker/Elephant protocol drift can break launch results.
- Full fuzzel-to-Walker migration may exceed review budget.
- `ero` does not currently have a Hyprland config, so multi-host support needs explicit host matrix design.

## Next recommended

Proceed to proposal, spec, design, and tasks before implementation.
