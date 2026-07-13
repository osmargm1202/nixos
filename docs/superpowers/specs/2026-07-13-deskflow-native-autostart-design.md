# Native Deskflow Autostart Design

## Goal

Install Deskflow from nixpkgs and start it automatically in every Hyprland profile managed by this repository.

## Scope

- Use the native `pkgs.deskflow` package from the pinned nixpkgs input.
- Support both `hyprland` and `hyprlandqs-caelestia` profiles.
- Do not add Deskflow to Flatpak packages.
- Do not start Deskflow in Niri or non-Hyprland desktop sessions.

## Configuration

Add `deskflow` to the communication applications in `nixos/profiles/common_hyprland.nix`. Both Hyprland profiles import this shared module, avoiding duplicated package declarations.

Add `deskflow` to the `exec_once` command table in:

- `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua`
- `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua`

Hyprland starts one Deskflow process when the graphical session starts. Existing `exec_once` behavior prevents the command from being rerun by a normal configuration reload.

## Failure Behavior

If Deskflow exits or fails to start, other autostart commands continue independently. No restart policy is added; Deskflow retains control of its own application lifecycle and configuration.

## Verification

- Confirm `pkgs.deskflow` evaluates from the pinned nixpkgs input.
- Run the repository formatter or formatting check on changed Nix files.
- Evaluate both Hyprland NixOS configurations.
- Confirm both autostart files contain exactly one `deskflow` command.
- Review the final diff to ensure unrelated dirty files remain untouched.
