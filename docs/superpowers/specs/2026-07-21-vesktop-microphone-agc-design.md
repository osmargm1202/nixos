# Vesktop Microphone AGC Design

## Goal

Prevent Vesktop's Chromium/WebRTC audio stack from changing the physical microphone source volume while preserving the user's most recent manual volume setting.

## Confirmed Root Cause

The default Corsair HS55 source was monitored while Vesktop and Dota 2 captured simultaneously. Speaking with Vesktop active caused rapid source-volume changes such as `1.40 -> 0.94 -> 0.81 -> 1.40`. After Vesktop was closed, Dota 2 continued capturing while sustained speech left the source at `1.40`.

Vesktop was then launched with:

```text
--disable-features=WebRtcAllowInputVolumeAdjustment
```

Its capture stream remained active and speech no longer changed the source volume. The installed Electron 40 binary contains the `WebRtcAllowInputVolumeAdjustment` feature.

## Permanent Configuration

Extend the existing wrapped Vesktop package in `nixos/packages/vesktop-webrtc.nix`. Its `symlinkJoin` and `wrapProgram` configuration already applies the required WebRTC IP policy; it will also append:

```text
--disable-features=WebRtcAllowInputVolumeAdjustment
```

The existing `nixos/profiles/vesktop.nix` module deploys this package and `common_hyprland.nix` imports that module. Because the package retains Vesktop's desktop files and binary name, launches from the application menu, terminal, and profile startup use the same protected command.

Both `orgm-hyprland` and `orgm-hyprlandqs-caelestia` inherit the combined wrapper through the shared module.

## Volume Policy

The configuration must not set, restore, clamp, or periodically enforce a microphone volume. The user's latest manual setting remains authoritative. Only Vesktop's permission to adjust input volume is disabled.

Dota 2, PipeWire, WirePlumber, mic keybindings, and the existing OSD remain unchanged.

## Testing

Extend `tests/discord-vesktop-webrtc-policy.bats.sh` to verify:

- the shared Vesktop wrapper keeps its existing WebRTC IP policy;
- the wrapper contains `--disable-features=WebRtcAllowInputVolumeAdjustment`;
- both Hyprland configurations include the wrapped package;
- no fixed microphone volume is introduced.

Run the focused test, Nix diagnostics, and builds for both Hyprland configurations. After activation, launch Vesktop normally, confirm its capture stream is active, speak, and verify the manually selected source volume remains unchanged.

## Cleanup

Stop and remove the transient `vesktop-agc-test.service` and `mic-volume-watch.service` after the permanent configuration is activated and runtime verification succeeds. Temporary files under `/tmp` are not committed.

## Out of Scope

- Blocking source-volume changes globally in WirePlumber.
- Forcing a fixed microphone level such as 140%.
- Changing Discord noise suppression, echo cancellation, or input sensitivity.
- Modifying Dota 2 or Steam voice settings.
