# GNOME Online Accounts GTK alongside Nautilus design

## Goal

Install `gnome-online-accounts-gtk` in every NixOS desktop profile that explicitly installs Nautilus.

## Scope

Add the package beside Nautilus in:

- `nixos/profiles/common_hyprland.nix`, covering classic Hyprland and HyprlandQS/Caelestia.
- `nixos/profiles/gnome.nix`.
- `nixos/profiles/i3.nix`.
- `nixos/profiles/labwc.nix`.

Do not add it globally in `nixos/common.nix`, because terminal/server and desktop profiles without Nautilus do not need it. Do not alter GNOME Online Accounts services; this change installs only the requested GTK frontend package.

## Verification

A shell contract test scans explicit Nautilus package entries and requires a neighboring `gnome-online-accounts-gtk` entry in each owning profile. Nix evaluation verifies the affected generic configurations, followed by `git diff --check`, diagnostics, commit, and push to `origin/master`.

Existing unrelated Caelestia, Herdr, Kitty, and Yazi working-tree changes remain untouched.
