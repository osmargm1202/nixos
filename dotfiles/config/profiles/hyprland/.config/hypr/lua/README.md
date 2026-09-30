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

## Visual profiles

`orgm-visual-profile` owns the runtime-only `slc`, `orgm`, and `osmar`
appearance state under `~/.local/state/orgm-visual-profile`. It generates the
Waybar, Kitty, borderless nwg-dock, borderless Dunst, and GTK outputs before
their session consumers start. Wallpapers for each profile live in
`~/Pictures/slc`, `~/Pictures/orgm`, and `~/Pictures/osmar`. Selecting a
profile restores its own saved wallpaper without overwriting it with the
previous profile's wallpaper. If none is saved, an image is selected from that
profile's folder; an empty folder keeps the current wallpaper.
The i3 profile consumes the same state and folders through i3bar, its main
menu, and `i3-wallpaper`; random selection is intentionally image-only.

Waybar and i3bar show `PERFIL: <ID> ▾`: left click opens the chooser and
right click toggles GTK light/dark mode. In i3, `Super+F12` → `Profile` opens
the same chooser, and `Super+Alt+w` chooses a random image from the active
profile folder. In Hyprland, the wallpaper icon performs that random selection.
