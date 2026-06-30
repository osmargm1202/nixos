# Proposal: hyprchy

## Status

proposed

## Problem

Current Hyprland profile works, but launcher/menu behavior is fragmented around fuzzel, helper scripts, Waybar clicks, and stale help text. User wants a NixOS system similar to Omarchy that uses Walker and Elephant as the menu/data layer, without destroying the existing Hyprland profile.

## Goals

- Add new NixOS profile: `nixos/profiles/hyprchy.nix`.
- Use git/flaked Walker and Elephant sources.
- Pin Walker and Elephant together to reduce protocol drift.
- Make Walker the central launcher for apps, runner, calc, web search, provider list, windows, clipboard, and custom system actions where practical.
- Support multiple hosts through `flake.nix` host/profile entries.
- Preserve current `hyprland.nix` behavior and existing Hyprland dotfiles.
- Keep implementation reviewable and reversible.

## Non-goals

- Do not replace or delete `nixos/profiles/hyprland.nix`.
- Do not clone Omarchy wholesale.
- Do not enable heavy Elephant file indexing in first slice unless explicitly validated.
- Do not move all desktop/session config to Home Manager unless required by Walker/Elephant module support.
- Do not change unrelated profiles like GNOME, Niri, Labwc, Sway, or i3.

## Scope

### NixOS flake

- Add Walker and Elephant git inputs.
- Configure input relationship so Walker follows/pins Elephant intentionally.
- Add `hyprchy` profile config and multi-host outputs.

### Profile

- Create `nixos/profiles/hyprchy.nix` from the working Hyprland baseline.
- Preserve portals, keyring, dbus, gvfs, MIME defaults, environment variables, Hyprland/hyprpaper packages, and current Wayland tooling.
- Add Walker/Elephant package/module/service integration.

### Dotfiles

- Add managed Walker config under `config/shared/.config/walker/**` if needed.
- Add managed Elephant config/menus under `config/shared/.config/elephant/**` if needed.
- Register new paths in `config/dotfiles.json`.
- Update Hyprland Lua launcher bindings/wrappers so Walker is central.
- Update Waybar launcher clicks and help text.

## Delivery strategy

Recommended chained slices if implementation exceeds 400 changed lines:

1. Flake/profile foundation: inputs, `hyprchy.nix`, host outputs, build validation.
2. Walker/Elephant user-session config: services, config dirs, conservative providers.
3. Launcher migration: Hypr Lua keybindings, Waybar clicks, wrappers, help text.
4. Optional Omarchy-like custom menus and richer providers.

## Acceptance summary

- Existing `orgm-hyprland` build still evaluates/builds.
- New `orgm-hyprchy` build evaluates/builds.
- Multi-host `hyprchy` outputs exist for selected hosts.
- Walker launches from `SUPER+SPACE`.
- Elephant service starts before or alongside Walker.
- Current core Hyprland behavior remains available.

## Risks

- Upstream git changes can break reproducibility until lockfile is pinned.
- Walker/Elephant service integration may work better through Home Manager than pure NixOS modules.
- Some current fuzzel scripts may need wrapper migration instead of direct replacement.
