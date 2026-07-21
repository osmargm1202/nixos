# Vesktop Microphone AGC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every deployed Vesktop launch preserve the user's latest manual microphone volume by disabling Chromium WebRTC input-volume adjustment.

**Architecture:** Extend the existing `vesktop-webrtc` Nix package, which already wraps Vesktop with the repository's required WebRTC IP policy. Add the input-volume feature flag to that same wrapper so the existing `vesktop.nix` module deploys both policies to both Hyprland profiles without nested wrappers.

**Tech Stack:** NixOS modules, Nixpkgs `symlinkJoin`/`makeWrapper`, Bash fixture tests.

## Global Constraints

- Never set, restore, clamp, or periodically enforce a microphone volume.
- Preserve the user's latest manual microphone volume, regardless of its numeric value.
- Preserve the existing `--force-webrtc-ip-handling-policy=default_public_and_private_interfaces` flag.
- Do not change PipeWire, WirePlumber, Dota 2, Discord voice-processing settings, mic keybindings, or OSD behavior.
- Apply `--disable-features=WebRtcAllowInputVolumeAdjustment` to every deployed Vesktop launch.
- Do not include Herdr state or local Steam icon files in any commit.

---

### Task 1: Extend the existing WebRTC package contract

**Files:**

- Modify: `tests/discord-vesktop-webrtc-policy.bats.sh`
- Inspect: `nixos/packages/vesktop-webrtc.nix`
- Inspect: `nixos/profiles/vesktop.nix`

**Interfaces:**

- Consumes: the existing `vesktop-webrtc` package builder and both orgm Hyprland package lists.
- Produces: a test requiring both WebRTC flags in the built Vesktop wrapper while rejecting any fixed microphone-volume command.

- [x] **Step 1: Add the input-volume policy assertion**

```bash
INPUT_VOLUME_POLICY='--disable-features=WebRtcAllowInputVolumeAdjustment'

grep -RFq -- "$INPUT_VOLUME_POLICY" "$vesktop_out/bin" \
  || fail 'Vesktop wrapper permits automatic microphone gain changes'
if grep -Eq 'wpctl[[:space:]]+set-volume[[:space:]]+@DEFAULT_AUDIO_SOURCE@|pactl[[:space:]]+set-source-volume' \
  "$ROOT/nixos/packages/vesktop-webrtc.nix"; then
  fail 'Vesktop policy must not force a microphone volume'
fi
```

- [x] **Step 2: Run test to verify RED**

Run:

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
```

Expected: `FAIL: Vesktop wrapper permits automatic microphone gain changes`.

---

### Task 2: Add the volume policy to the existing wrapper

**Files:**

- Modify: `nixos/packages/vesktop-webrtc.nix`
- Test: `tests/discord-vesktop-webrtc-policy.bats.sh`

**Interfaces:**

- Consumes: `symlinkJoin`, `vesktop`, and `makeWrapper`.
- Produces: the existing `vesktop-webrtc-${vesktop.version}` package with both required Chromium flags.

- [x] **Step 1: Append the input-volume feature flag**

```nix
  postBuild = ''
    wrapProgram "$out/bin/vesktop" \
      --add-flags "--force-webrtc-ip-handling-policy=default_public_and_private_interfaces" \
      --add-flags "--disable-features=WebRtcAllowInputVolumeAdjustment"
  '';
```

- [ ] **Step 2: Run focused tests**

```bash
bash tests/discord-vesktop-webrtc-policy.bats.sh
```

Expected: `PASS: Discord and Vesktop wrappers enforce WebRTC policies`.

- [ ] **Step 3: Run diagnostics and builds**

```bash
shellcheck tests/discord-vesktop-webrtc-policy.bats.sh
nix build \
  .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel \
  .#nixosConfigurations.orgm-hyprlandqs-caelestia.config.system.build.toplevel \
  --no-link
```

Expected: all commands exit 0.

- [ ] **Step 4: Activate and verify runtime**

```bash
nh os switch
```

Launch Vesktop normally, select any manual microphone volume, speak for at least two minutes, and confirm the volume remains unchanged. The value is user-owned and is never forced by this configuration.

---

### Task 3: Clean temporary diagnostics

- [ ] **Step 1: Stop the microphone watcher after runtime confirmation**

```bash
systemctl --user stop mic-volume-watch.service
```

- [ ] **Step 2: Remove temporary files**

```bash
rm -f /tmp/watch-mic-volume.sh /tmp/mic-volume-watch.log
```

Temporary diagnostics are never committed.
