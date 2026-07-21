# Lenovo i915 Default GuC Design

**Date:** 2026-07-19

## Goal

Test whether the Lenovo P14s Gen 2i HDMI detection failure is caused by forcing `i915.enable_guc=3`, a kernel parameter absent from HyDE and Hydenix.

## Evidence

The failure occurs below Hyprland: with HDMI physically connected, DRM reports `HDMI-A-1` as disconnected, EDID is empty, and direct DDC probing finds no monitor. The same failure reproduces on Linux Zen 7.0.10 and Linux LTS 6.12.93 because both boots include the same forced parameter:

```text
i915.enable_guc=3
```

HyDE and Hydenix contain no HDMI detector, DRM reprobe service, udev monitor rule, or i915 GuC override. They rely on the kernel to enumerate the output and then apply the generic Hyprland rule `monitor = ,preferred,auto,auto`.

Linux 6.12 defines `i915.enable_guc=-1` as the automatic default. In `uc_expand_default_options()`, Tiger Lake explicitly converts that automatic value to `0`, disabling GuC and HuC. Removing the forced parameter therefore gives this hardware a true GuC-disabled comparison without adding another override.

## Scope

Remove only this line from `nixos/hosts/lenovo/p14s-gen2i.nix`:

```nix
boot.kernelParams = [ "i915.enable_guc=3" ];
```

The change applies to the seven graphical Lenovo profiles that import the P14s hardware module. It does not apply to ORGM, Jarq, server, or terminal-only outputs.

## Preserved Configuration

Keep unchanged:

- Linux LTS 6.12 selection
- Intel graphics packages and initrd i915 loading
- NVIDIA 580.142 and PRIME/offload configuration
- Hyprland and monitor layout configuration
- BIOS and firmware
- rejected HDMI watchdog implementation
- unrelated Herdr, Rofi, and Pi subagent changes

## Testing

Add a focused shell contract before changing production configuration. It must fail while `i915.enable_guc=3` remains in the Lenovo hardware module and pass only when the forced parameter is absent. It must also verify that Linux 6.12 remains selected.

Then:

1. Evaluate every graphical Lenovo output and confirm its kernel command line does not contain `i915.enable_guc=3`.
2. Evaluate `lenovo-hyprland` and confirm Linux 6.12 remains selected.
3. Build the complete `lenovo-hyprland` system closure, including NVIDIA 580.142.
4. Deploy with `nh os switch -H lenovo-hyprland`.

## Runtime Validation

After reboot:

1. Confirm Linux 6.12 is running.
2. Confirm `/proc/cmdline` does not contain `i915.enable_guc`.
3. Confirm the i915 boot log does not report GuC submission or SLPC enabled.
4. Confirm i915 and NVIDIA modules load and Hyprland starts without configuration errors.
5. With HDMI connected and powered, inspect connector status and EDID size.
6. If detected, perform repeated disconnect/reconnect and suspend/resume tests without changing the Hyprland PID during each boot session.

## Outcome Rules

- If HDMI is detected with a non-empty EDID, keep the parameter removed and continue physical validation.
- If HDMI remains disconnected with EDID 0, record GuC as a failed hypothesis. Do not add another workaround in the same change.
- If graphics regress, boot the prior generation and restore the parameter.

## Rollback

Systemd-boot generation 105 preserves Linux 6.12.93 with `i915.enable_guc=3`. It is the immediate rollback target if the GuC-disabled generation fails to boot or causes graphics regressions.
