# Skwd-wall migration design

## Goal

Replace Waytrogen and the legacy Hyprland wallpaper flow with `skwd-wall` and `skwd-daemon` in the classic `hyprland` profile. Skwd becomes the only component that restores and applies desktop wallpapers.

## Scope

This change applies only to `nixos/profiles/hyprland.nix` and its matching dotfiles under `dotfiles/config/profiles/hyprland`.

The `hyprlandqs-caelestia` profile is outside scope. Its current uncommitted wallpaper-picker changes and all unrelated Herdr state must remain untouched.

## Package and module integration

Add `github:osmargm1202/skwd-wall` as a flake input. Import `inputs.skwd-wall.nixosModules.default` from the classic Hyprland profile and enable:

```nix
programs.skwd-wall.enable = true;
```

The module supplies the `skwd-wall` selector, the `skwd` CLI, the `skwd-daemon` executable, and its user service. Remove `waytrogen` from the Hyprland system packages. Do not enable Skwd in the Caelestia profile.

Because this changes a flake input and a NixOS module, deployment uses `nh os switch`. The repository `flake.lock` must remain aligned with the dotfiles repository head.

## Session startup and ownership

The classic Hyprland profile adds `skwd-daemon.service` to `graphical-session.target` declaratively. Hyprland autostart does not launch the daemon or any wallpaper helper.

The daemon restores its saved wallpaper automatically after its initial scan. Automatic 30-minute rotation is intentionally no longer started at login; users can select or start wallpaper behavior through Skwd itself.

Startup must not use `hypr-skwd-wall-start`, `waytrogen`, `hypr-random-wallpaper`, direct `hyprctl hyprpaper` commands, or a second wallpaper daemon.

## User interaction

The Waybar `custom/wallpaper` module has one action:

- Left click: `skwd wall toggle`

Remove the legacy right-click picker action. Update both duplicate `custom/wallpaper` definitions in the current Waybar configuration so they cannot diverge.

Hyprland shortcuts become:

- `Win+Alt+W`: `skwd wall toggle`
- `Win+Shift+W`: `chromium`

The old wallpaper picker must not remain bound to either shortcut.

## Legacy removal

Remove the legacy automatic controller `hypr-random-wallpaper` from the classic Hyprland profile and remove its autostart calls.

Remove the old classic-profile wallpaper selector from the active flow, including its Waybar action, keybinding, launchers, and picker implementation. Tests and menus that advertise those legacy commands must be removed or updated to use Skwd.

Keep `hypr-current-wallpaper` only as a lockscreen bridge. It does not apply desktop wallpapers and therefore does not compete with Skwd.

## Lockscreen synchronization

`skwd-daemon` maintains a lock-ready image at:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall/wallpaper/current.jpg
```

`hypr-current-wallpaper` points `$XDG_RUNTIME_DIR/hypr-current-wallpaper` to that file whenever it exists. If Skwd has not produced the file yet, it points to the existing fallback image. `hypr-lock` continues to refresh this link immediately before launching Hyprlock, so static, video-preview, and Wallpaper Engine-preview selections remain synchronized with the lockscreen.

## Error handling

- systemd restarts `skwd-daemon.service` on failure without blocking Hyprland startup.
- The selector remains callable when the daemon is unavailable; Skwd reports the service error directly.
- A missing Skwd `current.jpg` leaves Hyprlock on the existing fallback image.
- No wallpaper source file is deleted during migration.

## Verification

Automated checks cover:

1. The Hyprland profile imports and enables the Skwd module and no longer installs Waytrogen.
2. `graphical-session.target` wants `skwd-daemon.service` declaratively.
3. Hyprland autostart invokes no wallpaper daemon or helper, and `hypr-skwd-wall-start` is absent.
4. Both Waybar wallpaper definitions launch `skwd wall toggle` and contain no legacy right-click action.
5. `Win+Alt+W` toggles Skwd and `Win+Shift+W` launches Chromium.
6. The lockscreen bridge prefers Skwd `current.jpg` and preserves its fallback.
7. Legacy picker and random-wallpaper tests are removed or replaced so the suite protects the new ownership model.
8. Shell syntax checks, focused Bats tests, Nix evaluation, `nix flake check`, `git diff --check`, and diagnostics pass.
9. `nh os switch` succeeds, followed by runtime checks for `systemctl --user status skwd-daemon.service`, Waybar launch, and Hyprlock background resolution.

## Out of scope

- Enabling Skwd in `hyprlandqs-caelestia`.
- Restoring automatic wallpaper rotation at login.
- Adding videos or Wallpaper Engine scenes to automatic rotation.
- Redesigning Skwd itself or changing the external repositories.
- Deleting user wallpapers or Skwd runtime data.
