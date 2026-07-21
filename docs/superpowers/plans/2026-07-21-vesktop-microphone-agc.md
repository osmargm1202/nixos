# Vesktop Microphone AGC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every deployed Vesktop launch preserve the user's latest manual microphone volume by disabling Chromium WebRTC input-volume adjustment.

**Architecture:** Wrap the existing Nixpkgs Vesktop package with `symlinkJoin` and `wrapProgram`, retaining its binary name and desktop files while appending one Chromium feature flag. Deploy that wrapped package through the shared Hyprland profile so both orgm Hyprland configurations inherit it.

**Tech Stack:** NixOS modules, Nixpkgs `symlinkJoin`/`makeWrapper`, Bash fixture tests.

## Global Constraints

- Never set, restore, clamp, or periodically enforce a microphone volume.
- Preserve the user's latest manual microphone volume, regardless of its numeric value.
- Do not change PipeWire, WirePlumber, Dota 2, Discord voice-processing settings, mic keybindings, or OSD behavior.
- Apply `--disable-features=WebRtcAllowInputVolumeAdjustment` to every deployed Vesktop launch.
- Do not commit or push implementation changes until the user runs `nh os switch` and completes runtime voice testing.
- Do not include Herdr state or local Steam icon files in any later commit.

---

### Task 1: Add a failing package-contract test

**Files:**

- Create: `tests/vesktop-mic-agc.bats.sh`
- Inspect: `nixos/profiles/common_hyprland.nix`

**Interfaces:**

- Consumes: `nixosConfigurations.orgm-hyprland.config.environment.systemPackages` and `nixosConfigurations.orgm-hyprlandqs-caelestia.config.environment.systemPackages`.
- Produces: A test requiring one package whose output name starts with `vesktop-no-input-volume-adjustment-` and whose `bin/vesktop` wrapper contains the Chromium feature flag.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/common_hyprland.nix"
FLAG='--disable-features=WebRtcAllowInputVolumeAdjustment'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'vesktopNoInputVolumeAdjustment' "$PROFILE" \
  || fail 'wrapped Vesktop package is not defined'
grep -Fq -- "$FLAG" "$PROFILE" \
  || fail 'WebRTC input-volume flag is missing'
if grep -Eq 'wpctl[[:space:]]+set-volume[[:space:]]+@DEFAULT_AUDIO_SOURCE@|pactl[[:space:]]+set-source-volume' "$PROFILE"; then
  fail 'profile must not force a microphone volume'
fi

cd "$ROOT"
for profile in orgm-hyprland orgm-hyprlandqs-caelestia; do
  drv="$(nix eval --raw ".#nixosConfigurations.$profile.config.environment.systemPackages" \
    --apply 'packages: let matches = builtins.filter (package: builtins.match "vesktop-no-input-volume-adjustment-.*" package.name != null) packages; in (builtins.head matches).drvPath' \
    2>/dev/null)"
  [[ -n "$drv" ]] || fail "wrapped Vesktop missing from $profile"
  wrapper="$(nix-store -r "$drv" 2>/dev/null)"
  grep -Fq -- "$FLAG" "$wrapper/bin/vesktop" \
    || fail "Vesktop wrapper flag missing from $profile"
done

printf 'PASS: Vesktop cannot adjust physical microphone volume\n'
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
chmod +x tests/vesktop-mic-agc.bats.sh
bash tests/vesktop-mic-agc.bats.sh
```

Expected: `FAIL: wrapped Vesktop package is not defined`.

---

### Task 2: Deploy the wrapped Vesktop package

**Files:**

- Modify: `nixos/profiles/common_hyprland.nix:9-25`
- Modify: `nixos/profiles/common_hyprland.nix:323-326`
- Test: `tests/vesktop-mic-agc.bats.sh`

**Interfaces:**

- Consumes: `pkgs.vesktop`, `pkgs.symlinkJoin`, and `pkgs.makeWrapper`.
- Produces: `vesktopNoInputVolumeAdjustment`, a package retaining Vesktop desktop files and exposing `bin/vesktop` with the input-volume feature disabled.

- [ ] **Step 1: Define the wrapped package in the module `let` block**

Insert after `psdZen`:

```nix
  vesktopNoInputVolumeAdjustment = pkgs.symlinkJoin {
    name = "vesktop-no-input-volume-adjustment-${pkgs.vesktop.version}";
    paths = [ pkgs.vesktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/vesktop \
        --add-flags "--disable-features=WebRtcAllowInputVolumeAdjustment"
    '';
  };
```

- [ ] **Step 2: Replace the communication package**

Change:

```nix
    # Communication
    vesktop
```

To:

```nix
    # Communication
    vesktopNoInputVolumeAdjustment
```

- [ ] **Step 3: Run focused test to verify GREEN**

Run:

```bash
bash tests/vesktop-mic-agc.bats.sh
```

Expected: `PASS: Vesktop cannot adjust physical microphone volume`.

- [ ] **Step 4: Run Nix diagnostics and build both profiles**

Run:

```bash
nix build \
  .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel \
  .#nixosConfigurations.orgm-hyprlandqs-caelestia.config.system.build.toplevel \
  --no-link
```

Expected: exit 0.

- [ ] **Step 5: Stop before activation and commit**

Report implementation and verification results. Leave files uncommitted. The user will run:

```bash
nh os switch
```

After activation, the user launches Vesktop normally, selects any manual microphone volume, speaks for at least two minutes, and confirms the volume remains unchanged. Only after that confirmation should the implementation, test, plan, and any approved documentation be committed and pushed.

---

### Task 3: Clean temporary diagnostics after runtime confirmation

**Files:**

- Delete outside repository: `/tmp/watch-mic-volume.sh`
- Delete outside repository: `/tmp/mic-volume-watch.log`

**Interfaces:**

- Consumes: Runtime confirmation from Task 2.
- Produces: No transient test Vesktop or microphone watcher services.

- [ ] **Step 1: Stop transient units without changing persistent configuration**

```bash
systemctl --user stop vesktop-agc-test.service mic-volume-watch.service
```

Expected: both transient units stop; normal Vesktop can then be launched from its desktop entry.

- [ ] **Step 2: Remove temporary diagnostic files**

```bash
rm -f /tmp/watch-mic-volume.sh /tmp/mic-volume-watch.log
```

Expected: neither file exists. This cleanup is not committed.
