# Require Explicit Jarq Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove ambiguous default `jarq` NixOS output so Jarq installs only when user specifies `jarq-gnome` or `jarq-cinnamon`.

**Architecture:** Keep profile-specific host outputs only. Rename current `jarq` GNOME output to `jarq-gnome`; keep existing `jarq-cinnamon`; add small repo test that fails if plain `jarq` output exists again.

**Tech Stack:** Nix flakes, bash tests, grep-based regression check.

---

## File Structure

- Modify: `flake.nix` — remove/rename plain `nixosConfigurations.jarq`; expose `jarq-gnome` and `jarq-cinnamon` only.
- Create: `tests/flake-outputs.bats.sh` — static regression test ensuring no plain `jarq` output and both explicit outputs exist.

---

### Task 1: Rename `jarq` output to `jarq-gnome`

**Files:**
- Modify: `flake.nix:220-241`

- [ ] **Step 1: Edit Jarq outputs**

Replace this block:

```nix
        jarq = mkHost {
          hostName = "jarq";
          hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/gnome.nix;
          userName = "jarq";
          extraModules = [
            ./nixos/hardware/gpu/intel.nix
            ./nixos/hosts/jarq/default.nix
            ./nixos/hosts/jarq/plymouth.nix
          ];
        };
        jarq-cinnamon = mkHost {
```

with:

```nix
        jarq-gnome = mkHost {
          hostName = "jarq";
          hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/gnome.nix;
          userName = "jarq";
          extraModules = [
            ./nixos/hardware/gpu/intel.nix
            ./nixos/hosts/jarq/default.nix
            ./nixos/hosts/jarq/plymouth.nix
          ];
        };
        jarq-cinnamon = mkHost {
```

- [ ] **Step 2: Verify plain `jarq` no longer exists by text scan**

Run:

```bash
grep -n '^[[:space:]]*jarq = mkHost' flake.nix && exit 1 || true
grep -n '^[[:space:]]*jarq-gnome = mkHost' flake.nix
grep -n '^[[:space:]]*jarq-cinnamon = mkHost' flake.nix
```

Expected:

- first command prints nothing and exits through `true`
- second command finds `jarq-gnome`
- third command finds `jarq-cinnamon`

---

### Task 2: Add regression test for explicit Jarq profiles

**Files:**
- Create: `tests/flake-outputs.bats.sh`

- [ ] **Step 1: Create test file**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$REPO_DIR/flake.nix"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local pattern="$1" name="$2"
  grep -Eq -- "$pattern" "$FLAKE" || fail "$name"
}

assert_not_contains() {
  local pattern="$1" name="$2"
  if grep -Eq -- "$pattern" "$FLAKE"; then
    fail "$name"
  fi
}

assert_not_contains '^[[:space:]]*jarq[[:space:]]*=[[:space:]]*mkHost' "plain jarq output must not exist; use jarq-gnome or jarq-cinnamon"
assert_contains '^[[:space:]]*jarq-gnome[[:space:]]*=[[:space:]]*mkHost' "jarq-gnome output must exist"
assert_contains '^[[:space:]]*jarq-cinnamon[[:space:]]*=[[:space:]]*mkHost' "jarq-cinnamon output must exist"

awk '
  /^[[:space:]]*jarq-gnome[[:space:]]*=[[:space:]]*mkHost/ { in_block = 1 }
  in_block && /profile = \.\/nixos\/profiles\/gnome\.nix;/ { found = 1 }
  in_block && /^[[:space:]]*};/ { in_block = 0 }
  END { exit found ? 0 : 1 }
' "$FLAKE" || fail "jarq-gnome must use gnome profile"

awk '
  /^[[:space:]]*jarq-cinnamon[[:space:]]*=[[:space:]]*mkHost/ { in_block = 1 }
  in_block && /profile = \.\/nixos\/profiles\/cinnamon\.nix;/ { found = 1 }
  in_block && /^[[:space:]]*};/ { in_block = 0 }
  END { exit found ? 0 : 1 }
' "$FLAKE" || fail "jarq-cinnamon must use cinnamon profile"

echo "PASS: flake output tests"
```

- [ ] **Step 2: Run test**

Run:

```bash
bash tests/flake-outputs.bats.sh
```

Expected before Task 1: FAIL because plain `jarq` exists.
Expected after Task 1: `PASS: flake output tests`.

---

### Task 3: Verify Nix evaluation for explicit profiles

**Files:**
- No code changes.

- [ ] **Step 1: Run local/static checks**

```bash
bash -n install.sh
bash tests/install-installer.bats.sh
bash tests/flake-outputs.bats.sh
```

Expected:

- `PASS: install installer tests`
- `PASS: flake output tests`

- [ ] **Step 2: Run host Nix eval from distrobox**

```bash
distrobox-host-exec bash -lc 'cd /home/osmarg/Hobby/nixos && nix eval .#nixosConfigurations.jarq-gnome.config.services.displayManager.defaultSession --raw'
distrobox-host-exec bash -lc 'cd /home/osmarg/Hobby/nixos && nix eval .#nixosConfigurations.jarq-cinnamon.config.services.displayManager.defaultSession --raw'
distrobox-host-exec bash -lc 'cd /home/osmarg/Hobby/nixos && nix eval .#nixosConfigurations.jarq.config.networking.hostName --raw'
```

Expected:

- first outputs `gnome`
- second outputs `cinnamon`
- third fails with missing attribute `jarq`

---

### Task 4: Commit

**Files:**
- Modify: `flake.nix`
- Create: `tests/flake-outputs.bats.sh`

- [ ] **Step 1: Inspect diff**

```bash
git diff -- flake.nix tests/flake-outputs.bats.sh
```

- [ ] **Step 2: Commit**

```bash
git add flake.nix tests/flake-outputs.bats.sh
git commit -m "fix(nixos): require explicit Jarq desktop profile"
```

---

## Self-Review

- Spec coverage: plain Jarq default removed; user must specify `jarq-gnome` or `jarq-cinnamon`; only one desktop profile selected per output.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: output names consistent across plan and tests.
