# Slice 6 menu and webapp characterization

## Scope decision

- Menu wrappers stay as scripts in Slice 6. They are blocking `rofi` flows with direct `exec` actions; moving them to Go would add review churn without safer runtime parity.
- `orgm-hypr smart-run` gets a pure parser and print-safe command surface only. Existing `hypr-smart-run` script remains runtime entrypoint.
- Webapp maker/remover stay deferred. Creation writes launcher, desktop, icon, browser profile state; remover can delete profile data with `rm -rf`. Do not migrate destructive behavior until filesystem and prompt flows are fully tested.

## Menu wrappers inventory

| Wrapper | Caller / prompt | Items and actions | Dependencies | Cancel path | Slice 6 decision |
|---|---|---|---|---|---|
| `hypr-main-menu` | Keybind / dock launcher, prompt `Hyprland` | Apps → `rofi -show drun`; Tools → `hypr-tools-menu`; Performance → `hypr-performance-menu`; WiFi → `hypr-wifi-menu`; Bluetooth → `hypr-bluetooth-menu`; Search → `hypr-smart-run`; Keybinds → `hypr-keybindings-help`; System → `hypr-system-menu`; Reload Dock → `hypr-nwg-dock reload`; Power → `hypr-power-menu`; Keyboard → `hypr-keyboard-menu`; Web App Maker → `hypr-webapp-maker`; Quit | `rofi`, shell, `HYPR_BIN_DIR`, optional env file | Quit or empty exits 0 | Retained. Top-level blocking menu and compatibility entrypoint. |
| `hypr-tools-menu` | Main menu, prompt `Tools` | Terminal → `kitty`; Files → `nautilus`; Search files → `fuzzel-open-file`; Calculator → `gnome-calculator`; Displays → `nwg-displays`; Wallpaper next → `orgm-hypr wallpaper next` | `rofi`, listed apps | unmatched/empty exits 0 | Retained. Simple interactive launcher glue. |
| `hypr-performance-menu` | Main menu, prompt `Performance` | Adds available `btop`, `htop`, `dgop`, GNOME System Monitor; runs terminal tools in `kitty`; GUI monitor direct | `rofi`, `command -v`, optional tools | Cancel exits 0 | Retained. Dynamic availability depends on host PATH. |
| `hypr-wifi-menu` | Main menu, prompt `WiFi` | NetworkManager GUI → `nm-connection-editor`; nmtui → `kitty -e nmtui` | `rofi`, NetworkManager tools, `kitty` | unmatched/empty exits 0 | Retained. Interactive system tooling. |
| `hypr-bluetooth-menu` | Main menu, prompt `Bluetooth` | Bluetooth GUI → `blueman-manager`; bluetui → `kitty -e bluetui` | `rofi`, bluetooth tools, `kitty` | unmatched/empty exits 0 | Retained. Interactive system tooling. |
| `hypr-keyboard-menu` | Main menu, prompt `Keyboard` | Toggle layout → `hyprctl switchxkblayout all next`; US → `... all 0`; Latam → `... all 1` | `rofi`, `hyprctl` | unmatched/empty exits 0 | Retained. Small wrapper; possible future pure action model. |
| `hypr-power-menu` | Main menu / keybinding, prompt `Power` | Lock → `hypr-lock`; Suspend/Hibernate/Reboot/Power off → `systemctl`; Logout → `hyprctl dispatch exit` | `rofi`, optional env file, `awk`, `systemctl`, `hyprctl` | unmatched/empty exits 0 | Retained. Potentially disruptive system actions; no Go migration without manual parity. |
| `hypr-keybindings-help` | Main menu / keybinding, prompt `Atajos Hyprland` | Categories: Todos, Launchers, Tools, Ventanas, Workspaces, Media, Sistema, Salir. Entries list key, description, command; selection copies via `wl-copy` or notifies | `rofi`, optional env file, `wl-copy`, `notify-send` | empty category exits 0; Salir exits 0; empty entry returns to categories | Retained. Data could later move to pure model, but markup/copy UI remains script-owned for now. |

## Smart-run characterization

Current `hypr-smart-run` behavior captured in `internal/smartrun` parser tests:

- trims surrounding whitespace;
- opens `http://` / `https://` directly in browser;
- prefixes `localhost:*` and `127.0.0.1:*` with `http://`;
- `!a` launches `Chatgpt.desktop` after copying stripped query when `wl-copy` exists;
- `!c` launches `Claude.desktop` after copying stripped query when `wl-copy` exists;
- `!g` builds Google search URL by replacing spaces with `+`;
- `!y` builds YouTube search URL by replacing spaces with `+`;
- single executable word runs as command when found on PATH;
- single domain-like word/path opens as `https://...`;
- fallback launches `Chatgpt.desktop` with full query;
- empty input exits/no-ops.

`orgm-hypr smart-run parse QUERY...` and `orgm-hypr smart-run run QUERY... --print` expose print-safe plans. Live GUI/browser execution remains with existing `hypr-smart-run` wrapper.

## Webapp maker/remover characterization

### `hypr-webapp-maker`

Inputs and prompts:

1. `App name` rofi prompt; empty cancels with exit 0.
2. `URL` rofi prompt defaulting to `https://`; empty cancels with exit 0; missing scheme gets `https://`.
3. Existing desktop file asks overwrite; negative answer notifies cancellation and preserves files.
4. Browser picker selects installed Chromium-compatible browser: `chromium`, `brave`, `brave-browser`, or `flatpak:com.brave.Browser`.
5. Icon download tries origin `/favicon.ico`, then Google favicon service; fallback asks `Logo URL/path`; if unavailable uses `chromium` icon.

Writes and side effects:

- Creates `${XDG_DATA_HOME:-~/.local/share}/applications/$slug.desktop`.
- Creates launcher under `.../hypr/webapps/bin/hypr-webapp-$slug`.
- Creates browser profile path under `.../hypr/webapps/profiles/$slug` when launcher runs.
- Writes/copies icon under `${XDG_DATA_HOME:-~/.local/share}/icons/$slug.png` when possible.
- Runs `update-desktop-database` best-effort.
- Sends notify-send success/failure notifications.

Deferral rationale: network fetch, prompt flow, generated shell launcher, desktop escaping, icon writes, and overwrite behavior require focused fake filesystem/process tests before any Go migration.

### `hypr-webapp-remover`

Discovery:

- Scans `$apps_dir/*.desktop` for `X-Hypr-WebApp=true`.
- Presents rows as `Name — URL`.
- No apps found sends notification and exits 0.

Deletion choices:

- Cancel/empty exits 0.
- `Remove launcher only`: removes desktop file and safe launcher only when `Exec=` exactly matches expected state-dir launcher.
- `Remove launcher and profile data`: also removes `state_dir/profiles/$slug` with `rm -rf`.

Deferral rationale: profile deletion is destructive and depends on parsing `Exec`, slug derivation, and rofi confirmation. Slice 6 does not implement deletion behavior because it is not fully testable in current scope.

## Rollback

- Keep all menu and webapp scripts unchanged.
- If `orgm-hypr smart-run` parser is wrong, stop using the new subcommand; `hypr-smart-run` still owns live behavior.
- Cleanup and caller migration remain Slice 7+ only after parity evidence.
