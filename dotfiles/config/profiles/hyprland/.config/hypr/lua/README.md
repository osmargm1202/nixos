# Hyprland Lua foundation

This directory contains the canonical Hyprland 0.55 Lua configuration modules.
Legacy split hyprlang `.conf` fallback files have been removed; keep Hyprland
behavior changes in these Lua modules.

## Entrypoint order

`../hyprland.lua` loads modules in this order:

1. `lua.monitors`
2. `lua.programs`
3. `lua.autostart`
4. `lua.environment`
5. `lua.permissions`
6. `lua.look-and-feel`
7. `lua.layout`
8. `lua.input`
9. `lua.keybindings` with the `programs` table
10. `lua.windows-workspaces`

Keep this order deterministic. Put shared external command names in
`programs.lua`; pass them into modules instead of duplicating paths.

`lua.autostart` loads ScrollOverview first at `hyprland.start`. Its plugin load
reloads the configuration; `lua.look-and-feel` then configures it only when
`hl.plugin.scrolloverview` is available.

## Module contract

- Lua modules must be fast to load and safe during compositor startup/reload.
- Long-running or interactive work should call small scripts in `~/.local/bin`
  instead of embedding large shell pipelines in Lua.
- High-cost startup helpers should call focused shell scripts directly (for
  example, `orgm-dot`).
- Do not add new `orgm-hypr` calls; that umbrella command is retired.
- Modules must be idempotent across reloads. Hyprland re-evaluates them on
  every reload and reads back values it already exported, so accumulating
  variables such as `PATH` must be rebuilt without repeats; every process
  launched from the session inherits the result.

## Users, programs and activation

`nixos/users/osmarg.nix` and `nixos/users/jarq.nix` select program integrations,
Flatpak application IDs and web application IDs independently. Host modules
retain hardware and boot configuration; selecting i3 does not select Osmarg's
personal applications.

Dotfiles are composed in this precedence order (later layers win):

1. Enabled `dotfiles/config/programs/<program>` layers.
2. `dotfiles/config/profiles/<profile>`.
3. `dotfiles/config/users/<user>/common`.
4. Enabled `dotfiles/config/users/<user>/programs/<program>` overrides.
5. `dotfiles/config/users/<user>/profiles/<profile>`.
6. Host hardware overrides, shared and then profile-specific.

The resulting sources are immutable Nix-store paths. Editing or pulling the
repository does not change an active configuration; a rebuild and activation
are required. Generated appearance state remains mutable in the user's home.
Disabling a program removes its managed dotfile links, not unrelated regular
files or application data.

For i3, Home Manager initializes Thunar's shared sort preference to modification
date, newest first. Per-folder view settings are disabled so old folder metadata
does not override that order; no Nautilus replacement is needed.
`bash tests/i3-thunar-sort.bats.sh` exercises the actual Home Manager loader
and Thunar in an isolated D-Bus/Xvfb session, including conflicting old folder
metadata and an Xfconf daemon restart.
Applying the user preferences is separate from activating NixOS:
`programs.xfconf.enable` needs a system switch for persistent D-Bus activation;
an existing session without that service cannot be repaired just by changing
the client's `XDG_DATA_DIRS`.

Shared modules and `flake.lock` still determine the next rebuild. To maintain
an independently tested Jarq release, deploy a fixed repository revision
(including its lock file), rather than automatically following `master`.
The `jarq` alias selects `jarq-i3`; explicit alternative profile outputs remain.

Personal startup commands, menus and bindings live in Osmarg's user-profile
overrides. Jarq retains Tailscale and Nextcloud without inheriting Osmarg's API
keys, RDP credentials, gaming clients or private infrastructure indicators.
The VPN is selected by `tailscale`; peer-change monitoring and notifications
also require Osmarg's private `orgm` integration.


The Hyprland configuration editor opens the editable checkout's shared profile,
not the active store files. Set `HYPR_CONFIG_EDITOR_ROOT` to the user's
Hyprland source directory to edit personal overrides. The checkout must exist;
it is no longer cloned or updated automatically during boot.

## Visual profiles

For Osmarg, `orgm-visual-profile` owns the runtime-only `slc`, `orgm`, and `osmar`
appearance state under `~/.local/state/orgm-visual-profile`. It generates the
Waybar, Kitty, borderless nwg-dock, borderless Dunst, and GTK outputs before
their session consumers start. Wallpapers for each profile live in
`~/Pictures/slc`, `~/Pictures/orgm`, and `~/Pictures/osmar`. Selecting a
profile restores its own saved wallpaper without overwriting it with the
previous profile's wallpaper. If none is saved, an image is selected from that
profile's folder; an empty folder keeps the current wallpaper.
Osmarg's i3 overrides consume the same state and folders through i3bar, its
main menu, and `i3-wallpaper`; random selection is intentionally image-only.

Waybar and i3bar show `PERFIL: <ID> ▾`: left click opens the chooser and
right click toggles GTK light/dark mode. In i3, `Super+F12` → `Profile` opens
the same chooser, and `Super+Alt+w` chooses a random image from the active
profile folder. In Hyprland, the wallpaper icon performs that random selection.
