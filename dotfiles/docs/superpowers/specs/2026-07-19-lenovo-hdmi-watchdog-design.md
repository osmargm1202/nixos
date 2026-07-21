# Lenovo HDMI Hotplug Watchdog Design

## Context

On the Lenovo ThinkPad P14s Gen 2i, the Intel `i915` DRM driver can stop reporting HDMI hotplug transitions after suspend/resume cycles. During diagnosis, `HDMI-A-1` remained `disconnected` with a zero-byte EDID while an LG UltraGear monitor was physically connected. Hyprland therefore had no output to configure.

A forced DRM reprobe changed the connector to `connected`, populated a 256-byte EDID, and caused Hyprland 0.55 to activate the monitor automatically at `2560x1440@120`. A subsequent physical unplug/replug cycle produced no DRM state transition, confirming that HPD remained stuck. The global DRM polling parameter was already enabled (`drm_kms_helper.poll=Y`), so enabling generic polling is not a solution.

Research found related `i915` hotplug and Linux 7.0 suspend regressions, but no evidence that Linux 6.12 fixes this exact Tiger Lake/P14s Gen 2 failure. Firmware 1.71 is available, but its published changelog only mentions updated diagnostics. The design therefore keeps the current kernel and firmware.

## Goals

- Make HDMI connection and disconnection visible to DRM and Hyprland without manual intervention.
- Limit the workaround to the Lenovo host.
- Recover within approximately 10 seconds after a physical HDMI transition or resume.
- Preserve the current Hyprland monitor mode selection and workspace behavior.
- Avoid restarting Hyprland or closing applications during recovery.

## Non-goals

- Claim that the underlying `i915` HPD bug is fixed.
- Change the kernel, BIOS, Intel graphics parameters, or NVIDIA PRIME configuration.
- Change monitor resolution, refresh rate, scale, or workspace assignments.
- Speculatively patch the ScrollOverview plugin without a fresh crash report.

## Architecture

Add a Lenovo-only NixOS module at `nixos/hosts/lenovo/hdmi-watchdog.nix` and import it from `nixos/hosts/lenovo/p14s-gen2i.nix`.

The module defines a root-owned systemd service. The service runs one persistent shell loop rather than starting a new oneshot unit every ten seconds. Each loop iteration:

1. Expands `/sys/class/drm/card*-HDMI-A-*/status`.
2. Ignores a glob with no matching connector.
3. Writes `detect` to every writable HDMI status file.
4. Ignores connectors that disappear during probing.
5. Sleeps for ten seconds.

Writing `detect` asks the DRM driver to perform the same forced connector detection that recovered the monitor during diagnosis. If the physical state changed, DRM emits the normal hotplug change and Hyprland configures or removes the output through its existing monitor logic.

The service starts from `multi-user.target`, runs as root, and uses `Restart=always` with a short restart delay. Suspend freezes the process with the rest of userspace; after resume, the next loop iteration reprobes HDMI within at most ten seconds.

## Failure handling

- Missing HDMI connectors are normal and do not fail the service.
- A transient sysfs write failure is logged but does not terminate the loop.
- If the shell exits unexpectedly, systemd restarts it.
- The service must not reload Hyprland configuration or invoke `hyprctl`; DRM remains the source of truth.
- If Hyprland enters safe mode again after HDMI hotplug is stable, the compositor crash is investigated separately using the new crash report and rolling log. Hyprland 0.55 already implements a headless `FALLBACK` output, so no speculative compositor or plugin change belongs in this workaround.

## Verification

### Automated checks

- Add a contract test that verifies:
  - the Lenovo hardware module imports `hdmi-watchdog.nix`;
  - the service is defined only in the Lenovo host path;
  - the loop targets `card*-HDMI-A-*/status`;
  - the loop writes `detect` and sleeps for ten seconds;
  - systemd restart behavior is enabled.
- Run the contract test.
- Evaluate the Lenovo Hyprland configuration and confirm the service is enabled.
- Build `.#nixosConfigurations.lenovo-hyprland.config.system.build.toplevel`.
- Run repository diagnostics on changed files.

### Runtime checks

After `nh os switch`:

1. Confirm the watchdog service is active.
2. Record the current Hyprland PID and keep test applications open.
3. Disconnect HDMI and verify DRM and `hyprctl monitors all` remove it within 10–12 seconds.
4. Reconnect HDMI and verify DRM obtains an EDID and Hyprland restores it within 10–12 seconds.
5. Suspend and resume with HDMI connected, then repeat the unplug/replug test.
6. Confirm the Hyprland PID and test applications remain alive throughout.

## Rollout and rollback

Deploy only on `lenovo-hyprland` with `nh os switch`. Do not reboot unless another system change requires it.

Rollback consists of removing the module import and module file, switching the system again, and confirming the service no longer exists. The workaround stores no persistent state and does not alter monitor configuration.
