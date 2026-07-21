# Discord and Vesktop WebRTC IP Policy Design

## Goal

Ensure every managed launch path for Discord and Vesktop uses Chromium's WebRTC IP handling policy:

```text
--force-webrtc-ip-handling-policy=default_public_and_private_interfaces
```

This addresses Discord calls that remain stuck during DTLS negotiation while Tailscale is enabled. Vesktop has an upstream patch using the equivalent Electron API value, `default_public_and_private_interfaces`; this design uses the command-line policy instead so both clients share one mechanism without maintaining a source patch.

## Scope

The policy applies to every desktop profile that installs Vesktop. A dedicated profile module will own Vesktop, Discord launch integration, and the policy. Currently both `hyprland` and `hyprlandqs-caelestia` receive it through `common_hyprland.nix`.

Terminal-only and server profiles will not install these graphical clients. A future desktop profile that needs Vesktop must import the dedicated module.

The guarantee covers managed commands, desktop launchers, and Hyprland Discord autostart. A user can still bypass it deliberately by running the raw Flatpak command or a binary directly from `/nix/store`.

## Architecture

### Shared Vesktop desktop module

Create `nixos/profiles/vesktop.nix` and import it from `nixos/profiles/common_hyprland.nix`.

The module defines one policy constant and provides:

1. A lightweight `symlinkJoin` package over `pkgs.vesktop`.
2. A `wrapProgram` wrapper around `bin/vesktop` that adds the policy flag.
3. A `discord` command that launches `com.discordapp.Discord` through Flatpak with the same policy.
4. A Home Manager desktop entry named `com.discordapp.Discord.desktop` that shadows Flatpak's exported launcher and invokes the managed `discord` command.

`common_hyprland.nix` removes the raw `vesktop` package from its package list. Importing `vesktop.nix` becomes the only supported way for a desktop profile to install Vesktop.

### Vesktop launch flow

```text
application launcher or terminal
  -> vesktop
  -> Nix wrapper
  -> upstream Vesktop/Electron with WebRTC policy
```

The wrapped package retains Vesktop's icons and desktop file. Because the raw package is no longer installed directly, both terminal and desktop launches resolve to the wrapper.

### Discord launch flow

```text
application launcher, terminal, or autostart
  -> managed discord command
  -> flatpak run com.discordapp.Discord with WebRTC policy
```

The wrapper preserves all caller arguments, including `--start-minimized` and URL arguments. It detects an already supplied WebRTC policy flag and does not add a duplicate.

The Home Manager desktop entry uses the same Flatpak desktop ID, so it takes precedence over the exported Flatpak entry while preserving its icon and desktop identity.

### Hyprland autostart compatibility

Update `dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord` so every direct fallback includes the policy. Resolution order remains:

1. `discord`
2. `Discord`
3. `flatpak run com.discordapp.Discord`

This supports the managed wrapper after rebuild and remains safe during transition or if a native executable is used later.

## Error Handling

- The Discord wrapper verifies that Flatpak and `com.discordapp.Discord` are available before launching. Missing dependencies produce a concise error on stderr and a non-zero exit.
- Arguments are forwarded without shell re-parsing.
- The autostart helper exits successfully when no supported Discord installation exists, preserving current login behavior.
- Vesktop relies on Nix build-time wrapper construction; a missing wrapped executable fails the build rather than producing a broken runtime launcher.

## Testing and Verification

Implementation follows test-driven development:

1. Add failing checks for the policy constant, Vesktop wrapper, Discord argument forwarding/deduplication, desktop launcher, and autostart fallback commands.
2. Implement the minimum Nix and shell changes to pass them.
3. Run shell syntax validation for `hypr-start-discord`.
4. Evaluate the `orgm-hyprland` and `orgm-hyprlandqs-caelestia` configurations.
5. Build the active NixOS configuration.
6. Run `nh os switch`, required because a NixOS module and Home Manager desktop entry change.
7. Confirm `command -v vesktop`, `command -v discord`, and the effective `Exec=` line in `~/.local/share/applications/com.discordapp.Discord.desktop` resolve to managed launchers.
8. Perform a manual Discord/Vesktop call with Tailscale enabled and confirm DTLS connects.

## Files

- Create: `nixos/profiles/vesktop.nix`
- Modify: `nixos/profiles/common_hyprland.nix`
- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord`
- Add or modify focused tests under `tests/`

## Non-Goals

- Maintaining the open Vesktop source patch.
- Replacing Discord Flatpak with the Nixpkgs Discord package.
- Intercepting deliberate raw invocations that bypass managed commands.
- Installing Vesktop on terminal-only or server profiles.
