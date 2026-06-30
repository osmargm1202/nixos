# Code Context

## Files Retrieved
1. `flake.nix` (lines 1-199) - flake inputs and `nixosConfigurations` profile/host matrix.
2. `nixos/common.nix` (lines 1-229) - shared NixOS baseline, update behavior, global packages, user/session defaults.
3. `nixos/profiles/hyprland.nix` (lines 1-181) - current Hyprland system profile and package list.
4. `nixos/profiles/niri.nix` (lines 1-125) - example of importing a flake-provided NixOS module (`inputs.dms.nixosModules...`) and SDDM/theme setup.
5. `nixos/profiles/gnome.nix` (lines 1-31) - simple profile shape for contrast.
6. `nixos/hosts/{orgm,lenovo,ero}/plymouth.nix` (full files) and `nixos/hosts/lenovo/audio.nix` (full file) - host-specific extra modules used by `mkHost`.
7. `config/dotfiles.json` (lines 1-94) - dot.sh shared/host path ownership.
8. `dot.sh` (lines 1-220) - dotfile manager command shape and source/destination model.
9. `config/shared/.config/hypr/hyprland.lua` (lines 1-12) and `hyprland.conf` (lines 1-12) - active Lua config with legacy `.conf` fallback.
10. `config/shared/.config/hypr/lua/{programs,autostart,keybindings,look-and-feel,monitors,environment,input,layout,permissions,windows-workspaces}.lua` - current Hyprland behavior split by module.
11. `config/shared/.config/hypr/scripts/pi-walker-prompt.sh` (lines 1-37) and `walker-window-switch.sh` (lines 1-69) - existing Walker-aware scripts.
12. `config/shared/.local/bin/fuzzel-*`, `hypr-keybindings-help`, `waybar-hypr-dock` - current launcher/menu helper scripts.
13. `config/shared/.config/waybar-hypr/config` (lines 1-120, 230-280), `dock-apps.json` (lines 1-62), `style.css` (lines 1-80) - Hyprland bar/menu/dock integration.

## Key Code

### NixOS profile/import structure
- `flake.nix` defines `mkHost` and `mkProfile` helpers (lines 40-72). Both import `./nixos/common.nix`, hardware, a selected profile, and set `networking.hostName`.
- Generic profile configs exist for `gnome`, `hyprland`, `niri`, `labwc`, `labwc-light`, `sway`, `i3` (lines 75-93).
- Host-specific configs currently include:
  - `orgm-hyprland` at `flake.nix` lines 102-106.
  - `lenovo-hyprland` at lines 163-170.
  - No `ero-hyprland`; `ero` currently has `labwc`, `i3`, `sway` only (lines 127-143).
- Existing inputs include git Hyprland and hyprpaper (`flake.nix` lines 10-17), plus `snappy-switcher`, `caelestia-shell`, `dms`, `dgop`, and `sddm-astronaut-theme` (lines 18-35).
- There are no current `walker` or `elephant` matches in `flake.nix`, `flake.lock`, or `nixos/profiles/hyprland.nix`.

### Current Hyprland profile
`nixos/profiles/hyprland.nix`:
- Uses flake Hyprland packages from `inputs.hyprland.packages.${system}` and `inputs.hyprpaper.packages.${system}.hyprpaper` (lines 3-7).
- Disables X server/display manager and auto-starts Hyprland from fish on tty1 (lines 10-17).
- Enables `programs.hyprland` with upstream package and portal package (lines 19-24).
- Enables polkit, keyring, dbus, gvfs, portals, terminal exec, and MIME defaults (lines 26-98).
- Sets Wayland/Qt/GTK/cursor/session env vars (lines 100-117).
- Package stack includes Hyprland-native tools, `waybar`, `nwg-drawer`, `nwg-displays`, `nwg-look`, `kitty`, `fuzzel`, `libqalculate`, `yad`, `wlogout`, `swaynotificationcenter`, screenshot/clipboard tools, hardware controls, GNOME apps, and themes (lines 119-181).

