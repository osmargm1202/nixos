# Lenovo LTS Kernel Design

**Date:** 2026-07-19

## Goal

Run every graphical Lenovo P14s Gen 2i profile on the repository's existing Linux LTS package set (`linuxPackages_6_12`) so HDMI detection can be tested independently of the pinned Linux Zen 7.0.10 kernel.

## Scope

The change applies to every flake output that imports `nixos/hosts/lenovo/p14s-gen2i.nix`:

- `lenovo-labwc`
- `lenovo-gnome`
- `lenovo-hyprland`
- `lenovo-hyprlandqs-caelestia`
- `lenovo-i3`
- `lenovo-xfce`
- `lenovo-mate`

The ORGM, Jarq, server, and terminal-only configurations remain unchanged.

## Architecture

Replace the Lenovo host module's import of `../../hardware/kernel/zen70-pin.nix` with `../../hardware/kernel/lts.nix`. The existing LTS module owns the kernel selection:

```nix
boot.kernelPackages = pkgs.linuxPackages_6_12;
```

Keeping kernel selection in the shared kernel module avoids duplicating the package expression and makes the Lenovo override visible at the hardware-profile boundary used by every graphical Lenovo output.

## Preserved Configuration

The change does not modify:

- `i915.enable_guc=3`
- Intel graphics packages
- NVIDIA 580.142 selection
- NVIDIA PRIME bus IDs, offload, modesetting, or power management
- Hyprland configuration or monitor rules
- BIOS settings
- firmware inputs
- non-Lenovo kernel selection

The rejected HDMI watchdog is not restored or merged.

## Testing

Use a shell contract test written before the production change. It must assert that:

1. `p14s-gen2i.nix` imports `kernel/lts.nix`.
2. `p14s-gen2i.nix` no longer imports `kernel/zen70-pin.nix`.
3. `lts.nix` selects `pkgs.linuxPackages_6_12`.

Then evaluate the kernel version for every graphical Lenovo output and verify each reports a 6.12 kernel. Evaluate at least one non-Lenovo output to ensure Lenovo's host-local override did not leak.

Build `nixosConfigurations.lenovo-hyprland.config.system.build.toplevel` to prove that the selected NVIDIA package compiles against Linux 6.12.

## Deployment and Runtime Validation

Deploy only `lenovo-hyprland` with `nh os switch -H lenovo-hyprland`, then reboot into the new generation. After boot:

1. Confirm `uname -r` reports Linux 6.12.
2. Confirm i915 and NVIDIA modules load without blocking errors.
3. Confirm Hyprland starts normally.
4. With HDMI physically connected and powered, inspect DRM status and EDID.
5. Disconnect and reconnect HDMI, verifying hotplug behavior and preserving the Hyprland PID.
6. Suspend and resume once, then repeat HDMI hotplug.

## Rollback

The prior known bootable generation remains available in systemd-boot. If Linux 6.12 or NVIDIA fails to boot, select the previous generation and restore the Zen import before deploying again.

A successful build is necessary but not sufficient: the HDMI issue is considered improved only after physical boot, hotplug, and suspend validation on the Lenovo host.
