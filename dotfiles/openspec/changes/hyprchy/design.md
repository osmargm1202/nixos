# Design: hyprchy

## Status

designed

## Architecture decision

Create `nixos/profiles/hyprchy.nix` as a new profile based on current `hyprland.nix` behavior. Do not replace `hyprland.nix`. Start with duplication plus small, explicit additions rather than a broad shared-base refactor. Refactor later only if drift becomes painful.

Reason: preserving working Hyprland behavior matters more than deduplicating during first integration.

## Flake inputs

Add inputs similar to:

```nix
walker = {
  url = "github:abenz1267/walker";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.elephant.follows = "elephant";
};

elephant = {
  url = "github:abenz1267/elephant";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Final attribute names must be verified against upstream flakes during apply.

## Profile structure

`nixos/profiles/hyprchy.nix` should:

- preserve current Hyprland profile settings;
- use `inputs.hyprland.packages.${system}.hyprland` and portal package like existing profile;
- add Walker and Elephant packages/modules from flake inputs;
- keep current Wayland desktop package stack initially, including fuzzel as fallback;
- add only Hyprchy-specific packages/config here, not in `nixos/common.nix`.

## Service/config placement

Preferred first implementation:

- NixOS profile installs packages and enables session prerequisites.
- Home Manager module support may be used if already available through `home-manager.users.osmarg` in this repo. If not straightforward, use managed dotfiles plus Hyprland `exec-once` for user services.
- Elephant runs in user session, not system service.
- Walker starts as gapplication service or direct launcher. Use direct `walker` binding first; socket launch can be optimized after reliability.

## Multi-host matrix

Add flake outputs:

- `hyprchy` generic profile via `mkProfile "hyprchy"`.
- `orgm-hyprchy` via `mkHost "orgm" "hyprchy"`.
- `lenovo-hyprchy` via `mkHost "lenovo" "hyprchy"`.
- `ero-hyprchy` only if host hardware/profile assumptions are safe. If omitted, document follow-up because user requested multi-host.

Recommended: include `ero-hyprchy` if `mkHost "ero" "hyprchy"` follows existing host pattern without extra modules.

## Launcher migration

Introduce wrappers to avoid hardcoding Walker everywhere:

- `hypr-launcher`: opens Walker.
- `hypr-window-switch`: uses existing `walker-window-switch.sh` or new wrapper.
- `hypr-pi-prompt`: uses existing `pi-walker-prompt.sh`.
- Optional wrappers for calc, clipboard, SSH, tmux, files.

Then update:

- `config/shared/.config/hypr/lua/programs.lua`
- `config/shared/.config/hypr/lua/keybindings.lua`
- `config/shared/.config/waybar-hypr/config`
- `config/shared/.local/bin/waybar-hypr-dock`
- `config/shared/.local/bin/hypr-keybindings-help`

Keep fuzzel installed as fallback until Walker is proven.

## Walker config

Add managed config only if upstream defaults are not enough:

- `config/shared/.config/walker/config.toml`
- `config/shared/.config/walker/themes/**` if theme customization is needed.

Default provider strategy:

- desktopapplications
- providerlist
- runner
- calc
- websearch
- menus
- clipboard/windows after validation
- defer files provider by default because of Omarchy CPU/inotify reports.

## Elephant config

Add managed config/menus:

- `config/shared/.config/elephant/elephant.toml`
- `config/shared/.config/elephant/desktopapplications.toml`
- `config/shared/.config/elephant/calc.toml`
- `config/shared/.config/elephant/menus/*.lua` or TOML menus.

Use custom menus for Omarchy-like system actions:

- theme/menu refresh
- power/session actions
- NixOS rebuild helpers
- dot.sh status/diff helpers
- Pi launcher/prompt actions

## dot.sh integration

If new config paths are added, update `config/dotfiles.json` shared paths:

- `.config/walker`
- `.config/elephant`

Run:

```bash
./dot.sh diff --host orgm
```

Only run sync after user approval during apply.

## Validation plan

RED:

```bash
nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link
```

Expected fail before implementation.

GREEN:

```bash
nix flake check
nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link
```

Compatibility:

```bash
nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link
```

Multi-host:

```bash
nix build .#nixosConfigurations.lenovo-hyprchy.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.ero-hyprchy.config.system.build.toplevel --no-link
```

Dotfiles:

```bash
./dot.sh diff --host orgm
```

## Rollback

- Boot/select existing `orgm-hyprland` profile.
- Remove/disable `hyprchy` flake outputs if needed.
- Restore launcher commands to fuzzel wrappers if Walker/Elephant fail.
- Keep fuzzel installed during first implementation for fallback.

## Review workload

Likely >400 lines if done in one patch. Prefer chained delivery.
