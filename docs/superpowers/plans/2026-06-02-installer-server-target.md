# Installer Server Target Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a server target to `install.sh` that generates a local flake using `nixos/server.nix`.

**Architecture:** Desktop installs keep `orgmos.lib.mkGeneralHost` plus GPU/kernel prompts. Server installs use new `orgmos.lib.mkServerHost`, skip GPU/kernel prompts, and produce a minimal server-shaped flake using local hardware plus `nixos/server.nix`.

**Tech Stack:** Nix flakes, Bash installer, shell regression tests.

---

## File Structure

- Modify: `flake.nix` — add `mkServerHost` helper and export it under `lib`.
- Modify: `install.sh` — add `server` menu option, server-mode branching, generated flake selection, and summary branching.
- Modify: `tests/install-installer.bats.sh` — add shell regression checks for generated server and desktop flakes.

## Task 1: Add failing installer tests

**Files:**
- Modify: `tests/install-installer.bats.sh`

- [ ] **Step 1: Append helper and assertions for flake generation**

Add test code after existing resolver assertions and before `bash -n "$REPO_DIR/install.sh"`:

```bash
assert_file_contains() {
  local file="$1" want="$2" name="$3"
  grep -qF -- "$want" "$file" || {
    echo "--- $file ---" >&2
    cat "$file" >&2 2>/dev/null || true
    fail "$name expected: $want"
  }
}

assert_file_not_contains() {
  local file="$1" want="$2" name="$3"
  if grep -qF -- "$want" "$file"; then
    echo "--- $file ---" >&2
    cat "$file" >&2 2>/dev/null || true
    fail "$name must not contain: $want"
  fi
}

server_dir="$TMP_ROOT/server/etc/nixos"
make_nixos_dir "$server_dir"
NIXOS_DIR="$server_dir"
NIXOS_DIR_EXPLICIT=true
DRY_RUN=false
SELECTED_PROFILE="server"
SELECTED_HOSTNAME="serverbox"
FLAKE_PATH="$server_dir/flake.nix"
HARDWARE_PATH="$server_dir/hardware-configuration.nix"
refresh_nixos_paths
printf 'y\n' | write_flake > "$TMP_ROOT/server.out"
assert_file_contains "$FLAKE_PATH" "orgmos.lib.mkServerHost" "server flake uses mkServerHost"
assert_file_contains "$FLAKE_PATH" 'hostName = "serverbox";' "server flake includes hostname"
assert_file_not_contains "$FLAKE_PATH" "mkGeneralHost" "server flake skips desktop host helper"
assert_file_not_contains "$FLAKE_PATH" "nixosModules.gpu" "server flake skips GPU modules"
assert_file_not_contains "$FLAKE_PATH" "nixosModules.kernel" "server flake skips kernel modules"

desktop_dir="$TMP_ROOT/desktop/etc/nixos"
make_nixos_dir "$desktop_dir"
NIXOS_DIR="$desktop_dir"
NIXOS_DIR_EXPLICIT=true
DRY_RUN=false
SELECTED_PROFILE="hyprland"
SELECTED_HOSTNAME="deskbox"
SELECTED_GPU="intel"
SELECTED_GPU_MODULE="orgmos.nixosModules.gpu.intel"
SELECTED_KERNEL="zen"
SELECTED_KERNEL_MODULE="orgmos.nixosModules.kernel.zen"
FLAKE_PATH="$desktop_dir/flake.nix"
HARDWARE_PATH="$desktop_dir/hardware-configuration.nix"
refresh_nixos_paths
printf 'y\n' | write_flake > "$TMP_ROOT/desktop.out"
assert_file_contains "$FLAKE_PATH" "orgmos.lib.mkGeneralHost" "desktop flake keeps mkGeneralHost"
assert_file_contains "$FLAKE_PATH" "orgmos.nixosModules.gpu.intel" "desktop flake includes GPU module"
assert_file_contains "$FLAKE_PATH" "orgmos.nixosModules.kernel.zen" "desktop flake includes kernel module"
```

- [ ] **Step 2: Run failing tests**

Run:

```bash
bash tests/install-installer.bats.sh
```

Expected: FAIL because server flake still uses `mkGeneralHost` or references unset GPU/kernel module variables.

## Task 2: Add flake server helper

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add `mkServerHost` beside `mkGeneralHost`**

Insert after `mkGeneralHost` definition:

```nix
      mkServerHost =
        {
          hardware,
          hostName,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            hardware
            ./nixos/server.nix
            { networking.hostName = hostName; }
          ]
          ++ extraModules;
        };
```

- [ ] **Step 2: Export helper**

Change:

```nix
      lib = {
        inherit mkGeneralHost;
      };
```

to:

```nix
      lib = {
        inherit mkGeneralHost mkServerHost;
      };
```

## Task 3: Add installer server branching

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Add server to profiles**

Change:

```bash
profiles=(hyprland gnome labwc sway i3)
```

to:

```bash
profiles=(hyprland gnome labwc sway i3 server)
```

- [ ] **Step 2: Add profile helper**

Add:

```bash
is_server_profile() {
  [ "${SELECTED_PROFILE:-}" = "server" ]
}
```

- [ ] **Step 3: Skip desktop prompts for server**

In `main`, after `choose_profile`, change prompt sequence to:

```bash
  choose_profile
  if ! is_server_profile; then
    choose_gpu
    choose_kernel
  fi
  choose_hostname

  if [ "${SELECTED_GPU:-}" = "nvidia-offload" ]; then
    detect_offload_bus_ids
  fi
```

- [ ] **Step 4: Branch generated flake helper**

In `write_flake`, branch heredoc. Server must write:

```nix
{
  inputs.orgmos.url = "$REPO_URL";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkServerHost {
      hardware = ./hardware-configuration.nix;
      hostName = "$SELECTED_HOSTNAME";
    };
  };
}
```

Desktop keeps existing `mkGeneralHost` body with `profile` and `extraModules`.

- [ ] **Step 5: Branch summary output**

Only print GPU/kernel lines when profile is not server:

```bash
  if ! is_server_profile; then
    say "  GPU:        $SELECTED_GPU"
    say "  Kernel:     $SELECTED_KERNEL"
  fi
```

## Task 4: Verify and commit

**Files:**
- Modify: `flake.nix`
- Modify: `install.sh`
- Modify: `tests/install-installer.bats.sh`

- [ ] **Step 1: Run shell verification**

Run:

```bash
bash -n install.sh && bash tests/install-installer.bats.sh
```

Expected: `PASS: install installer tests`.

- [ ] **Step 2: Run Nix eval verification**

Run:

```bash
nix eval .#lib --apply 'lib: builtins.hasAttr "mkServerHost" lib'
```

Expected: `true`.

- [ ] **Step 3: Run Go tests**

Run:

```bash
go test ./...
```

Expected: all packages pass.

- [ ] **Step 4: Commit**

Run:

```bash
git add flake.nix install.sh tests/install-installer.bats.sh
git commit -m "feat(installer): add server target"
```

## Self-Review

- Spec coverage: server menu, `mkServerHost`, skipped GPU/kernel prompts, server flake generation, desktop preservation, and export verification are covered.
- Placeholder scan: no placeholders remain.
- Type consistency: `mkServerHost`, `SELECTED_PROFILE`, `is_server_profile`, and generated flake fields are consistent across plan tasks.
