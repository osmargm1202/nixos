# Deskflow launcher environment fix design

## Goal

Make the shared Deskflow user service start the installed Flatpak reliably on the `lenovo` and `orgm` hosts instead of entering a restart loop.

## Root cause

The generated launcher resets `XDG_RUNTIME_DIR` before running `systemctl --user show-environment`. Because `XDG_RUNTIME_DIR` is exported in the inherited user-manager environment, assigning an empty value passes an empty runtime directory to `systemctl`. The command cannot connect to the user bus, but `2>/dev/null || true` hides that failure. The parser receives no display or runtime values, waits 30 seconds, exits with failure, and systemd restarts it.

The installed Deskflow Flatpak is already the latest stable release, version 1.26.0. Refreshing Flathub metadata and running a download-only update reported `Nothing to do`.

## Scope

- Modify only the shared launcher in `nixos/deskflow.nix`.
- Apply the behavior to both hosts that import the module: `lenovo` and `orgm`.
- Preserve the current Flatpak application ID, retry count, systemd restart policy, and host selection.
- Add focused regression coverage for launcher environment handling.
- Do not switch Deskflow to a beta or continuous release.
- Preserve unrelated working-tree changes.

## Launcher flow

Each retry performs these operations in order:

1. Call `systemctl --user show-environment` before clearing any inherited environment variable needed to reach the user bus.
2. Reset the local parsed values for `WAYLAND_DISPLAY`, `DISPLAY`, and `XDG_RUNTIME_DIR`.
3. Parse those values from the captured user-manager environment.
4. Accept either a Wayland or X11 display only when `XDG_RUNTIME_DIR` is present and its `bus` path is a Unix socket.
5. Export the parsed values so the final Flatpak process receives them.
6. Execute `flatpak run org.deskflow.deskflow`.

If the environment is not ready, the launcher sleeps one second and retries. After 30 unsuccessful attempts it exits non-zero, retaining the existing `Restart=on-failure` behavior.

## Testing

Add `tests/deskflow-launcher.bats.sh` with an executable behavior test around the evaluated launcher:

- Stub `systemctl` so it fails when invoked without the inherited runtime directory.
- Return a controlled user-manager environment containing display and runtime values.
- Stub `flatpak` and assert that it receives the parsed/exported values.
- Stub retry behavior so the current bug fails quickly instead of waiting 30 seconds.

The test must fail against the current launcher before the module changes and pass after the minimal fix.

Verification also includes:

- Nix formatting of changed Nix files.
- Focused Bats regression test.
- Evaluation of representative `lenovo` and `orgm` graphical configurations.
- `git diff --check` and review that generated/runtime files remain untouched.
- `orgm-diff` review followed by `orgm-sync` to apply the approved declarative change.
- Runtime confirmation that `deskflow.service` stays active with the Flatpak process instead of accumulating restarts.

## Failure handling

Failure to query the user-manager environment remains non-fatal for an individual retry. The launcher does not launch Deskflow until display and bus prerequisites are valid. Flatpak launch failures remain visible to systemd and continue to use the existing restart policy.
