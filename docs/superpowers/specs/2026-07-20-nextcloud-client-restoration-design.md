# Nextcloud Client Restoration Design

## Goal

Reverse the temporary Nextcloud desktop-client removal performed in commit `c5c71ba` and restore automatic startup in every desktop environment where it previously existed.

## Scope

Restore the exact package and autostart declarations removed by the temporary test:

- Install `nextcloud-client` from `nixos/common.nix`.
- Start Nextcloud from classic Hyprland.
- Start Nextcloud from Hyprland Caelestia.
- Start Nextcloud from the retained Niri startup configuration.
- Start Nextcloud from Labwc with its existing duplicate-process guard.

Do not introduce a new systemd service or change the previously proven launch commands.

## Implementation

Restore these declarations from the parent of commit `c5c71ba`:

```nix
nextcloud-client
```

```lua
"nextcloud --background",
```

in both Hyprland Lua autostart files.

Restore the Niri command:

```kdl
spawn-at-startup "nextcloud"
```

Restore the guarded Labwc command:

```sh
pgrep -u "$USER" -x nextcloud >/dev/null 2>&1 || nextcloud --background >/dev/null 2>&1 &
```

## Data Safety

Do not delete or modify:

- `~/Nextcloud` or synchronized files.
- Nextcloud account configuration, cache, credentials, or session state.
- AGE key paths under `~/Nextcloud`.
- Unrelated working-tree changes.

## Testing and Verification

Replace the temporary negative contract in `tests/nextcloud-client-disabled.bats.sh` with a positive restoration contract. The test must require:

- `nextcloud-client` in `nixos/common.nix`.
- Both Hyprland `nextcloud --background` entries.
- The Niri startup entry.
- The Labwc guarded startup entry.
- Existing AGE paths remain intact.

Then run:

1. The focused Nextcloud contract test.
2. Shell syntax checks for the test and Labwc autostart.
3. Lua syntax checks for both Hyprland autostart files when `luac` is available.
4. Nix evaluation for affected Hyprland configurations.
5. The active NixOS configuration build and `nh os switch`.
6. Runtime confirmation that `nextcloud` is available and starts after the next Hyprland login; an immediate guarded launch may be used to activate it in the current session.

## Files

- Modify: `nixos/common.nix`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua`
- Modify: `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua`
- Modify: `dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl`
- Modify: `dotfiles/config/profiles/labwc/.config/labwc/autostart`
- Modify: `tests/nextcloud-client-disabled.bats.sh`
