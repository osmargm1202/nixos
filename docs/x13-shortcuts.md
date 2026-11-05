# X13 GNOME shortcuts

These shortcuts apply to Osmarg on X13 only. They use native GNOME Shell window
activation on Wayland; they do not depend on favorites order or X11 tools.

| Shortcut | Action |
| --- | --- |
| Super+Q | Close the active window through GNOME's window-manager binding; not logout |
| Super+Return | Focus GNOME Console, or open it if absent |
| Super+W | Focus Firefox, or open it if absent; no extra tab/window when one exists |
| Super+E | Focus Files (Nautilus), or open it if absent |

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

After deployment and the next graphical login, check all four shortcuts, with
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
