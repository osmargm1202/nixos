# GNOME Online Accounts GTK alongside Nautilus design

## Goal

Install `gnome-online-accounts-gtk` in every NixOS desktop profile that explicitly installs Nautilus and ensure the GOA daemon is D-Bus activatable outside GNOME.

## Scope

Add the package beside Nautilus in:

- `nixos/profiles/common_hyprland.nix`, covering classic Hyprland and HyprlandQS/Caelestia.
- `nixos/profiles/gnome.nix`.
- `nixos/profiles/i3.nix`.
- `nixos/profiles/labwc.nix`.

Do not add it globally in `nixos/common.nix`, because terminal/server and desktop profiles without Nautilus do not need it.

Enable `services.gnome.gnome-online-accounts.enable = true` in `common_hyprland.nix`, `i3.nix`, and `labwc.nix`. GNOME already enables the backend through its desktop module. The backend registration is required: without it, browser authentication succeeds but the GTK frontend waits forever because `goa-daemon` and `org.gnome.OnlineAccounts` are unavailable on the user D-Bus.

## Verification

A shell contract test requires the frontend beside every explicit Nautilus entry and requires the backend option in non-GNOME owners. Nix evaluation verifies the backend is enabled in Hyprland, Caelestia, GNOME, i3, and Labwc, followed by `git diff --check`, diagnostics, commit, and push to `origin/master`.

Existing unrelated Caelestia, Herdr, Kitty, and Yazi working-tree changes remain untouched.
