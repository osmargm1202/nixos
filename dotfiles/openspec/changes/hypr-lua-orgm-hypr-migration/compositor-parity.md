# Slice 3 compositor parity checklist

Scope: validate compositor-local Hyprland behavior through Lua while retaining
split `.conf` fallback files and every shell entrypoint.

## Keybindings parity

- Lua owner: `config/shared/.config/hypr/lua/keybindings.lua`.
- Fallback: `config/shared/.config/hypr/70-keybindings.conf`.
- Compatibility entrypoints retained: all `~/.local/bin/hypr-*`,
  `~/.local/bin/fuzzel-*`, `*-osd`, and Waybar helpers referenced by binds.
- Confirmed no script deletion or caller cleanup in this slice.
- Parity adjustment: fallback now includes `SUPER+ALT+Space` control center bind
  through `$control_center`, matching existing Lua `programs.control_center` and
  `keybindings.lua` behavior.

Smoke checklist for host runtime:

| Binding domain | Example binds | Expected action |
|---|---|---|
| Help/menu | `SUPER+/`, `SUPER+Space`, `SUPER+ALT+Space` | Help/menu/control-center wrappers open. |
| Launcher/file tools | `SUPER+A`, `SUPER+M`, `SUPER+SHIFT+M` | Existing shell wrappers run; no Lua blocking flow added. |
| Scratchpad | `SUPER+S`, `SUPER+SHIFT+S`, `SUPER+CTRL+S` | Special workspace toggle/move behavior preserved. |
| Media/OSD | XF86 audio/brightness keys | Existing OSD wrappers run with same args. |
| Window controls | `SUPER+Q`, `SUPER+F`, `SUPER+SHIFT+Space` | Close/fullscreen/float dispatches behave as before. |
| Focus/move | arrows and `h/j/k/l` variants | Focus and window move directions preserved. |
| Workspaces | number/Home/Page binds | Workspace focus/move behavior preserved. |
| Mouse | `SUPER+mouse:272/273` | Drag/resize behavior preserved. |

## Monitor, input, look/layout parity

- Lua owners: `monitors.lua`, `input.lua`, `look-and-feel.lua`, `layout.lua`.
- Fallbacks: `00-monitors.conf`, `60-input.conf`, `50-look-and-feel.conf`,
  `55-layout.conf`.
- Parity adjustment: fallback `55-layout.conf` now includes the Lua `scrolling`
  block so rollback/fallback preserves current layout behavior.

Host runtime checklist:

| Domain | Expected action |
|---|---|
| Monitor | Preferred mode, auto position, scale `1`. |
| Input | `us,latam` layouts, `altgr-intl`, Ctrl+Space layout toggle, numlock on. |
| Gestures | 3-finger horizontal workspace gesture. |
| Look | gaps/borders/rounding/shadow/blur/opacity match Lua and fallback. |
| Layout | dwindle preserve split, master status, scrolling settings, misc wallpaper/logo settings. |

## Window/workspace rules parity

- Lua owner: `windows-workspaces.lua`.
- Fallback: `80-windows-workspaces.conf`.
- Existing Lua and fallback both keep opacity rules, utility-window float/size/center
  rules, modal floating, and empty XWayland no-focus workaround.
- Discord remains normal; no forced scratchpad behavior.

Host runtime checklist:

| Rule domain | Expected action |
|---|---|
| Opacity | Global opacity plus terminal/browser overrides apply. |
| Utilities | Calculator, pavucontrol, blueman, network editor, nwg-displays, File Roller float/center/size. |
| Modal windows | Modal windows float. |
| XWayland empty class | Empty floating XWayland drag helper does not steal focus. |

## Runtime blockers

- `nix flake check` blocked in current runtime if `nix` is unavailable.
- `orgm-dot diff --host orgm` and `dot.sh diff --host orgm` may be blocked by
  unavailable/broken local wrappers in this runtime.
- Manual Hyprland reload is deferred to host verification; this apply slice only
  made static parity adjustments and documentation.
