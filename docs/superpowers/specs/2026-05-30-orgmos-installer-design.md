# ORGMOS Interactive Installer Design

## Goal

Create a safe interactive installer for ORGMOS so a new NixOS machine can install this repository's profiles from GitHub while keeping its own local `hardware-configuration.nix`.

Primary entrypoint:

```bash
curl -fsSL https://or-gm.com/orgmos | bash
```

`or-gm.com/orgmos` will redirect to this repository's `install.sh`.

## Problem

The repository currently has host-specific flake outputs such as `orgm-hyprland`, `lenovo-gnome`, and profile-only outputs such as `hyprland` that use an eval-only generic hardware module. That works for known machines and checks, but it is not the right install model for an unknown new machine.

A remote GitHub flake cannot safely and purely discover a user's local `/etc/nixos/hardware-configuration.nix`. The install flow must create a small local flake that points at the GitHub repo and imports the local hardware file.

## Design

Add an interactive `install.sh` script to the repository. The script is intended for pipe-to-bash use, but must remain safe by default.

The script will:

1. Detect that it is running on NixOS.
2. Verify `/etc/nixos/hardware-configuration.nix` exists.
3. Ask the user to choose a profile:
   - `hyprland`
   - `gnome`
   - `labwc`
   - `sway`
   - `i3`
4. Ask for the target hostname, defaulting to current `hostname`.
5. Backup any existing `/etc/nixos/flake.nix` before replacing it.
6. Write a minimal local `/etc/nixos/flake.nix` that imports this repository and calls `orgmos.lib.mkGeneralHost` with:
   - `hardware = ./hardware-configuration.nix;`
   - selected profile
   - selected hostname
7. Show the generated flake and explain what will happen.
8. Ask for explicit confirmation before running `sudo nixos-rebuild switch --flake /etc/nixos#default`.

The generated local flake will look like:

```nix
{
  inputs.orgmos.url = "github:osmargm1202/nixos";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = ./hardware-configuration.nix;
      profile = "hyprland";
      hostName = "my-host";
    };
  };
}
```

## Repository Changes

### `flake.nix`

Expose `lib.mkGeneralHost`.

`mkGeneralHost` will accept:

```nix
{
  hardware,
  profile,
  hostName,
  extraModules ? [ ],
}
```

`profile` will be a string mapped to existing profile modules. Invalid profile names should fail evaluation with a clear error.

The module list will include:

1. `./nixos/common.nix`
2. `./nixos/general.nix`
3. user-provided local hardware module
4. selected profile module
5. networking hostname module
6. optional extra modules

### `nixos/general.nix`

Add general ORGMOS configuration that is safe for unknown hardware and not hardware-specific. This module should contain general branding and defaults only.

### `nixos/hosts/general/plymouth.nix`

Add the general Plymouth logo theme module. It will use the existing `nixos/plymouth-logo-theme.nix` helper with a general ORGMOS logo.

### `nixos/plymouth-logos/`

Initial implementation will reuse `orgm-nixos.png` as the general ORGMOS logo to avoid blocking installer work. A future visual-only change may replace it with `orgmos.png` without changing installer behavior.

### Existing host outputs

Keep current host-specific outputs unchanged. Known hosts continue using their own `hardware-configuration.nix` and host-specific Plymouth modules.

### Existing profile outputs

Keep current eval-only outputs (`hyprland`, `gnome`, etc.) for pure flake evaluation and checks. They should not be presented as the recommended install path for real machines.

## Safety Rules

- Do not run `nixos-rebuild switch` without explicit confirmation.
- Do not delete existing `/etc/nixos/flake.nix`; backup it with a timestamp.
- Do not modify `/etc/nixos/hardware-configuration.nix`.
- Exit with a clear message if not running on NixOS or if hardware config is missing.
- Prefer readable shell over clever shell.

## Success Criteria

- A new NixOS machine can run `curl -fsSL https://or-gm.com/orgmos | bash` and get an interactive setup.
- The generated local flake uses local hardware config and repository profiles.
- The general host gets the ORGMOS Plymouth branding.
- Existing host-specific outputs still evaluate as before.
- Profile-only outputs remain available for evaluation/checks.
