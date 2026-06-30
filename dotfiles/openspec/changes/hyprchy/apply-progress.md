# Apply Progress: hyprchy

## Slice 1: flake/profile foundation

### Status

lightweight_green

### Changes made

- Added flake inputs:
  - `systems`
  - `elephant` from `github:abenz1267/elephant`
  - `walker` from `github:abenz1267/walker`
- Pinned Walker to the shared Elephant input with `walker.inputs.elephant.follows = "elephant"`.
- Added new profile: `nixos/profiles/hyprchy.nix`.
- Added NixOS outputs:
  - `hyprchy`
  - `orgm-hyprchy`
  - `lenovo-hyprchy`
  - `ero-hyprchy`
- Updated `flake.lock` with Walker/Elephant/system inputs.

### RED evidence

Initial container-local RED command could not run because the distrobox does not have `nix`:

```text
nix: command not found
```

Host Nix is available through `distrobox-host-exec`. Before staging the new profile for flake evaluation, `orgm-hyprchy` failed because the flake source did not include the untracked new file:

```text
error: path '.../nixos/profiles/hyprchy.nix' does not exist
```

### GREEN evidence

Host Nix eval works through `distrobox-host-exec`.

```bash
nix eval .#nixosConfigurations.orgm-hyprchy.config.system.name
# "orgm"

nix eval .#nixosConfigurations.lenovo-hyprchy.config.system.name
# "lenovo"

nix eval .#nixosConfigurations.ero-hyprchy.config.system.name
# "ero"
```

`orgm-hyprchy` dry-run evaluates and plans Walker/Elephant builds:

```text
these 22 derivations will be built:
  ... elephant-providers-2.21.0.drv
  ... elephant-with-providers-2.21.0.drv
  ... walker-2.16.2.drv
  ... nixos-system-orgm-25.11.20260505.0c88e1f.drv
```

`orgm-hyprland` dry-run completed without errors.

LSP diagnostics:

- `flake.nix`: no diagnostics
- `nixos/profiles/hyprchy.nix`: no diagnostics

### Known blockers / caveats

- User requested no real builds or `nix flake check` until the final step after system instability; use lightweight eval/lint only unless explicitly approved.
- `mkProfile` was adjusted to use repo-local eval-only `nixos/hosts/generic/hardware-configuration.nix` for pure generic profile evaluation instead of `/etc/nixos/hardware-configuration.nix`, but full `nix flake check` remains deferred.
- Full build was not completed in-session; dry-run/eval evidence only.
- New profile file had to be added with `git add -N` so Nix's git flake source would include it for eval.

## Slice 2: Walker/Elephant config and service bootstrap

### Status

lightweight_green

### Changes made

- Enabled Walker through `programs.walker` in `nixos/profiles/hyprchy.nix`.
- Configured Walker's Elephant backend provider set through `programs.walker.elephant.providers`.
- Kept runtime Walker config owned by dot.sh (`~/.config/walker`) to avoid two active config sources.
- Added managed dotfile paths to `config/dotfiles.json`:
  - `.config/elephant`
  - `.config/walker`
- Added shared Walker config: `config/shared/.config/walker/config.toml`.
- Added shared Elephant config: `config/shared/.config/elephant/elephant.toml`.
- Added custom Elephant menu: `config/shared/.config/elephant/menus/hyprchy_system.lua`.
- Added optional launcher wrapper: `config/shared/.local/bin/hypr-launcher`.
- Added `HYPRCHY=1` profile marker and user services for Elephant/Walker in `hyprchy.nix`.
- Preserved current shared Hyprland launch/autostart/program/keybinding files unchanged; Hyprchy-specific behavior lives in separate `hyprchy.lua` overlay files.

### Lightweight validation

```text
bash -n config/shared/.local/bin/hypr-launcher: ok
bash -n config/shared/.local/bin/hyprchy-tui: ok
jq empty config/dotfiles.json: ok
nix eval .#nixosConfigurations.orgm-hyprchy.config.system.name: "orgm"
nix eval .#nixosConfigurations.lenovo-hyprchy.config.system.name: "lenovo"
nix eval .#nixosConfigurations.ero-hyprchy.config.system.name: "ero"
nix eval .#nixosConfigurations.hyprchy.config.system.name: "nixos"
nix eval .#nixosConfigurations.orgm-hyprchy.config.environment.sessionVariables.HYPRCHY: "1"
LSP diagnostics flake.nix: none
LSP diagnostics nixos/profiles/hyprchy.nix: none
LSP diagnostics nixos/hosts/generic/hardware-configuration.nix: none
```

### Caveats

