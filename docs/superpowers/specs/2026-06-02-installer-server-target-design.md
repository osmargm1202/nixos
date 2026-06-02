# Installer Server Target Design

## Goal

Allow the generic `install.sh` flow to install a server target that uses `nixos/server.nix`.

## Problem

`install.sh` currently only exposes desktop profiles:

- `hyprland`
- `gnome`
- `labwc`
- `sway`
- `i3`

The existing `ero-server` flake output uses `nixos/server.nix` directly, without `nixos/common.nix`, `nixos/general.nix`, desktop GPU modules, or desktop kernel selection from the installer. The generic installer has no way to generate that server-shaped config for new machines.

## Approved Design

Add a separate server install path.

### Flake API

Expose a new helper:

```nix
orgmos.lib.mkServerHost {
  hardware = ./hardware-configuration.nix;
  hostName = "my-server";
  extraModules = [ ];
}
```

`mkServerHost` builds a NixOS system with modules:

1. local generated hardware file
2. `./nixos/server.nix`
3. hostname module
4. optional `extraModules`

It intentionally does not include `./nixos/common.nix`, `./nixos/general.nix`, or desktop profiles.

### Installer behavior

Add `server` to the profile menu.

If user selects `server`:

- skip GPU prompt
- skip kernel prompt
- ask hostname as usual
- write generated flake using `orgmos.lib.mkServerHost`
- keep existing `/etc/nixos` vs `/mnt/etc/nixos` command behavior

If user selects a desktop profile:

- keep current GPU prompt
- keep current kernel prompt
- keep current `orgmos.lib.mkGeneralHost` generated flake

### Summary output

For server installs, show:

- selected profile: `server`
- mode: `rebuild` or `install`
- no GPU/kernel lines

For desktop installs, keep existing summary lines.

## Testing

Add regression tests proving:

1. Choosing `server` sets server mode.
2. Server generated flake calls `orgmos.lib.mkServerHost`.
3. Server generated flake does not include desktop GPU/kernel modules.
4. Existing desktop flake still calls `orgmos.lib.mkGeneralHost` and includes selected GPU/kernel modules.
5. `flake.nix` exports `lib.mkServerHost`.

## Scope

This change only adds a generic server install target. It does not change the contents of `nixos/server.nix` or existing `ero-server` behavior.
