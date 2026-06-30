# Spec: hyprchy

## Status

specified

## Requirements

### REQ-1: New profile

The system SHALL provide a new NixOS profile at `nixos/profiles/hyprchy.nix`.

#### Scenario: profile does not replace Hyprland

- Given existing `nixos/profiles/hyprland.nix`
- When `hyprchy.nix` is added
- Then `hyprland.nix` remains available and unchanged except for intentional shared refactors approved by design.

### REQ-2: Git Walker and Elephant inputs

The flake SHALL use git/flaked versions of Walker and Elephant.

#### Scenario: compatibility pinning

- Given Walker depends on Elephant protocol/provider compatibility
- When inputs are added
- Then Walker and Elephant revisions are pinned together through `flake.lock` and documented input relationships.

### REQ-3: Multi-host outputs

The flake SHALL expose `hyprchy` outputs for multiple hosts.

#### Scenario: host matrix

- Given hosts `orgm`, `lenovo`, and `ero`
- When `hyprchy` support is implemented
- Then `flake.nix` exposes at least `orgm-hyprchy` and `lenovo-hyprchy`
- And `ero-hyprchy` is either implemented or explicitly deferred with reason.

### REQ-4: Preserve current Hyprland behavior

The new profile SHALL preserve the functional behavior of the existing Hyprland profile unless intentionally changed by the launcher migration.

#### Scenario: core desktop capabilities

- Given current Hyprland profile supports portals, keyring, polkit, dbus, gvfs, MIME defaults, Wayland env vars, screenshot/clipboard tools, Waybar, swaync, hyprlock, hypridle, hyprpaper, and applets
- When `hyprchy.nix` is built
- Then equivalent capabilities remain installed/configured.

### REQ-5: Walker central launcher

Walker SHALL be the central launcher entry point for the new system.

#### Scenario: primary binding

- Given user presses `SUPER+SPACE`
- When running Hyprchy session
- Then Walker opens as launcher.

#### Scenario: current launcher paths

- Given fuzzel is currently embedded in Hypr Lua, Waybar, and helper scripts
- When launcher migration is applied
- Then common launcher actions use Walker or a wrapper that prefers Walker and has safe fallback.

### REQ-6: Elephant provider service

Elephant SHALL run as the backend provider service for Walker.

#### Scenario: service startup

- Given user enters Hyprchy session
- When Walker starts
- Then Elephant is started as a user-session service or equivalent user process before Walker needs provider data.

#### Scenario: conservative providers

- Given Elephant file provider can cause CPU/inotify risk
- When first implementation is applied
- Then providers start conservative: desktop apps, provider list, runner, calc, websearch, menus, and optionally clipboard/windows only after validation.

### REQ-7: Managed dotfiles

Walker and Elephant config managed by this repo SHALL be registered in `config/dotfiles.json`.

#### Scenario: new config dir

- Given `config/shared/.config/walker` or `config/shared/.config/elephant` is added
- When dot.sh sync is expected to manage it
- Then corresponding paths exist in `config/dotfiles.json`.

### REQ-8: Validation evidence

Implementation SHALL record strict TDD-style evidence.

#### Scenario: RED

- Given `orgm-hyprchy` does not exist before implementation
- When running `nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link`
- Then it fails for missing attribute or missing profile before implementation.

#### Scenario: GREEN

- Given implementation complete
- When running configured validation commands
- Then `nix flake check` and focused `orgm-hyprchy` build pass or documented environment blockers are recorded.

#### Scenario: compatibility

- Given current Hyprland profile must be preserved
- When running `nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link`
- Then it still passes or unrelated blockers are documented.
