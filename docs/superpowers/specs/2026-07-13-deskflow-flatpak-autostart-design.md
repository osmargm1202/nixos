# Host-Scoped Deskflow Flatpak Autostart Design

## Goal

Install the current Flathub release of Deskflow and start it automatically in graphical sessions on the `orgm` and `lenovo` hosts.

## Scope

- Use Flatpak application `org.deskflow.deskflow` from the existing Flathub remote.
- Enable Deskflow only through host modules for `orgm` and `lenovo`.
- Support every graphical desktop profile on those hosts, including Hyprland.
- Keep installation and autostart behavior in one reusable NixOS module.
- Do not enable Deskflow on terminal-only configurations or other hosts.

## Module Structure

Create `nixos/deskflow.nix` as a NixOS module. It will contain:

1. A `services.flatpak.packages` declaration for `org.deskflow.deskflow`. Nix module list merging adds this application to the packages already declared in `nixos/flatpak.nix` without duplicating the shared Flatpak configuration.
2. A Home Manager systemd user service that starts Deskflow once a graphical display is available.
3. A small generated launcher script used by the service. The script waits for either `WAYLAND_DISPLAY` or `DISPLAY` to appear in the systemd user-manager environment, exports that environment, and then executes `flatpak run org.deskflow.deskflow`.

The service is enabled through the user `default.target`, because not every desktop profile in this repository starts `graphical-session.target` consistently. Waiting for display variables prevents Deskflow from launching before the compositor or X server is ready.

## Host Selection

Import `nixos/deskflow.nix` from the existing machine modules:

- `nixos/hosts/orgm/ms-7d43.nix`
- `nixos/hosts/lenovo/p14s-gen2i.nix`

Every graphical flake output for these machines already includes its machine module. Terminal-only outputs use only the hardware configuration and therefore do not receive Deskflow.

## Service Behavior

- Start one Deskflow process per user session.
- Wait a bounded amount of time for a graphical environment rather than running indefinitely without one.
- Restart only after a failed launch; do not restart after a clean user exit.
- Keep Deskflow application state and role selection under Deskflow's own user configuration.
- Do not modify compositor-specific autostart files.

## Failure Behavior

If no graphical display becomes available before the timeout, the launcher exits with failure and systemd applies the configured retry policy. Other session services remain unaffected. If the Flatpak is temporarily unavailable during activation, the same retry behavior applies.

## Verification

- Confirm Flathub resolves `org.deskflow.deskflow` and provides the newer release.
- Format all changed Nix files.
- Evaluate representative graphical outputs for both hosts, including `orgm-hyprland` and `lenovo-hyprland`.
- Confirm each selected host configuration contains the Deskflow Flatpak and user service.
- Evaluate an unrelated host and confirm it does not contain the Deskflow package or service.
- Review the final diff to ensure unrelated dirty files remain untouched.
