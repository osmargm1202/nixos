# Waybar and Dock Display Selection Design

## Goal

Make Waybar and `nwg-dock-hyprland` display placement portable across hosts without hardcoding monitor names in shared dotfiles. Each host should remember its preferred monitor behavior locally, detect known monitors when they return, and ask via rofi when a first-time choice is needed.

## Scope

In scope:

- Waybar output selection for `~/.config/waybar-hypr`.
- `hypr-nwg-dock` monitor/placement target selection where supported by `nwg-dock-hyprland`.
- Local-only persistence of monitor identity and user choices.
- A menu entry from `hypr-main-menu` to change display preferences.
- First-run or unknown-monitor prompting through the existing rofi helper style.

Out of scope:

- Full Hyprland monitor layout management.
- Replacing `nwg-displays`.
- Persisting mode, position, scale, transform, or rotation for Hyprland outputs.
- Changing workspace-to-monitor rules.

`nwg-displays` remains the tool for screen arrangement. This feature only decides where Waybar and dock appear.

## Current Problem

`config/shared/.config/waybar-hypr/config` currently has historically contained output-specific values such as `"output": "DP-3"`. That is correct for one host/layout, but wrong when the same shared config syncs to a laptop or another host whose active output is `eDP-1`, `HDMI-A-1`, or a different `DP-*` name.

Shared config should describe bar content and style. Local-only runtime config should decide actual outputs.

## Recommended Architecture

Add one shell helper:

```bash
hypr-display-targets
```

It owns monitor identity, local display preferences, and generated runtime config.

### Commands

```bash
hypr-display-targets ensure
hypr-display-targets menu
hypr-display-targets status
hypr-display-targets waybar-config CONFIG_DIR
hypr-display-targets dock-env
```

Responsibilities:

- `ensure`: detect current monitors, create local config if missing, and prompt via rofi if current setup needs a user choice.
- `menu`: interactive rofi menu for changing Waybar and dock display preferences.
- `status`: print current monitor identities and selected policy for debugging.
- `waybar-config CONFIG_DIR`: generate a runtime Waybar config with correct `output` fields, based on the shared source config and local policy.
- `dock-env`: print environment variables or CLI arguments for `hypr-nwg-dock`, if `nwg-dock-hyprland` supports targeting a monitor in the installed version.

## Local-only State

Store local state at:

```text
~/.config/orgm-hypr/display-targets.json
```

Add this path to `config/dotfiles.json` under `local_only.paths` so it is never synced from one host to another.

Example:

```json
{
  "version": 1,
  "waybar": {
    "mode": "primary",
    "selected": []
  },
  "dock": {
    "monitor": "primary"
  },
  "monitors": {
    "BOE 0x09DE": {
      "label": "Laptop",
      "primary": true
    },
    "LG Electronics LG 2K SERIAL": {
      "label": "LG 2K",
      "primary": false
    }
  }
}
```

### Monitor Identity

Build a stable monitor key from `hyprctl -j monitors` in this order:

1. `description` when present and specific.
2. combined `make + model + serial` if available.
3. current output name (`eDP-1`, `DP-3`, etc.) only as fallback.

Runtime output names may change across boots or ports. The saved monitor key should prefer hardware identity when Hyprland exposes it.

## Waybar Policy

Supported modes:

- `primary`: show Waybar only on the saved primary monitor. Default.
- `all`: show Waybar on all connected monitors by omitting `output` from generated config.
- `selected`: show Waybar only on selected saved monitors.

First-run behavior:

- If one monitor is connected, mark it primary and use `primary` mode without prompting.
- If multiple monitors are connected and no primary exists, show rofi prompt to select primary.
- If an unknown monitor is connected, record it with a generated label and optionally ask whether it should become primary or be included in selected Waybar outputs.

Generated config:

- Keep shared `config/shared/.config/waybar-hypr/config` free of hardcoded output names.
- Generate a runtime copy under:

```text
~/.cache/orgm-hypr/waybar/<profile>/config
```

- `waybar-watch` launches Waybar with the generated config and existing style file.

## Dock Policy

`hypr-nwg-dock` should read the same local state.

Supported targets:

- `primary`: dock follows saved primary monitor.
- a saved monitor key: dock appears on that monitor when connected.
- `focused` fallback if target monitor is absent or targeting is not supported by installed `nwg-dock-hyprland`.

If current `nwg-dock-hyprland` version does not expose a reliable monitor/output flag, keep behavior unchanged but still store the desired target for future support and show limitation in `hypr-display-targets status`.

## Menu Integration

Add `Displays` or `Waybar/Dock Displays` entry to `hypr-main-menu`.

Menu actions:

- Set primary monitor.
- Set Waybar mode: primary / all / selected.
- Choose selected Waybar monitors.
- Set dock target monitor.
- Show status/debug.
- Reset local display preferences.

Use existing `hypr-rofi-lib` for consistent rofi styling.

## Startup Flow

Update Hypr autostart to run:

```lua
"hypr-display-targets ensure && waybar-watch ~/.config/waybar-hypr",
"hypr-nwg-dock",
```

`ensure` should be fast and idempotent. It must not block startup forever if rofi fails or is unavailable. If prompting cannot run, it should choose safe fallback:

- one monitor: mark primary and continue.
- multiple monitors: use focused monitor or first focused Hyprland monitor as temporary primary, then continue.

## Error Handling

- If `hyprctl -j monitors` fails, generate config without output and launch Waybar on all outputs.
- If local JSON is corrupt, move it to `.bak-<timestamp>`, create a fresh config, and continue.
- If rofi is cancelled, keep current settings and exit successfully from menu mode; from startup mode, use safe fallback.
- If selected monitor is not connected, use primary; if primary is not connected, use focused/current monitor; if none detected, omit output.

## Testing

Automated tests:

- Parse sample `hyprctl -j monitors` output into stable monitor keys.
- First-run with one monitor creates primary without prompt.
- First-run with multiple monitors requests a selection in menu-capable mode.
- Waybar `primary` mode generates config with current output for saved monitor.
- Waybar `all` mode generates config without `output` fields.
- Waybar `selected` mode generates expected output-specific bars.
- Corrupt JSON backup and recovery.
- Unknown monitor merge behavior.
- `hypr-nwg-dock` fallback when output targeting is unavailable.

Manual checks:

- Laptop-only host starts Waybar on laptop panel.
- External monitor connected later: menu can make it primary.
- External monitor disconnected: Waybar falls back to laptop panel.
- Reconnected known external monitor uses saved policy.
- Main Hypr menu can reopen display preference menu.

## Migration

1. Remove hardcoded `output` fields from shared `waybar-hypr/config`.
2. Add local-only path `.config/orgm-hypr/display-targets.json`.
3. Add `hypr-display-targets` helper.
4. Update `waybar-watch` to use generated config.
5. Update `hypr-main-menu` to expose display preferences.
6. Update `hypr-nwg-dock` to read display target if supported.
7. Keep `nwg-displays` bindings unchanged.

## Non-goals and Guardrails

- Do not write host-specific monitor names into shared Waybar config.
- Do not sync local monitor choices between hosts.
- Do not silently rewrite full Hyprland monitor layout.
- Do not require `orgm-hypr` Go binary for basic Waybar startup; shell fallback must remain enough to show a bar.
