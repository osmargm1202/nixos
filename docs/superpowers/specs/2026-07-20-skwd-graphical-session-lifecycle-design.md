# SKWD Graphical Session Lifecycle Design

## Problem

`skwd-daemon.service` is installed correctly and `graphical-session.target` wants it, but the direct SDDM → Hyprland session never activates `graphical-session.target`. After login:

- `graphical-session.target` is `inactive (dead)`;
- `skwd-daemon.service` is `inactive (dead)`;
- the unit has no boot journal entries;
- the saved wallpaper is not restored.

A manual `systemctl --user start skwd-daemon.service` starts the existing unit and restores the saved wallpaper on both `eDP-1` and `HDMI-A-1`. The daemon and restore logic are therefore healthy; session lifecycle activation is the failing boundary.

## Goals

- Activate the standard user `graphical-session.target` once Hyprland has exported its Wayland environment.
- Let the existing target dependency start and supervise `skwd-daemon.service`.
- Restore the saved SKWD wallpaper automatically at graphical login.
- Preserve the SKWD package, unit, restart policy, selector entry points, and wallpaper state.

## Non-goals

- Replacing SKWD or modifying its daemon.
- Enabling UWSM.
- Starting SKWD from `default.target` before Wayland is available.
- Reintroducing the removed `hypr-skwd-wall-start` helper.
- Changing HDMI, GuC, monitor, NVIDIA, or wallpaper-selection configuration.

## Considered Approaches

### 1. Activate `graphical-session.target` after environment import — selected

Chain the existing `hypr-session-import-env` startup command with `systemctl --user start graphical-session.target`. This preserves standard systemd lifecycle semantics and starts every unit already declared for the graphical session, including SKWD.

### 2. Start only `skwd-daemon.service` from Hyprland

This restores the wallpaper but duplicates the declarative target dependency and leaves the standard graphical target inactive. Rejected because it fixes one symptom rather than the session boundary.

### 3. Attach SKWD to `default.target`

This is fully declarative but may start before Hyprland exports `WAYLAND_DISPLAY` and related variables. Rejected because the daemon creates Wayland surfaces and should start only after the graphical environment exists.

## Selected Design

In `autostart.lua`, replace the standalone environment-import command with one shell transaction:

```text
hypr-session-import-env && systemctl --user start graphical-session.target
```

Ordering is explicit:

1. Hyprland starts.
2. `hypr-session-import-env` copies Wayland/session variables into the systemd user manager and D-Bus activation environment.
3. Only after that command succeeds, systemd activates `graphical-session.target`.
4. The existing target `Wants=skwd-daemon.service` starts the packaged SKWD unit.
5. SKWD reads `last-wallpaper.json` and restores the saved wallpaper.

The existing declaration in `nixos/profiles/hyprland.nix` remains:

```nix
systemd.user.targets.graphical-session.wants = [ "skwd-daemon.service" ];
```

The daemon remains owned by systemd with its packaged `Restart=on-failure` behavior. Hyprland does not launch the daemon process directly.

## Error Handling

- Environment import remains tolerant of unavailable variables, as implemented by `hypr-session-import-env`.
- A target or daemon failure remains visible through `systemctl --user status` and `journalctl --user`.
- No retry loop or duplicate process guard is added; systemd owns retries and idempotency.
- Re-running target start is safe because systemd target activation is idempotent.

## Testing

### Contract tests

Update focused tests to assert:

- environment import precedes target activation in one startup command;
- Hyprland starts `graphical-session.target`, not `skwd-daemon.service` directly;
- the obsolete bootstrap helper remains absent;
- the NixOS profile still wires SKWD into `graphical-session.target`.

The new assertion must fail against the current implementation before production code changes.

### Build and runtime verification

- Run focused SKWD and Hyprland autostart contracts.
- Run shell/Lua diagnostics and formatting checks.
- Build `lenovo-hyprland` completely.
- Deploy without restarting Hyprland.
- Simulate a fresh graphical target transaction by stopping SKWD/target, importing the live environment, and starting `graphical-session.target`.
- Confirm target and daemon become active, SKWD logs `auto-restored wallpaper`, and `skwd-paper-still` owns surfaces for `eDP-1` and `HDMI-A-1`.
- Confirm no duplicate daemon processes.
- Verify automatic startup after the next normal login or reboot.

## Rollback

Remove the graphical-target activation from Hyprland autostart and switch to the previous generation. The existing SKWD state and package remain unchanged.
