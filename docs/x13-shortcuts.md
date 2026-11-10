# X13 GNOME shortcuts

These shortcuts apply to Osmarg on X13 only. They use native GNOME Shell window
activation on Wayland; they do not depend on favorites order or X11 tools.

| Shortcut | Action |
| --- | --- |
| Super+Q | Close the active window through GNOME's window-manager binding; not logout |
| Super+Return | Focus GNOME Console, or open it if absent |
| Super+W | Focus Firefox, or open it if absent; no extra tab/window when one exists |
| Super+E | Focus Files (Nautilus), or open it if absent |
| Super+L | Lock the screen through GNOME’s native screensaver binding |

The focus extension selects the app's most recently used window, including a
minimized window or one on another workspace. GNOME activates/restores that
window. If no window exists, it activates the app unless the app is already
STARTING. Disabling the extension unregisters its three bindings.

## Activation and acceptance

Home Manager installs `x13-focus-shortcuts@orgm.local` and its compiled schema.
At graphical login, `x13-focus-shortcuts.service` merges this UUID into the current
GNOME enabled list and removes it from the disabled list. Other manual extension
choices and their order are preserved. The only retired enabled UUID is
`gnome-ui-tune@itstime.tech`: the locked Gnome 4x UI Improvements release 25
supports Shell 45–49, while X13 selects Shell 50.5. Other hosts are unchanged.

**First installation requires the next logout/login for Shell discovery.** Nothing
forces logout, restarts Shell, changes unsafe mode or bypasses Shell guards.
The current session may not discover a newly installed extension. Existing manual
shortcut conflicts may still require inspection in the real session.

X13 now selects GDM: GNOME 50’s native screen shield and Lock menu require its
D-Bus service. The host wrapper omits the shared SDDM module while retaining
printing. Home Manager enables locking and declares Super+L; the Server
specialisation explicitly disables GDM. Thunar is excluded from X13’s common
package selection; Nautilus remains the directory default.

For this display-manager migration, use `nh os boot` and reboot when ready;
closing the existing SDDM session alone does not activate the new manager.
A live switch can terminate the old session even when dry activation says the
changed display-manager unit will not stop: its new GDM D-Bus name requirement
can trigger a systemd restart. This occurred on X13 during the user-requested
2026-11-07 switch; GDM is now running and a new Wayland login was observed.
After boot, verify the Lock menu, Super+L, and password unlock physically.

After deployment and the next graphical login, check the app shortcuts, with
Firefox both absent and already open, repeated presses during app startup, and
minimized/other-workspace windows. Runtime keyboard acceptance is still pending;
the automated JavaScript tests exercise the shipped callbacks with Shell stubs,
not a live compositor. Missing desktop IDs are ignored rather than launching an
unrelated fallback.

X13 also masks the Syncthing and Tailscale tray autostarts and omits Syncthing
Tray's package. Syncthing's independent user service and the Tailscale daemon
remain enabled. The existing shared retirement helper archives old launchers
before Home Manager replaces them with masks; it does not remove application data.

## Configuration checks

```sh
node tests/x13-focus-shortcuts.test.js
python3 tests/x13-trays.test.py
python3 tests/x13.test.py
python3 tests/x13-server.test.py
```

Sources: `nixos/hosts/x13/focus-shortcuts.nix`, its `focus-shortcuts/` directory,
`nixos/hosts/x13/gnome.nix`, `nixos/common.nix` and `nixos/common-dotfiles.nix`.

## Native application menus on GNOME

GNOME paths in Osmarg's desktop scripts now use `orgm-menu` (Zenity) for remote
selection, masked RDP password entry, Firefox URL entry, bookmarks and visual
profiles. Other desktops keep their Rofi paths. The GNOME video timer uses a
GTK duration prompt and keeps the current workspace. Visual profiles use native
GSettings for wallpaper and light/dark preferences. Selected bookmarks copy
exact text to the clipboard; paste with Ctrl+V instead of synthetic typing.

Clipboard scripts reuse the already-enabled Clipboard Indicator, including its
native selection/deletion UI. They do not read cliphist or start another history
collector in GNOME. `orgm-clipboard-menu` asks the X13 shortcut extension to open
the existing indicator; the bridge is disabled on lock/greeter screens and never
returns history content. **The first update of this integration requires your
next logout/login.** Until then, use the indicator in the top bar. No session
restart is forced by deployment.

GTK menus support list selection, zero-based row IDs for remote selectors,
free-text entry, masked password entry and cancellation. They deliberately
implement only the options used by these scripts; unsupported Rofi options fail.
Rofi remains installed for compatibility.

Checks: `python3 tests/gnome-menus.test.py`,
`node tests/x13-focus-shortcuts.test.js`, existing Firefox/remote-client/visual
profile regressions and X13 Normal/Server tests. Actual GTK entry, list selection
and cancellation were also exercised in an isolated Xvfb display. Real endpoint
connections and the post-login native clipboard menu still require user checks.