### Hyprland dotfiles/features
- Hyprland prefers `hyprland.lua` and requires modules for monitors, programs, autostart, environment, permissions, look/layout/input/keybindings/window rules (`config/shared/.config/hypr/hyprland.lua` lines 1-12).
- Legacy `.conf` files still exist and are sourced by `hyprland.conf` (lines 1-12), but comment says Lua is preferred.
- Main programs are in `lua/programs.lua`: terminal `kitty`, file manager fallback to Nautilus/xdg-open, menu currently `fuzzel --prompt "Apps> "`, lock `hyprlock`, power menu `fish -c wlogout_uniqe`, display settings `nwg-displays`, distrobox command, and Pi prompt via fuzzel (lines 1-11).
- Autostart includes environment import, `graphical-session.target`, Waybar via `waybar-watch ~/.config/waybar-hypr`, `swaync`, applets, gnome-keyring, `hyprpolkitagent`, wallpaper daemon, Nextcloud, podman/docker containers, Discord, cliphist watchers, and `hypridle` (`lua/autostart.lua` lines 1-17).
- Keybindings include launcher/help/file/window/calc/SSH/tmux actions, display/power/lock/notifications/wallpaper/clipboard/media/screenshot/window/workspace controls (`lua/keybindings.lua` lines 1-118). Key launcher points:
  - `SUPER+Space` runs `programs.menu` (line 23).
  - `SUPER+M`, `SUPER+Ctrl+M`, `SUPER+Shift+M`, `SUPER+Escape`, `SUPER+Shift+T`, `SUPER+C`, `SUPER+D`, `SUPER+V` are fuzzel-backed helpers (lines 24-30, 38).
- Look-and-feel is Catppuccin-ish with gaps 12, borders, opacity, shadows, blur, and animations (`lua/look-and-feel.lua` lines 1-56).
- Input uses `us,latam`, ctrl-space layout toggle, numlock, 3-finger workspace gesture (`lua/input.lua` lines 1-19).
- Layout uses dwindle, master defaults, scrolling layout options, disables Hyprland logo (`lua/layout.lua` lines 1-20).
- Window rules set global and per-app opacity, utility floating/centered rules, modal floating, XWayland empty-class drag workaround (`lua/windows-workspaces.lua` lines 1-53).

### Current launcher/menu scripts
- Current central launcher is still fuzzel, not Walker:
  - `programs.menu = "fuzzel --prompt \"Apps> \""` in `lua/programs.lua` line 4.
  - Waybar menu clicks run `fuzzel` in `config/shared/.config/waybar-hypr/config` lines 35 and 251.
  - Many helper scripts call fuzzel directly: `fuzzel-open-file`, `fuzzel-open-file-dir`, `fuzzel-open-file-terminal`, `fuzzel-hypr-window`, `fuzzel-tmux-arch`, `fuzzel-calc`, `fuzzel-ssh-host`, clipboard binding, and `waybar-hypr-dock` line 88.
- Walker-aware scripts already exist but are not wired into keybindings:
  - `config/shared/.config/hypr/scripts/pi-walker-prompt.sh` uses `walker --dmenu` if available, then rofi fallback (lines 6-22), then launches Pi in kitty/distrobox (lines 24-37).
  - `config/shared/.config/hypr/scripts/walker-window-switch.sh` lists Hyprland clients and selects via Walker if available, rofi fallback otherwise (lines 1-69).
- `hypr-keybindings-help` is stale in places: it says `Win+D / Win+Space` Application Menu = `nwg-drawer`, while actual `SUPER+Space` uses fuzzel; it also mentions clipboard `nwg-drawer/fuzzel`.

## Architecture

- System configuration is split between NixOS profiles and dot.sh-managed home dotfiles.
- `flake.nix` owns reusable profile selection and multi-host combinations. Adding `hyprchy.nix` means adding a new profile file plus generic and host-specific `nixosConfigurations` entries, e.g. `hyprchy`, `orgm-hyprchy`, `lenovo-hyprchy`, and possibly `ero-hyprchy` if the user wants that host supported.
- `nixos/common.nix` is global for all profiles. It sets the flake path for `nh` and auto-upgrade, global packages, base services, user, fonts, and Nix settings. Avoid Hyprchy-specific packages here unless every profile should get them.
- `nixos/profiles/hyprland.nix` is the safest base for `hyprchy.nix` because it already preserves current Hyprland functionality. The new profile can either import/factor common Hyprland pieces or duplicate then evolve; factoring reduces drift but is a bigger planning task.
- Hyprland runtime behavior is mostly in `config/shared/.config/hypr/lua/*.lua` and shared helper scripts under `config/shared/.local/bin`. These are shared across all hosts and are already dot.sh-managed.
- Host-specific dotfiles currently live under `config/hosts/<host>` and are synced after shared paths. DankMaterialShell is host-scoped for `orgm`/`lenovo`; Hyprland config is shared.

## dot.sh implications

