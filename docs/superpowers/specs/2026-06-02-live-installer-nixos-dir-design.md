# Live Installer NixOS Directory Design

## Goal

Make `install.sh` work both on an already-installed NixOS system and inside the NixOS live installer after:

```bash
nixos-generate-config --root /mnt
```

That command writes generated defaults to `/mnt/etc/nixos`, not `/etc/nixos`.

## Problem

Current `install.sh` defaults to `/etc/nixos` and verifies only `/etc/nixos/hardware-configuration.nix`. On a fresh installation from the live ISO, the generated hardware file is normally at `/mnt/etc/nixos/hardware-configuration.nix`, so the installer exits even though the correct file exists.

The final command also differs by context:

- Installed system: `nixos-rebuild switch --flake /etc/nixos#default`
- Live installer target: `nixos-install --flake /mnt/etc/nixos#default`

## Approved Design

`install.sh` will resolve the NixOS configuration directory in this order:

1. Explicit `--nixos-dir PATH` or `ORGMOS_NIXOS_DIR`, if provided.
2. `/etc/nixos`, when `/etc/nixos/hardware-configuration.nix` exists.
3. `/mnt/etc/nixos`, when `/mnt/etc/nixos/hardware-configuration.nix` exists.
4. Manual prompt for a directory, when neither default location contains `hardware-configuration.nix`.

The resolved directory sets:

- `NIXOS_DIR`
- `FLAKE_PATH`
- `HARDWARE_PATH`
- install mode

Modes:

- `installed`: resolved path is not under `/mnt`; final command remains `sudo nixos-rebuild switch --flake "$NIXOS_DIR#default"`.
- `live`: resolved path is `/mnt/etc/nixos` or another `/mnt/...` path; final command becomes `sudo nixos-install --flake "$NIXOS_DIR#default"`.

`--dry-run` keeps current safety behavior: no write and no rebuild/install command execution. It should still show the resolved path and correct next command.

## Error Handling

If the chosen directory does not contain `hardware-configuration.nix`, the script prompts again for a valid directory instead of failing immediately.

If the user provides `--nixos-dir` with an invalid path in non-interactive mode, the script fails with a clear message.

## Testing

Add shell-level regression tests or scripted checks that prove:

1. Existing `/etc/nixos/hardware-configuration.nix` keeps installed mode and `nixos-rebuild` command.
2. Missing `/etc/nixos` plus existing `/mnt/etc/nixos/hardware-configuration.nix` selects live mode and `nixos-install` command.
3. Explicit `--nixos-dir` overrides autodetection.
4. Generated flake still imports `./hardware-configuration.nix` relative to the written flake.

## Scope

This change only fixes config directory resolution and final command selection. It does not change profile, GPU, kernel, hostname, flake structure, or hardware module semantics.
