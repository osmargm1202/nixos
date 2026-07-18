# GNOME Online Accounts GTK alongside Nautilus design

## Goal

Install `gnome-online-accounts-gtk` in every NixOS desktop profile that explicitly installs Nautilus, ensure the GOA daemon is D-Bus activatable outside GNOME, and make authorized Google Drive accounts mountable.

## Scope

Add the package beside Nautilus in:

- `nixos/profiles/common_hyprland.nix`, covering classic Hyprland and HyprlandQS/Caelestia.
- `nixos/profiles/gnome.nix`.
- `nixos/profiles/i3.nix`.
- `nixos/profiles/labwc.nix`.

Do not add it globally in `nixos/common.nix`, because terminal/server and desktop profiles without Nautilus do not need it.

Enable `services.gnome.gnome-online-accounts.enable = true` in `common_hyprland.nix`, `i3.nix`, and `labwc.nix`. GNOME already enables the backend through its desktop module. The backend registration is required: without it, browser authentication succeeds but the GTK frontend waits forever because `goa-daemon` and `org.gnome.OnlineAccounts` are unavailable on the user D-Bus.

## Google Drive compatibility and accepted risk

Nixpkgs disables the GVfs Google backend because unmaintained `libgdata` requires EOL `libsoup-2.74.3`, which has multiple known unfixed CVEs. The user explicitly chose native legacy GVfs integration after this risk was presented instead of the recommended rclone mount.

Override `pkgs.gnome.gvfs` with `googleSupport = true` and permit only `libsoup-2.74.3` in the four Nautilus/GOA profiles. This restores `gvfsd-google` and the `google-drive` mount descriptor. Remove the exception when upstream ports the backend to libsoup 3 or when migrating to rclone.

## Verification

A shell contract test requires the frontend beside every explicit Nautilus entry, the GOA backend option in non-GNOME owners, and the explicit legacy Google backend/security exception in all four owners. Nix evaluation verifies the selected GVfs derivation across Hyprland, Caelestia, GNOME, i3, and Labwc. Building that derivation must produce executable `libexec/gvfsd-google` and `share/gvfs/mounts/google.mount`, followed by `git diff --check`, diagnostics, commit, and push to `origin/master`.

Existing unrelated Caelestia, Herdr, Kitty, and Yazi working-tree changes remain untouched.