- `config/dotfiles.json` already tracks `.config/hypr`, `.config/waybar-hypr`, and `.local/bin` under `shared.paths` (lines 24, 44, 51). Changes to Hyprland Lua, Walker scripts/config under `.config/hypr`, Waybar Hypr config, and helper scripts under `.local/bin` will be synced to all hosts by `./dot.sh sync --host <host>`.
- If adding a new Walker config directory such as `config/shared/.config/walker`, it must be added to `config/dotfiles.json` under `shared.paths`; otherwise dot.sh will not sync it.
- If Elephant has per-user config/state that should be versioned, add it under `config/shared` or `config/hosts/<host>` and register the path. If it stores local runtime state/secrets, add to `local_only.paths` instead.
- Desktop launchers belong in `config/shared/.local/share/applications` if shared; that path is not currently in `shared.paths` except one individual `windows-rdp.desktop`. Full `.local/share/applications` is host-scoped for all hosts, so shared launcher additions need an explicit shared path or host copies.

## Likely files to change for the SDD plan

1. `flake.nix` - add git inputs for Walker and Elephant; add `hyprchy` generic config and host configs. Consider whether `ero-hyprchy` is required.
2. `flake.lock` - will update after adding git inputs.
3. `nixos/profiles/hyprchy.nix` - new profile, probably based on `hyprland.nix`, adding Walker/Elephant packages/modules and Omarchy-inspired defaults without regressing current services/packages.
4. Optional refactor: `nixos/profiles/hyprland-base.nix` or similar - only if avoiding duplicated Hyprland profile logic is worth the extra review load.
5. `config/shared/.config/hypr/lua/programs.lua` - set central launcher to Walker and update `piPrompt` to use existing Walker script or Walker dmenu.
6. `config/shared/.config/hypr/lua/keybindings.lua` - replace fuzzel-specific bindings with Walker equivalents where desired; wire existing `walker-window-switch.sh` and `pi-walker-prompt.sh` if they are the intended central flows.
7. `config/shared/.config/hypr/lua/autostart.lua` - add Elephant autostart if needed; ensure it does not conflict with Waybar/swaync/cliphist/hypridle.
8. `config/shared/.config/waybar-hypr/config` and possibly `waybar-hypr-dock` - switch menu clicks and multi-window picker from fuzzel to Walker or wrapper scripts.
9. `config/shared/.local/bin/*` - add wrapper scripts like `launcher`, `menu`, `clipboard-picker`, `window-switcher`, or migrate existing fuzzel scripts to Walker with fallback.
10. `config/shared/.config/walker/**` - likely new managed Walker config; add to `config/dotfiles.json`.
11. `config/dotfiles.json` - register new shared/host config paths.
12. `config/shared/.local/bin/hypr-keybindings-help` - update help text so it matches new Walker/Hyprchy bindings.

## Risks / constraints / open questions

- Walker and Elephant are not currently declared in Nix inputs or packages. Need confirm upstream repos/flake support/package attribute names before implementation.
- Current Hyprland profile uses latest upstream Hyprland git (`git+https://github.com/hyprwm/Hyprland?submodules=1`) and hyprpaper. Adding more git inputs increases flake update/build risk.
- `system.autoUpgrade` updates only `nixpkgs` and `home-manager`; new Walker/Elephant git inputs will stay locked unless `nix flake update` or explicit `--update-input` is used.
- Current Hyprland config uses Lua for Hyprland 0.55. Any Omarchy-inspired snippets from `.conf` syntax need translation or kept in legacy fallback carefully.
- Fuzzel is deeply embedded. Making Walker central is more than changing `programs.menu`; all dmenu helpers, Waybar clicks, clipboard picker, dock multi-window picker, and help text need a consistent migration or wrappers with fallback.
- Existing Walker scripts use `walker --dmenu -p`; verify this CLI matches the desired git Walker version.
- `hypr-keybindings-help` is already partly stale versus actual config, so it should not be treated as source of truth.
- `power_menu = "fish -c wlogout_uniqe"` looks possibly misspelled, but may be an existing fish function; preserve unless separately verified.
- Multi-host support: `orgm` and `lenovo` have Hyprland host entries; `ero` does not. Decide whether Hyprchy should support all three hosts or only hosts with current Hyprland entries.
- Host-scoped `.local/share/applications` can shadow shared desktop launchers; plan dot.sh path ownership before adding shared Walker/Elephant desktop files.
- I do not have callable Engram tools in this subagent environment, so I could not save discoveries to Engram despite the instruction.

## Start Here

Start with `nixos/profiles/hyprland.nix`: it is the current functional Hyprland system profile and the safest baseline for designing `nixos/profiles/hyprchy.nix` while preserving existing behavior. Then open `config/shared/.config/hypr/lua/programs.lua` and `keybindings.lua` to plan the Walker-centered launcher migration.
