# Tasks: hyprchy

## Status

lightweight_apply_complete_no_real_build

## Review forecast

Likely over 400 changed lines if all done at once. Use chained implementation slices.

## Slice 1: Flake/profile foundation

Goal: create buildable `hyprchy` profile with Walker/Elephant inputs while preserving current Hyprland.

### RED

- [ ] Run:
  ```bash
  nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link
  ```
- [ ] Record expected missing attribute/profile failure.

### GREEN

- [x] Add Walker and Elephant git inputs to `flake.nix`.
- [x] Pin Walker/Elephant relationship, preferably `walker.inputs.elephant.follows = "elephant"`.
- [x] Create `nixos/profiles/hyprchy.nix` from current Hyprland baseline.
- [x] Add `hyprchy` generic profile output.
- [x] Add `orgm-hyprchy`, `lenovo-hyprchy`, and `ero-hyprchy` host outputs unless unsafe.
- [x] Update `flake.lock`.
- [ ] Run after explicit build approval:
  ```bash
  nix flake check
  nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link
  nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link
  ```

## Slice 2: Walker/Elephant config and services

Goal: make Walker/Elephant installed and session-started conservatively.

### RED

- [ ] Verify `walker`/`elephant` are not currently available in `hyprchy` before config addition, or record Nix eval failure for missing package attrs.

### GREEN

- [x] Add Walker/Elephant packages or modules to `hyprchy.nix`.
- [x] Add managed Walker config if needed: `config/shared/.config/walker/**`.
- [x] Add managed Elephant config/menus if needed: `config/shared/.config/elephant/**`.
- [x] Add `.config/walker` and `.config/elephant` to `config/dotfiles.json` when files are managed.
- [x] Start Elephant as user session service/process before Walker.
- [x] Start Walker service or bind direct `walker` launch.
- [x] Keep fuzzel installed as fallback.

### Validation

- [ ] Run `nix flake check`.
- [ ] Run `nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link`.
- [ ] Run `./dot.sh diff --host orgm`.

## Slice 3: Central launcher migration

Goal: make Walker central across Hypr Lua, Waybar, and scripts.

### RED

- [ ] Document current fuzzel references from `programs.lua`, `keybindings.lua`, Waybar config, and helper scripts.

### GREEN

- [x] Add launcher wrapper(s) under `config/shared/.local/bin`.
- [x] Keep current `programs.lua` unchanged; add `hyprchy-programs.lua` so only Hyprchy uses Walker/wrapper.
- [x] Update Hyprchy keybindings for launcher, window switcher, Pi prompt, calc, clipboard, and app/file actions where safe.
- [x] Wire existing `pi-walker-prompt.sh` and `walker-window-switch.sh`.
- [x] Keep current Waybar unchanged; add `waybar-hyprchy` for Hyprchy launcher/menu/TUI clicks.
- [x] Update `hypr-keybindings-help` so help matches actual bindings.

### Validation

- [ ] Run `./dot.sh diff --host orgm`.
- [ ] Run `nix flake check` if Nix files changed.
- [ ] Manual after sync/session: `SUPER+SPACE` opens Walker; apps appear; runner/calc/websearch/providerlist work; logs have no Elephant waiting loop.

## Slice 4: Omarchy-like custom menus

Goal: add custom Elephant menus for system actions.

### GREEN

- [x] Add conservative menus under `config/shared/.config/elephant/menus`.
- [x] Include actions for power/session, NixOS rebuild/eval helper, dot.sh status/diff, Pi prompt, and logs.
- [x] Avoid heavy file provider until explicitly tested.

### Validation

- [ ] Walker shows custom menu provider.
- [ ] Actions run expected commands.
- [ ] CPU/RAM remain normal after idle.

## Final verify

- [ ] `nix flake check`
- [ ] `nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link`
- [ ] `nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link`
- [ ] `nix build .#nixosConfigurations.lenovo-hyprchy.config.system.build.toplevel --no-link`
- [ ] `nix build .#nixosConfigurations.ero-hyprchy.config.system.build.toplevel --no-link` if `ero-hyprchy` added
- [ ] `./dot.sh diff --host orgm`
- [ ] Manual session smoke test after user-approved sync/switch.

## Slice 5: Hyprchy Waybar/TUI layer

Goal: separate Hyprchy Waybar from current Hyprland and wire TUI clicks.

### GREEN

- [x] Add `config/shared/.config/waybar-hyprchy/config` and `style.css`.
- [x] Add `.config/waybar-hyprchy` to `config/dotfiles.json`.
- [x] Launch `waybar-watch ~/.config/waybar-hyprchy` from `hyprchy-autostart.lua`.
- [x] Add `hyprchy-bluetooth`, `hyprchy-network`, and `hyprchy-audio` wrappers.
- [x] Add Hyprchy TUI packages: `bluetui`, `pulsemixer`, `networkmanager`, `impala`, `iwmenu`.
- [x] Route fuzzel helper selections through `hypr-dmenu` so Walker is used only when `HYPRCHY=1`, with fuzzel fallback preserved.

### Validation

- [x] `jq empty config/dotfiles.json`
- [x] JSONC parse `waybar-hyprchy/config`
- [x] `bash -n` changed scripts
- [x] `luac -p` Hyprchy Lua files
- [x] `nix eval` system names and package attrs through host Nix
- [ ] Manual session smoke test after user-approved sync/switch.

## Apply recommendation

Lightweight apply is complete. Next safe step is final user-approved build/switch and manual smoke test, or split the large diff into reviewable commits before building.