- No real builds were run by user request.
- No `dot.sh sync` was run.
- Walker/Elephant runtime menu behavior still needs manual session smoke test after final build/switch.

## Startup correction: start-hyprland

### Status

lightweight_green

### Web verification

- Hyprland current docs say Hyprland can be launched from TTY with `start-hyprland`.
- Hyprland docs say config path can be supplied with `--config` / `-c`.
- Recent Hyprland discussion/NixOS issue confirms the warning "Hyprland was started without start-hyprland" is caused by launching the `Hyprland` binary directly.
- `start-hyprland` accepts Hyprland args after `--`; docs mention `start-hyprland -- -h` for launch flags.

### Changes made

- Updated current `nixos/profiles/hyprland.nix` TTY startup:
  - prefer `exec start-hyprland`
  - fallback to `exec Hyprland` if wrapper is unavailable.
- Updated `nixos/profiles/hyprchy.nix` TTY startup:
  - export `HYPRCHY=1`
  - prefer `exec start-hyprland -- --config "$HOME/.config/hypr/hyprchy.lua"`
  - fallback to `exec Hyprland --config "$HOME/.config/hypr/hyprchy.lua"`.

### Lightweight validation

```text
nix eval orgm-hyprland fish loginShellInit contains exec start-hyprland: ok
nix eval orgm-hyprchy fish loginShellInit contains start-hyprland -- --config: ok
nix eval orgm-hyprchy fish loginShellInit contains Hyprland --config fallback: ok
```

### Caveat

No real build/switch was run by user preference.

## Slice 3: Hyprchy-specific launcher/keybinding overlay

### Status

lightweight_green

### Changes made

- Kept current Hyprland config stack unchanged.
- Added `config/shared/.config/hypr/hyprchy.lua`, same module stack as `hyprland.lua` but using Hyprchy overlays.
- Added `config/shared/.config/hypr/lua/hyprchy-programs.lua` to override only launcher/prompt commands.
- Added `config/shared/.config/hypr/lua/hyprchy-autostart.lua` as Hyprchy-specific autostart; it keeps current session daemons but launches `waybar-hyprchy`.
- Added `config/shared/.config/hypr/lua/hyprchy-keybindings.lua` with same bindings as current Hyprland plus Hyprchy changes:
  - `SUPER+Space` uses Walker launcher wrapper.
  - `SUPER+Escape` uses Walker window switcher.
  - `SUPER+V` uses `hypr-dmenu` adapter.
  - `SUPER+CTRL+H` opens `hyprchy-tui`.
- Updated `hyprchy.nix` login startup to export `HYPRCHY=1` and prefer `start-hyprland -- --config "$HOME/.config/hypr/hyprchy.lua"`.
- Added `config/shared/.local/bin/hypr-dmenu` and `config/shared/.local/bin/hyprchy-tui` as new helper/TUI tools.

### Lightweight validation

```text
luac -p hyprland.lua: ok
luac -p hyprchy.lua: ok
luac -p hyprchy-programs.lua: ok
luac -p hyprchy-autostart.lua: ok
luac -p hyprchy-keybindings.lua: ok
bash -n hyprchy-tui/hypr-dmenu/hypr-launcher: ok
nix eval orgm-hyprchy fish loginShellInit contains hyprchy.lua: ok
star/start hyprland references: none found
current Hyprland launch now prefers: exec start-hyprland
Hyprchy launch is separate: exec start-hyprland -- --config ~/.config/hypr/hyprchy.lua
```

### Caveats

- No real builds were run by user request.
- No `dot.sh sync` was run.
- Need final switch/smoke test to confirm Hyprland accepts the Lua config path through `-c`.

## Static review fixes

### Status

lightweight_green

### Changes made

- Made `config/shared/.local/bin/hyprchy-tui` executable because Hyprchy keybindings run it through Kitty.
- Added `hyprchy.lua`, `hyprchy-autostart.lua`, `hyprchy-keybindings.lua`, `hyprchy-programs.lua`, and `hyprchy-tui` as intentional tracked files.
- Updated `walker-window-switch.sh` to use `hypr-dmenu` first, then gated Walker/fuzzel/rofi fallbacks, so legacy Hyprland `.conf` users do not need Walker installed.
- Re-applied Waybar/help/program updates so direct fuzzel menu entries are removed except explicit fallback paths.

### Lightweight validation

```text
bash -n all changed launcher/helper scripts: ok
new Hyprchy scripts executable: ok
jq empty config/dotfiles.json: ok
TOML parse for walker/elephant configs: ok
nix eval orgm-hyprchy/lenovo-hyprchy/ero-hyprchy/hyprchy system names: ok
stale direct fuzzel UI refs grep: none
```

### Next

Clean review artifacts and decide final validation/commit strategy. Real builds and `nix flake check` remain final-step only.

## Slice 4: Hyprchy Waybar/TUI layer and Walker-safe helpers

### Status

lightweight_green

### Changes made

- Added managed Hyprchy Waybar profile:
  - `config/shared/.config/waybar-hyprchy/config`
  - `config/shared/.config/waybar-hyprchy/style.css`
- Added `.config/waybar-hyprchy` to `config/dotfiles.json`.
- Updated `hyprchy-autostart.lua` to launch `~/.local/bin/waybar-watch ~/.config/waybar-hyprchy` instead of current shared `waybar-hypr` profile.
- Added Hyprchy Waybar click wrappers:
  - `hyprchy-bluetooth`: `kitty -e bluetui`, fallback `blueman-manager`.
  - `hyprchy-network`: `kitty -e nmtui`, fallback `iwgtk`, then `nm-connection-editor`.
  - `hyprchy-audio`: `kitty -e pulsemixer`, fallback `pavucontrol`.
- Hyprchy Waybar clicks now use:
  - menu/logo -> `hypr-launcher` / Walker under `HYPRCHY=1`.
  - bluetooth -> `hyprchy-bluetooth`.
  - network -> `hyprchy-network`.
  - audio -> `hyprchy-audio`.
  - system/help -> `kitty --class hyprchy-tui -e hyprchy-tui`.
- Added Hyprchy-only TUI packages to `hyprchy.nix`:
  - `bluetui`
  - `pulsemixer`
  - `networkmanager` for `nmtui`
  - `impala`
  - `iwmenu`
- Migrated existing fuzzel helper scripts to route selections through `hypr-dmenu`, preserving fuzzel fallback outside Hyprchy while allowing Walker under `HYPRCHY=1`.

### Lightweight validation

```text
jq empty config/dotfiles.json: ok
JSONC parse config/shared/.config/waybar-hyprchy/config: ok
bash -n hypr-dmenu/hypr-launcher/hyprchy-* helpers/fuzzel-* helpers/waybar-hypr-dock: ok
luac -p hyprchy.lua/hyprchy-autostart.lua/hyprchy-keybindings.lua/hyprchy-programs.lua: ok
nix eval orgm-hyprchy environment.systemPackages length: ok
LSP diagnostics hyprchy.nix: none
LSP diagnostics hyprland.nix: none
```

### Caveats

- No real builds or switches were run by user preference.
- `impala`/`iwmenu` are installed as available network TUI options, but Waybar currently prefers `nmtui` because it is stable with NetworkManager.
- Runtime smoke test still needed after final switch.

### Next

Run fresh static review, then final build/switch only when user approves.

## Runtime smoke fix: PATH and Elephant startup

### Status

runtime_bugfix_lightweight_green

### Root cause evidence

- Running Hyprchy session had `HYPRCHY=1`, Hyprland, and `waybar-hyprchy` active.
- `waybar-hyprchy.log` showed click commands failing with `command not found` for `hypr-launcher`, `hyprchy-bluetooth`, `hyprchy-network`, and `hyprchy-audio`.
- `systemctl --user start graphical-session.target` is refused on this NixOS session (`Operation refused, unit graphical-session.target may be requested by dependency only`), so `hyprchy-elephant.service` and `hyprchy-walker.service` stayed inactive.
- Manually starting `hyprchy-elephant.service` then `hyprchy-walker.service` worked; Walker/Elephant processes became active.

### Changes made

- `hyprchy-autostart.lua` now starts `hyprchy-elephant.service` and `hyprchy-walker.service` explicitly instead of trying to start `graphical-session.target`.
- `hyprchy-programs.lua` uses `~/.local/bin/hypr-launcher` so `SUPER+Space` does not depend on PATH containing `~/.local/bin`.
- `waybar-hyprchy/config` uses absolute `~/.local/bin/hypr-*` commands for launcher/audio/bluetooth/network clicks.
- fuzzel helper scripts and `walker-window-switch.sh` call `$HOME/.local/bin/hypr-dmenu` explicitly.
- Clipboard keybinding calls `$HOME/.local/bin/hypr-dmenu` explicitly.

### Lightweight validation

```text
JSONC parse waybar-hyprchy/config: ok
luac -p hyprchy autostart/programs/keybindings: ok
bash -n changed helper scripts: ok
remaining unqualified Waybar custom commands: none
remaining bare hypr-dmenu command refs: only help text
```
